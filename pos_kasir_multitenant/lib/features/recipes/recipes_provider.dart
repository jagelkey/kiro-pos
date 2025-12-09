import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/repositories/recipe_repository.dart';
import '../../data/repositories/cloud_repository.dart' as cloud;
import '../auth/auth_provider.dart';

export '../../data/repositories/recipe_repository.dart'
    show RecipeIngredient, MaterialStatus;
export '../auth/auth_provider.dart' show authProvider;

/// Helper function to check connectivity results
bool _checkConnectivityResults(dynamic results) {
  if (results is List<ConnectivityResult>) {
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  } else if (results is ConnectivityResult) {
    return results != ConnectivityResult.none;
  }
  return true;
}

final recipeRepositoryProvider = Provider((ref) => RecipeRepository());
final cloudRecipeRepositoryProvider =
    Provider((ref) => cloud.CloudRepository());

/// Provider for all recipes of current tenant
final recipesProvider =
    FutureProvider<Map<String, List<RecipeIngredient>>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.tenant == null) return {};

  // Try cloud first if enabled
  if (AppConfig.useSupabase) {
    try {
      final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
      final cloudRecipes = await cloudRepo.getAllRecipes(authState.tenant!.id);
      // Convert cloud RecipeIngredient to local RecipeIngredient
      final Map<String, List<RecipeIngredient>> recipes = {};
      for (final entry in cloudRecipes.entries) {
        recipes[entry.key] = entry.value
            .map((ci) => RecipeIngredient(
                  materialId: ci.materialId,
                  name: ci.name,
                  quantity: ci.quantity,
                  unit: ci.unit,
                ))
            .toList();
      }
      return recipes;
    } catch (e) {
      debugPrint('Cloud recipes load failed, falling back to local: $e');
    }
  }

  final repository = ref.read(recipeRepositoryProvider);
  return repository.getAllRecipes(authState.tenant!.id);
});

/// StateNotifier for recipe management
final recipeNotifierProvider = StateNotifierProvider<RecipeNotifier,
    AsyncValue<Map<String, List<RecipeIngredient>>>>((ref) {
  return RecipeNotifier(ref);
});

