import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/branch.dart';
import '../../data/models/user.dart';
import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../data/repositories/product_repository.dart'; // For RepositoryResult
import '../auth/auth_provider.dart';

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

final cloudBranchRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider for branch list
final branchListProvider =
    StateNotifierProvider<BranchListNotifier, AsyncValue<List<Branch>>>((ref) {
  return BranchListNotifier(ref);
});

class BranchListNotifier extends StateNotifier<AsyncValue<List<Branch>>> {
  final Ref ref;
  final BranchRepository _repository = BranchRepository();

  BranchListNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadBranches();
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

  /// Queue branch operation for sync when back online (Android only)
  Future<void> _queueForSync(String operation, Branch branch) async {
    if (kIsWeb) return; // Web doesn't support offline sync

    try {
      final syncOp = SyncOperation(
        id: '${branch.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'branches',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: branch.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue branch sync operation: $e');
    }
  }

  Future<void> loadBranches() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      final user = authState.user;

      if (user == null) {
        state = AsyncValue.error('User tidak ditemukan', StackTrace.current);
        return;
      }

      // Only owner can view branches
      if (user.role != UserRole.owner) {
        state = AsyncValue.error(
            'Hanya Owner yang dapat mengakses cabang', StackTrace.current);
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          final branches = await cloudRepo.getBranchesByOwner(user.id);
          state = AsyncValue.data(branches);
          return;
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      final branches = await _repository.getBranchesByOwner(user.id);
      state = AsyncValue.data(branches);
    } catch (e, st) {
      state = AsyncValue.error('Gagal memuat data cabang: $e', st);
    }
  }

  /// Create a new branch with offline support
  Future<RepositoryResult<Branch>> createBranch(Branch branch) async {
    try {
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          final created = await cloudRepo.createBranch(branch);
          await loadBranches(); // Refresh list
          return RepositoryResult.success(created);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud branch create failed, saving locally: $e');
            final result = await _repository.createBranch(branch);
            if (result.success) {
              await _queueForSync('insert', result.data!);
              await loadBranches();
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal membuat cabang: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.createBranch(branch);
      if (result.success) {
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('insert', result.data!);
        }
        await loadBranches();
      }
      return result;
    } catch (e) {
      return RepositoryResult.failure('Gagal membuat cabang: $e');
    }
  }

  /// Update an existing branch with offline support
  Future<RepositoryResult<Branch>> updateBranch(Branch branch) async {
    try {
      final isOnline = await _checkConnectivity();
      final branchToUpdate = branch.copyWith(updatedAt: DateTime.now());

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          await cloudRepo.updateBranch(branchToUpdate);
          await loadBranches(); // Refresh list
          return RepositoryResult.success(branchToUpdate);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud branch update failed, saving locally: $e');
            final result = await _repository.updateBranch(branchToUpdate);
            if (result.success) {
              await _queueForSync('update', result.data!);
              await loadBranches();
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal memperbarui cabang: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.updateBranch(branchToUpdate);
      if (result.success) {
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('update', result.data!);
        }
        await loadBranches();
      }
      return result;
    } catch (e) {
      return RepositoryResult.failure('Gagal memperbarui cabang: $e');
    }
  }

  /// Delete a branch with offline support
  Future<RepositoryResult<bool>> deleteBranch(String id,
      {String? ownerId}) async {
    try {
      final isOnline = await _checkConnectivity();

      // Find branch for sync queue (before deletion)
      final Branch branchToDelete;
      final currentState = state;
      if (currentState is AsyncData<List<Branch>>) {
        branchToDelete = currentState.value.firstWhere(
          (b) => b.id == id,
          orElse: () => Branch(
            id: id,
            ownerId: ownerId ?? '',
            name: '',
            code: '',
            createdAt: DateTime.now(),
          ),
        );
      } else {
        branchToDelete = Branch(
          id: id,
          ownerId: ownerId ?? '',
          name: '',
          code: '',
          createdAt: DateTime.now(),
        );
      }

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          await cloudRepo.deleteBranch(id);
          await loadBranches(); // Refresh list
          return RepositoryResult.success(true);
        } catch (e) {
          // Offline fallback: delete locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud branch delete failed, deleting locally: $e');
            final result = await _repository.deleteBranch(id, ownerId: ownerId);
            if (result.success) {
              await _queueForSync('delete', branchToDelete);
              await loadBranches();
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal menghapus cabang: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.deleteBranch(id, ownerId: ownerId);
      if (result.success) {
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('delete', branchToDelete);
        }
        await loadBranches();
      }
      return result;
    } catch (e) {
      return RepositoryResult.failure('Gagal menghapus cabang: $e');
    }
  }

  /// Toggle branch active status with offline support
  Future<RepositoryResult<Branch>> toggleStatus(
      String id, bool isActive) async {
    try {
      final isOnline = await _checkConnectivity();

      // Find the branch to update
      Branch? branchToUpdate;
      final currentState = state;
      if (currentState is AsyncData<List<Branch>>) {
        final index = currentState.value.indexWhere((b) => b.id == id);
        if (index != -1) {
          branchToUpdate = currentState.value[index].copyWith(
            isActive: isActive,
            updatedAt: DateTime.now(),
          );
        }
      }

      if (branchToUpdate == null) {
        return RepositoryResult.failure('Cabang tidak ditemukan');
      }

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudBranchRepositoryProvider);
          await cloudRepo.updateBranch(branchToUpdate);
          await loadBranches(); // Refresh list
          return RepositoryResult.success(branchToUpdate);
        } catch (e) {
          // Offline fallback: update locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud branch toggle failed, updating locally: $e');
            final result = isActive
                ? await _repository.activateBranch(id)
                : await _repository.deactivateBranch(id);
            if (result.success) {
              await _queueForSync('update', result.data!);
              await loadBranches();
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal mengubah status: $e');
          }
        }
      }

      // Local mode
      final result = isActive
          ? await _repository.activateBranch(id)
          : await _repository.deactivateBranch(id);
      if (result.success) {
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('update', result.data!);
        }
        await loadBranches();
      }
      return result;
    } catch (e) {
      return RepositoryResult.failure('Gagal mengubah status: $e');
    }
  }

  /// Retry loading after error
  void retry() => loadBranches();

  BranchRepository get repository => _repository;
}
