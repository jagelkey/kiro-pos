import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/material.dart' as mat;
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/cloud_repository.dart'
    show CloudRepository, CloudStockMovement;
import '../auth/auth_provider.dart';

final materialRepositoryProvider = Provider((ref) => MaterialRepository());
final cloudMaterialRepositoryProvider = Provider((ref) => CloudRepository());

final materialsProvider =
    StateNotifierProvider<MaterialNotifier, AsyncValue<List<mat.Material>>>(
        (ref) {
  return MaterialNotifier(ref);
});

class MaterialNotifier extends StateNotifier<AsyncValue<List<mat.Material>>> {
  final Ref ref;

  MaterialNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadMaterials();
  }

  Future<void> loadMaterials() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
          final materials = await cloudRepo.getMaterials(authState.tenant!.id);
          state = AsyncValue.data(materials);
          return;
        } catch (e) {
          debugPrint('Cloud materials load failed, falling back to local: $e');
        }
      }

      // Fallback to local
      final repository = ref.read(materialRepositoryProvider);
      final materials = await repository.getMaterials(authState.tenant!.id);
      state = AsyncValue.data(materials);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMaterial(mat.Material material) async {
    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
        await cloudRepo.createMaterial(material);
        await loadMaterials();
        return;
      } catch (e) {
        debugPrint('Cloud material create failed, falling back to local: $e');
      }
    }

    final repository = ref.read(materialRepositoryProvider);
    final result = await repository.createMaterial(material);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to create material');
    }
    await loadMaterials();
  }

  Future<void> updateMaterial(mat.Material material) async {
    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
        await cloudRepo.updateMaterial(material);
        await loadMaterials();
        return;
      } catch (e) {
        debugPrint('Cloud material update failed, falling back to local: $e');
      }
    }

    final repository = ref.read(materialRepositoryProvider);
    final result = await repository.updateMaterial(material);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to update material');
    }
    await loadMaterials();
  }

  Future<void> deleteMaterial(String id) async {
    final authState = ref.read(authProvider);

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
        await cloudRepo.deleteMaterial(id);
        await loadMaterials();
        return;
      } catch (e) {
        debugPrint('Cloud material delete failed, falling back to local: $e');
      }
    }

    final repository = ref.read(materialRepositoryProvider);
    // Pass tenantId for multi-tenant validation
    final result = await repository.deleteMaterial(
      id,
      tenantId: authState.tenant?.id,
    );
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus bahan baku');
    }
    await loadMaterials();
  }

  Future<void> updateStock(String id, double newStock,
      {required String reason, String? note}) async {
    // For stock update, we need to get current material and update it
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
        final material = await cloudRepo.getMaterialById(id);
        if (material != null) {
          final previousStock = material.stock;
          final updated = mat.Material(
            id: material.id,
            tenantId: material.tenantId,
            name: material.name,
            stock: newStock,
            unit: material.unit,
            minStock: material.minStock,
            category: material.category,
            createdAt: material.createdAt,
          );
          await cloudRepo.updateMaterial(updated);

          // Record stock movement to cloud
          try {
            await cloudRepo.createStockMovement(CloudStockMovement(
              id: 'sm-${DateTime.now().millisecondsSinceEpoch}',
              materialId: id,
              tenantId: material.tenantId,
              previousStock: previousStock,
              newStock: newStock,
              change: newStock - previousStock,
              reason: reason,
              note: note,
              timestamp: DateTime.now(),
            ));
          } catch (e) {
            debugPrint('Warning: Failed to record stock movement to cloud: $e');
          }

          await loadMaterials();
          return;
        }
      } catch (e) {
        debugPrint('Cloud stock update failed, falling back to local: $e');
      }
    }

    final repository = ref.read(materialRepositoryProvider);
    final result =
        await repository.updateStock(id, newStock, reason: reason, note: note);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to update stock');
    }
    await loadMaterials();
  }

  Future<List<mat.Material>> getLowStockMaterials() async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return [];

    final repository = ref.read(materialRepositoryProvider);
    return repository.getLowStockMaterials(authState.tenant!.id);
  }

  /// Get stock movements for a specific material
  /// Requirements 3.2: Record stock movement with timestamp and reason
  Future<List<StockMovement>> getStockMovements(String materialId) async {
    final repository = ref.read(materialRepositoryProvider);
    return repository.getStockMovements(materialId);
  }
}
