import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/cloud_repository.dart';
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

final userRepositoryProvider = Provider((ref) => UserRepository());
final cloudUserRepositoryProvider = Provider((ref) => CloudRepository());

final usersProvider =
    StateNotifierProvider<UsersNotifier, AsyncValue<List<User>>>((ref) {
  return UsersNotifier(ref);
});

/// Provider untuk mengecek apakah user saat ini bisa mengakses halaman pengguna
/// Requirements 7.3: Restrict owner-only features for cashier role
final canAccessUsersPageProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return false;
  // Hanya owner dan manager yang bisa mengakses halaman pengguna
  return user.hasManagerAccess;
});

/// Provider untuk mengecek apakah user bisa mengelola user lain (CRUD)
final canManageUsersProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return false;
  // Hanya owner yang bisa CRUD user
  return user.hasOwnerAccess;
});

class UsersNotifier extends StateNotifier<AsyncValue<List<User>>> {
  final Ref ref;

  UsersNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadUsers();
  }

  /// Get current tenant ID from auth state
  String? get _currentTenantId => ref.read(authProvider).tenant?.id;

  /// Get current user from auth state
  User? get _currentUser => ref.read(authProvider).user;

  /// Check if current user has permission to manage users
  bool get _canManageUsers => _currentUser?.hasOwnerAccess ?? false;

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Queue user operation for sync when back online (Android only)
  Future<void> _queueForSync(String operation, User user) async {
    if (kIsWeb) return; // Web doesn't support offline sync

    try {
      final syncOp = SyncOperation(
        id: '${user.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'users',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: user.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue user sync operation: $e');
    }
  }

  Future<void> loadUsers() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Validasi akses - hanya owner/manager yang bisa melihat daftar user
      if (authState.user != null && !authState.user!.hasManagerAccess) {
        state = AsyncValue.error(
          'Anda tidak memiliki akses ke halaman ini',
          StackTrace.current,
        );
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudUserRepositoryProvider);
          final users = await cloudRepo.getUsers(authState.tenant!.id);
          state = AsyncValue.data(users);
          return;
        } catch (e) {
          debugPrint('Cloud users load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      final repository = ref.read(userRepositoryProvider);
      final users = await repository.getUsers(authState.tenant!.id);
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add a new user
  /// Requirements 7.1: Validate required fields and save to database
  Future<void> addUser(User user, {String? password}) async {
    // Validasi permission
    if (!_canManageUsers) {
      throw Exception('Anda tidak memiliki izin untuk menambah pengguna');
    }

    // Pastikan tenantId sesuai dengan tenant saat ini
    final tenantId = _currentTenantId;
    if (tenantId == null) {
      throw Exception('Tenant tidak ditemukan');
    }

    // Update user dengan tenantId yang benar
    final userWithTenant = user.copyWith(tenantId: tenantId);
    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.createUser(userWithTenant, password ?? 'password123');
        await loadUsers();
        return;
      } catch (e) {
        // Offline fallback: save locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud user create failed, saving locally: $e');
          final repository = ref.read(userRepositoryProvider);
          final result = await repository.createUser(userWithTenant);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal menambah pengguna');
          }
          // Queue for sync when online
          await _queueForSync('insert', userWithTenant);
          await loadUsers();
          return;
        } else {
          throw Exception('Gagal menambah pengguna: $e');
        }
      }
    }

    // Local mode
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.createUser(userWithTenant);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menambah pengguna');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('insert', userWithTenant);
    }
    await loadUsers();
  }

  /// Update an existing user
  /// Requirements 7.2: Persist active/inactive status
  Future<void> updateUser(User user) async {
    // Validasi permission
    if (!_canManageUsers) {
      throw Exception('Anda tidak memiliki izin untuk mengubah pengguna');
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.updateUser(user);
        await loadUsers();
        return;
      } catch (e) {
        // Offline fallback: save locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud user update failed, saving locally: $e');
          final repository = ref.read(userRepositoryProvider);
          final result = await repository.updateUser(user);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal mengubah pengguna');
          }
          // Queue for sync when online
          await _queueForSync('update', user);
          await loadUsers();
          return;
        } else {
          throw Exception('Gagal mengubah pengguna: $e');
        }
      }
    }

    // Local mode
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.updateUser(user);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah pengguna');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('update', user);
    }
    await loadUsers();
  }

  /// Delete a user
  Future<void> deleteUser(String id) async {
    // Validasi permission
    if (!_canManageUsers) {
      throw Exception('Anda tidak memiliki izin untuk menghapus pengguna');
    }

    // Cegah user menghapus dirinya sendiri
    if (_currentUser?.id == id) {
      throw Exception('Anda tidak dapat menghapus akun Anda sendiri');
    }

    final isOnline = await _checkConnectivity();

    // Find user for sync queue (before deletion)
    final User userToDelete;
    final currentState = state;
    if (currentState is AsyncData<List<User>>) {
      userToDelete = currentState.value.firstWhere(
        (u) => u.id == id,
        orElse: () => User(
          id: id,
          tenantId: _currentTenantId ?? '',
          email: '',
          name: '',
          role: UserRole.cashier,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      userToDelete = User(
        id: id,
        tenantId: _currentTenantId ?? '',
        email: '',
        name: '',
        role: UserRole.cashier,
        createdAt: DateTime.now(),
      );
    }

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.deleteUser(id);
        await loadUsers();
        return;
      } catch (e) {
        // Offline fallback: delete locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud user delete failed, deleting locally: $e');
          final repository = ref.read(userRepositoryProvider);
          final result =
              await repository.deleteUser(id, tenantId: _currentTenantId);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal menghapus pengguna');
          }
          // Queue for sync when online
          await _queueForSync('delete', userToDelete);
          await loadUsers();
          return;
        } else {
          throw Exception('Gagal menghapus pengguna: $e');
        }
      }
    }

    // Local mode
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.deleteUser(id, tenantId: _currentTenantId);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus pengguna');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('delete', userToDelete);
    }
    await loadUsers();
  }

  /// Toggle user active status
  /// Requirements 7.2: Persist active/inactive status
  Future<void> toggleUserStatus(String id, bool isActive) async {
    // Validasi permission
    if (!_canManageUsers) {
      throw Exception(
          'Anda tidak memiliki izin untuk mengubah status pengguna');
    }

    // Cegah user menonaktifkan dirinya sendiri
    if (_currentUser?.id == id && !isActive) {
      throw Exception('Anda tidak dapat menonaktifkan akun Anda sendiri');
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        final user = await cloudRepo.getUserById(id);
        if (user != null) {
          final updatedUser = user.copyWith(isActive: isActive);
          await cloudRepo.updateUser(updatedUser);
          await loadUsers();
          return;
        }
      } catch (e) {
        // Offline fallback: update locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud user status toggle failed, updating locally: $e');
          final repository = ref.read(userRepositoryProvider);
          final result = await repository.toggleUserStatus(
            id,
            isActive,
            tenantId: _currentTenantId,
          );
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal mengubah status pengguna');
          }
          // Queue for sync when online
          if (result.data != null) {
            await _queueForSync('update', result.data!);
          }
          await loadUsers();
          return;
        } else {
          throw Exception('Gagal mengubah status pengguna: $e');
        }
      }
    }

    // Local mode
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.toggleUserStatus(
      id,
      isActive,
      tenantId: _currentTenantId,
    );
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah status pengguna');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase && result.data != null) {
      await _queueForSync('update', result.data!);
    }
    await loadUsers();
  }
}
