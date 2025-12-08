import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/recipe_repository.dart';
import '../../data/repositories/cloud_repository.dart' as cloud;
import '../auth/auth_provider.dart';

export '../../data/repositories/recipe_repository.dart'
    show RecipeIngredient, MaterialStatus;
export '../auth/auth_provider.dart' show authProvider;

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

  Future<void> loadRecipes() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data({});
        return;
      }

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
          final cloudRecipes =
              await cloudRepo.getAllRecipes(authState.tenant!.id);
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
        }
      }

      final repository = ref.read(recipeRepositoryProvider);
      final recipes = await repository.getAllRecipes(authState.tenant!.id);
      state = AsyncValue.data(recipes);
    } catch (e, stack) {
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
    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      throw Exception('Tenant tidak ditemukan');
    }

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
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
        await cloudRepo.saveRecipe(
            authState.tenant!.id, productId, cloudIngredients);
        await loadRecipes();
        return;
      } catch (e) {
        debugPrint('Cloud recipe save failed, falling back to local: $e');
      }
    }

    final repository = ref.read(recipeRepositoryProvider);
    final result = await repository.saveRecipe(
      authState.tenant!.id,
      productId,
      ingredients,
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menyimpan resep');
    }

    await loadRecipes();
  }

  /// Delete recipe for a product
  Future<void> deleteRecipe(String productId) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      throw Exception('Tenant tidak ditemukan');
    }

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudRecipeRepositoryProvider);
        await cloudRepo.deleteRecipe(productId);
        await loadRecipes();
        return;
      } catch (e) {
        debugPrint('Cloud recipe delete failed, falling back to local: $e');
      }
    }

    final repository = ref.read(recipeRepositoryProvider);
    final result = await repository.deleteRecipe(
      authState.tenant!.id,
      productId,
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus resep');
    }

    await loadRecipes();
  }
}
