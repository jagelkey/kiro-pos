import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/material.dart' as mat;
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/cloud_repository.dart'
    show CloudRepository, CloudStockMovement;
import '../auth/auth_provider.dart';

final materialRepositoryProvider = Provider((ref) => MaterialRepository());
final cloudMaterialRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider untuk cek konektivitas
final materialConnectivityProvider = FutureProvider<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return _checkConnectivityResults(results);
});

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

  /// Queue operation for sync when back online
  Future<void> _queueForSync(String operation, mat.Material material) async {
    try {
      final syncOp = SyncOperation(
        id: '${material.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'materials',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: material.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue sync operation: $e');
    }
  }

  Future<void> loadMaterials() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final tenantId = authState.tenant!.id;
      if (tenantId.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final branchId = authState.user?.branchId;
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
          final materials =
              await cloudRepo.getMaterials(tenantId, branchId: branchId);
          state = AsyncValue.data(materials);
          return;
        } catch (e) {
          debugPrint('Cloud materials load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      final repository = ref.read(materialRepositoryProvider);
      final materials =
          await repository.getMaterials(tenantId, branchId: branchId);
      state = AsyncValue.data(materials);
    } catch (e, stack) {
      debugPrint('Error loading materials: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addMaterial(mat.Material material) async {
    try {
      final tenantId = _validateTenant();

      // Ensure material has correct tenantId
      final materialWithTenant = mat.Material(
        id: material.id,
        tenantId: tenantId,
        name: material.name,
        stock: material.stock,
        unit: material.unit,
        minStock: material.minStock,
        category: material.category,
        createdAt: material.createdAt,
      );

      // Validate material data
      if (materialWithTenant.name.trim().isEmpty) {
        throw Exception('Nama bahan baku wajib diisi');
      }
      if (materialWithTenant.stock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      if (materialWithTenant.unit.trim().isEmpty) {
        throw Exception('Satuan wajib diisi');
      }
      if (materialWithTenant.stock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
          await cloudRepo.createMaterial(materialWithTenant);
          await loadMaterials();
          return;
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud create failed, saving locally: $e');
            final repository = ref.read(materialRepositoryProvider);
            final result = await repository.createMaterial(materialWithTenant);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal membuat bahan baku');
            }
            // Queue for sync when online
            await _queueForSync('insert', materialWithTenant);
            await loadMaterials();
            return;
          } else {
            rethrow;
          }
        }
      }

      // Local mode
      final repository = ref.read(materialRepositoryProvider);
      final result = await repository.createMaterial(materialWithTenant);
      if (!result.success) {
        throw Exception(result.error ?? 'Gagal membuat bahan baku');
      }
      // Queue for sync when online (Android only)
      if (!kIsWeb && AppConfig.useSupabase) {
        await _queueForSync('insert', materialWithTenant);
      }
      await loadMaterials();
    } catch (e) {
      debugPrint('Error adding material: $e');
      rethrow;
    }
  }

  Future<void> updateMaterial(mat.Material material) async {
    try {
      final tenantId = _validateTenant();

      // Ensure material has correct tenantId
      final materialWithTenant = mat.Material(
        id: material.id,
        tenantId: tenantId,
        name: material.name,
        stock: material.stock,
        unit: material.unit,
        minStock: material.minStock,
        category: material.category,
        createdAt: material.createdAt,
      );

      // Validate material data
      if (materialWithTenant.name.trim().isEmpty) {
        throw Exception('Nama bahan baku wajib diisi');
      }
      if (materialWithTenant.stock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      if (materialWithTenant.unit.trim().isEmpty) {
        throw Exception('Satuan wajib diisi');
      }
      if (materialWithTenant.stock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
          await cloudRepo.updateMaterial(materialWithTenant);
          await loadMaterials();
          return;
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud update failed, saving locally: $e');
            final repository = ref.read(materialRepositoryProvider);
            final result = await repository.updateMaterial(materialWithTenant);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal memperbarui bahan baku');
            }
            // Queue for sync when online
            await _queueForSync('update', materialWithTenant);
            await loadMaterials();
            return;
          } else {
            rethrow;
          }
        }
      }

      // Local mode
      final repository = ref.read(materialRepositoryProvider);
      final result = await repository.updateMaterial(materialWithTenant);
      if (!result.success) {
        throw Exception(result.error ?? 'Gagal memperbarui bahan baku');
      }
      // Queue for sync when online (Android only)
      if (!kIsWeb && AppConfig.useSupabase) {
        await _queueForSync('update', materialWithTenant);
      }
      await loadMaterials();
    } catch (e) {
      debugPrint('Error updating material: $e');
      rethrow;
    }
  }

  Future<void> deleteMaterial(String id) async {
    try {
      final tenantId = _validateTenant();

      if (id.isEmpty) {
        throw Exception('ID bahan baku tidak valid');
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudMaterialRepositoryProvider);
          await cloudRepo.deleteMaterial(id);
          await loadMaterials();
          return;
        } catch (e) {
          // Offline fallback: delete locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud delete failed, deleting locally: $e');
            final repository = ref.read(materialRepositoryProvider);
            final result =
                await repository.deleteMaterial(id, tenantId: tenantId);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal menghapus bahan baku');
            }
            // Queue for sync when online - create dummy material for sync data
            final dummyMaterial = mat.Material(
              id: id,
              tenantId: tenantId,
              name: '',
              stock: 0,
              unit: '',
              createdAt: DateTime.now(),
            );
            await _queueForSync('delete', dummyMaterial);
            await loadMaterials();
            return;
          } else {
            rethrow;
          }
        }
      }

      // Local mode
      final repository = ref.read(materialRepositoryProvider);
      final result = await repository.deleteMaterial(id, tenantId: tenantId);
      if (!result.success) {
        throw Exception(result.error ?? 'Gagal menghapus bahan baku');
      }
      // Queue for sync when online (Android only)
      if (!kIsWeb && AppConfig.useSupabase) {
        final dummyMaterial = mat.Material(
          id: id,
          tenantId: tenantId,
          name: '',
          stock: 0,
          unit: '',
          createdAt: DateTime.now(),
        );
        await _queueForSync('delete', dummyMaterial);
      }
      await loadMaterials();
    } catch (e) {
      debugPrint('Error deleting material: $e');
      rethrow;
    }
  }

  Future<void> updateStock(String id, double newStock,
      {required String reason, String? note}) async {
    try {
      // Validate tenant - ensures user is logged in
      _validateTenant();

      if (id.isEmpty) {
        throw Exception('ID bahan baku tidak valid');
      }
      if (newStock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      if (newStock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
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
              debugPrint(
                  'Warning: Failed to record stock movement to cloud: $e');
            }

            await loadMaterials();
            return;
          } else {
            throw Exception('Bahan baku tidak ditemukan');
          }
        } catch (e) {
          // Offline fallback
          if (!kIsWeb) {
            debugPrint('Cloud stock update failed, updating locally: $e');
            final repository = ref.read(materialRepositoryProvider);
            final result = await repository.updateStock(id, newStock,
                reason: reason, note: note);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal memperbarui stok');
            }
            // Queue for sync - get material data for sync
            if (result.data != null) {
              await _queueForSync('update', result.data!);
            }
            await loadMaterials();
            return;
          } else {
            rethrow;
          }
        }
      }

      // Local mode
      final repository = ref.read(materialRepositoryProvider);
      final result = await repository.updateStock(id, newStock,
          reason: reason, note: note);
      if (!result.success) {
        throw Exception(result.error ?? 'Gagal memperbarui stok');
      }
      // Queue for sync when online (Android only)
      if (!kIsWeb && AppConfig.useSupabase && result.data != null) {
        await _queueForSync('update', result.data!);
      }
      await loadMaterials();
    } catch (e) {
      debugPrint('Error updating stock: $e');
      rethrow;
    }
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
