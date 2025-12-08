import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../auth/auth_provider.dart';

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

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudUserRepositoryProvider);
          final users = await cloudRepo.getUsers(authState.tenant!.id);
          state = AsyncValue.data(users);
          return;
        } catch (e) {
          debugPrint('Cloud users load failed, falling back to local: $e');
        }
      }

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

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.createUser(userWithTenant, password ?? 'password123');
        await loadUsers();
        return;
      } catch (e) {
        debugPrint('Cloud user create failed, falling back to local: $e');
      }
    }

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.createUser(userWithTenant);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menambah pengguna');
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

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.updateUser(user);
        await loadUsers();
        return;
      } catch (e) {
        debugPrint('Cloud user update failed, falling back to local: $e');
      }
    }

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.updateUser(user);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah pengguna');
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

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudUserRepositoryProvider);
        await cloudRepo.deleteUser(id);
        await loadUsers();
        return;
      } catch (e) {
        debugPrint('Cloud user delete failed, falling back to local: $e');
      }
    }

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.deleteUser(id, tenantId: _currentTenantId);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus pengguna');
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

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
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
        debugPrint(
            'Cloud user status toggle failed, falling back to local: $e');
      }
    }

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.toggleUserStatus(
      id,
      isActive,
      tenantId: _currentTenantId,
    );
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah status pengguna');
    }
    await loadUsers();
  }
}