class RecipeNotifier
    extends StateNotifier<AsyncValue<Map<String, List<RecipeIngredient>>>> {
  final Ref ref;

  RecipeNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadRecipes();
  }

  /// Validates tenant and returns tenantId or throws exception
  String _validateTenant() {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      throw Exception('Tenant tidak ditemukan. Silakan login ulang.');
    }
    final tenantId = authState.tenant!.id;
    if (tenantId.isEmpty) {
      throw Exception('ID Tenant tidak valid');
    }
    return tenantId;
  }

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Queue recipe operation for sync when back online (Android only)
  Future<void> _queueForSync(String operation, String productId,
      List<RecipeIngredient> ingredients) async {
    if (kIsWeb) return; // Web doesn't support offline sync

    try {
      final tenantId = _validateTenant();
      final syncOp = SyncOperation(
        id: 'recipe-$productId-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'recipes',
        type: operation == 'insert' || operation == 'update'
            ? SyncOperationType.update
            : SyncOperationType.delete,
        data: {
          'tenant_id': tenantId,
          'product_id': productId,
          'ingredients': ingredients.map((i) => i.toJson()).toList(),
        },
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue recipe sync operation: $e');
    }
  }

  Future<void> loadRecipes() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data({});
        return;
      }

      final tenantId = authState.tenant!.id;
      if (tenantId.isEmpty) {
        state = const AsyncValue.data({});
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
          final cloudRecipes = await cloudRepo.getAllRecipes(tenantId);
          // Convert cloud RecipeIngredient to local RecipeIngredient
          final Map<String, List<RecipeIngredient>> recipes = {};
          for (final entry in cloudRecipes.entries) {
            recipes[entry.key] = entry.value
                .map((ci) => RecipeIngredient(
                      materialId: ci.materialId,
                      name: ci.name,
                      quantity: ci.quantity,
                      unit: ci.unit,
                    ))
                .toList();
          }
          state = AsyncValue.data(recipes);
          return;
        } catch (e) {
          debugPrint('Cloud recipes load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      final repository = ref.read(recipeRepositoryProvider);
      final recipes = await repository.getAllRecipes(tenantId);
      state = AsyncValue.data(recipes);
    } catch (e, stack) {
      debugPrint('Error loading recipes: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Get recipe for a specific product
  List<RecipeIngredient>? getRecipe(String productId) {
    return state.valueOrNull?[productId];
  }

  /// Check if product has recipe
  bool hasRecipe(String productId) {
    final recipe = state.valueOrNull?[productId];
    return recipe != null && recipe.isNotEmpty;
  }

  /// Save recipe for a product
  Future<void> saveRecipe(
      String productId, List<RecipeIngredient> ingredients) async {
    final tenantId = _validateTenant();

    if (productId.isEmpty) {
      throw Exception('ID produk tidak valid');
    }

    // Validate ingredients
    for (var ingredient in ingredients) {
      if (ingredient.materialId.isEmpty) {
        throw Exception(
            'Material ID tidak valid untuk bahan "${ingredient.name}"');
      }
      if (ingredient.quantity <= 0) {
        throw Exception('Jumlah bahan "${ingredient.name}" harus lebih dari 0');
      }
      if (ingredient.unit.isEmpty) {
        throw Exception('Satuan tidak valid untuk bahan "${ingredient.name}"');
      }
    }

    // Check for duplicate materials
    final materialIds = ingredients.map((i) => i.materialId).toList();
    final uniqueMaterialIds = materialIds.toSet();
    if (materialIds.length != uniqueMaterialIds.length) {
      throw Exception('Tidak boleh ada bahan yang duplikat dalam resep');
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
        // Convert local RecipeIngredient to cloud format
        final cloudIngredients = ingredients
            .map((i) => cloud.CloudRecipeIngredient(
                  materialId: i.materialId,
                  name: i.name,
                  quantity: i.quantity,
                  unit: i.unit,
                ))
            .toList();
        await cloudRepo.saveRecipe(tenantId, productId, cloudIngredients);
        await loadRecipes();
        return;
      } catch (e) {
        // Offline fallback: save locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud recipe save failed, saving locally: $e');
          final repository = ref.read(recipeRepositoryProvider);
          final result = await repository.saveRecipe(
            tenantId,
            productId,
            ingredients,
          );
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal menyimpan resep');
          }
          // Queue for sync when online
          await _queueForSync('update', productId, ingredients);
          await loadRecipes();
          return;
        } else {
          rethrow;
        }
      }
    }

    // Local mode
    final repository = ref.read(recipeRepositoryProvider);
    final result = await repository.saveRecipe(
      tenantId,
      productId,
      ingredients,
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menyimpan resep');
    }

    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('update', productId, ingredients);
    }

    await loadRecipes();
  }

  /// Delete recipe for a product
  Future<void> deleteRecipe(String productId) async {
    final tenantId = _validateTenant();

    if (productId.isEmpty) {
      throw Exception('ID produk tidak valid');
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
        await cloudRepo.deleteRecipe(productId);
        await loadRecipes();
        return;
      } catch (e) {
        // Offline fallback: delete locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud recipe delete failed, deleting locally: $e');
          final repository = ref.read(recipeRepositoryProvider);
          final result = await repository.deleteRecipe(tenantId, productId);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal menghapus resep');
          }
          // Queue for sync when online
          await _queueForSync('delete', productId, []);
          await loadRecipes();
          return;
        } else {
          rethrow;
        }
      }
    }

    // Local mode
    final repository = ref.read(recipeRepositoryProvider);
    final result = await repository.deleteRecipe(tenantId, productId);

    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus resep');
    }

    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('delete', productId, []);
    }

    await loadRecipes();
  }
}
