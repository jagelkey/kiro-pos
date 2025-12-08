import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/user.dart';
import '../mock/mock_data.dart';
import 'product_repository.dart'; // For RepositoryResult

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - initialized from MockData
  static List<User>? _webUsersCache;
  static List<User> get _webUsers {
    _webUsersCache ??= List<User>.from(MockData.users);
    return _webUsersCache!;
  }

  /// Get all users for a tenant
  Future<List<User>> getUsers(String tenantId) async {
    try {
      if (kIsWeb) {
        return _webUsers.where((u) => u.tenantId == tenantId).toList();
      }

      final db = await _db.database;
      final results = await db.query(
        'users',
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
        orderBy: 'name ASC',
      );

      return results.map((map) => User.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting users: $e');
      return [];
    }
  }

  /// Get a single user by ID
  Future<User?> getUser(String id) async {
    try {
      if (kIsWeb) {
        final index = _webUsers.indexWhere((u) => u.id == id);
        return index != -1 ? _webUsers[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Get user by email for login validation
  /// Requirements 7.5: Check isActive status during login
  Future<User?> getUserByEmail(String email, String tenantId) async {
    try {
      if (kIsWeb) {
        final index = _webUsers.indexWhere(
          (u) => u.email == email && u.tenantId == tenantId,
        );
        return index != -1 ? _webUsers[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'users',
        where: 'email = ? AND tenant_id = ?',
        whereArgs: [email, tenantId],
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting user by email: $e');
      return null;
    }
  }

  /// Create a new user
  /// Requirements 7.1: Validate required fields and save to database
  Future<RepositoryResult<User>> createUser(User user) async {
    try {
      // Validate required fields
      if (user.tenantId.isEmpty) {
        return RepositoryResult.failure('Tenant ID tidak valid');
      }
      if (user.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama pengguna wajib diisi');
      }
      if (user.email.trim().isEmpty) {
        return RepositoryResult.failure('Email wajib diisi');
      }
      if (!user.email.contains('@')) {
        return RepositoryResult.failure('Format email tidak valid');
      }

      if (kIsWeb) {
        // Check for duplicate email (case-insensitive)
        final existingIndex = _webUsers.indexWhere(
          (u) =>
              u.email.toLowerCase() == user.email.toLowerCase() &&
              u.tenantId == user.tenantId,
        );
        if (existingIndex != -1) {
          return RepositoryResult.failure('Email sudah digunakan');
        }
        // Check for duplicate ID
        final idIndex = _webUsers.indexWhere((u) => u.id == user.id);
        if (idIndex != -1) {
          return RepositoryResult.failure('ID pengguna sudah ada');
        }
        _webUsers.add(user);
        return RepositoryResult.success(user);
      }

      final db = await _db.database;

      // Check for duplicate email (case-insensitive)
      final existing = await db.rawQuery(
        'SELECT * FROM users WHERE LOWER(email) = LOWER(?) AND tenant_id = ?',
        [user.email, user.tenantId],
      );
      if (existing.isNotEmpty) {
        return RepositoryResult.failure('Email sudah digunakan');
      }

      await db.insert('users', user.toMap());
      return RepositoryResult.success(user);
    } catch (e) {
      debugPrint('Error creating user: $e');
      return RepositoryResult.failure('Gagal menambah pengguna: $e');
    }
  }

  /// Update an existing user
  /// Requirements 7.2: Persist active/inactive status
  Future<RepositoryResult<User>> updateUser(User user) async {
    try {
      // Validate required fields
      if (user.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama pengguna wajib diisi');
      }
      if (user.email.trim().isEmpty) {
        return RepositoryResult.failure('Email wajib diisi');
      }
      if (!user.email.contains('@')) {
        return RepositoryResult.failure('Format email tidak valid');
      }

      if (kIsWeb) {
        final index = _webUsers.indexWhere((u) => u.id == user.id);
        if (index == -1) {
          return RepositoryResult.failure('Pengguna tidak ditemukan');
        }

        // Validate tenant ownership
        if (_webUsers[index].tenantId != user.tenantId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk mengubah pengguna ini');
        }

        // Check for duplicate email (excluding current user, case-insensitive)
        final emailIndex = _webUsers.indexWhere(
          (u) =>
              u.email.toLowerCase() == user.email.toLowerCase() &&
              u.tenantId == user.tenantId &&
              u.id != user.id,
        );
        if (emailIndex != -1) {
          return RepositoryResult.failure('Email sudah digunakan');
        }
        _webUsers[index] = user;
        return RepositoryResult.success(user);
      }

      final db = await _db.database;

      // Check for duplicate email (excluding current user, case-insensitive)
      final existing = await db.rawQuery(
        'SELECT * FROM users WHERE LOWER(email) = LOWER(?) AND tenant_id = ? AND id != ?',
        [user.email, user.tenantId, user.id],
      );
      if (existing.isNotEmpty) {
        return RepositoryResult.failure('Email sudah digunakan');
      }

      final rowsAffected = await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Pengguna tidak ditemukan');
      }
      return RepositoryResult.success(user);
    } catch (e) {
      debugPrint('Error updating user: $e');
      return RepositoryResult.failure('Gagal mengubah pengguna: $e');
    }
  }

  /// Delete a user by ID
  /// Validates tenant ownership before deletion
  Future<RepositoryResult<bool>> deleteUser(String id,
      {String? tenantId}) async {
    try {
      if (kIsWeb) {
        final index = _webUsers.indexWhere((u) => u.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Pengguna tidak ditemukan');
        }
        // Validate tenant ownership if tenantId provided
        if (tenantId != null && _webUsers[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk menghapus pengguna ini');
        }
        // Prevent deleting the last owner
        final user = _webUsers[index];
        if (user.role == UserRole.owner) {
          final ownerCount = _webUsers
              .where((u) =>
                  u.tenantId == user.tenantId && u.role == UserRole.owner)
              .length;
          if (ownerCount <= 1) {
            return RepositoryResult.failure(
                'Tidak dapat menghapus owner terakhir');
          }
        }
        _webUsers.removeAt(index);
        return RepositoryResult.success(true);
      }

      final db = await _db.database;

      // Get user first to validate
      final existing = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) {
        return RepositoryResult.failure('Pengguna tidak ditemukan');
      }

      final user = User.fromMap(existing.first);

      // Validate tenant ownership if tenantId provided
      if (tenantId != null && user.tenantId != tenantId) {
        return RepositoryResult.failure(
            'Tidak memiliki akses untuk menghapus pengguna ini');
      }

      // Prevent deleting the last owner
      if (user.role == UserRole.owner) {
        final ownerCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM users WHERE tenant_id = ? AND role = ?',
          [user.tenantId, UserRole.owner.name],
        );
        if ((ownerCount.first['count'] as int) <= 1) {
          return RepositoryResult.failure(
              'Tidak dapat menghapus owner terakhir');
        }
      }

      final rowsAffected = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Pengguna tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return RepositoryResult.failure('Gagal menghapus pengguna: $e');
    }
  }

  /// Toggle user active status
  /// Requirements 7.2: Persist active/inactive status
  Future<RepositoryResult<User>> toggleUserStatus(String id, bool isActive,
      {String? tenantId}) async {
    try {
      if (kIsWeb) {
        final index = _webUsers.indexWhere((u) => u.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Pengguna tidak ditemukan');
        }
        final user = _webUsers[index];

        // Validate tenant ownership if tenantId provided
        if (tenantId != null && user.tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk mengubah status pengguna ini');
        }

        // Prevent deactivating the last active owner
        if (!isActive && user.role == UserRole.owner) {
          final activeOwnerCount = _webUsers
              .where((u) =>
                  u.tenantId == user.tenantId &&
                  u.role == UserRole.owner &&
                  u.isActive &&
                  u.id != id)
              .length;
          if (activeOwnerCount == 0) {
            return RepositoryResult.failure(
                'Tidak dapat menonaktifkan owner terakhir yang aktif');
          }
        }

        final updatedUser = user.copyWith(isActive: isActive);
        _webUsers[index] = updatedUser;
        return RepositoryResult.success(updatedUser);
      }

      final db = await _db.database;

      // Get user first to validate
      final existing = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) {
        return RepositoryResult.failure('Pengguna tidak ditemukan');
      }

      final user = User.fromMap(existing.first);

      // Validate tenant ownership if tenantId provided
      if (tenantId != null && user.tenantId != tenantId) {
        return RepositoryResult.failure(
            'Tidak memiliki akses untuk mengubah status pengguna ini');
      }

      // Prevent deactivating the last active owner
      if (!isActive && user.role == UserRole.owner) {
        final activeOwnerCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM users WHERE tenant_id = ? AND role = ? AND is_active = 1 AND id != ?',
          [user.tenantId, UserRole.owner.name, id],
        );
        if ((activeOwnerCount.first['count'] as int) == 0) {
          return RepositoryResult.failure(
              'Tidak dapat menonaktifkan owner terakhir yang aktif');
        }
      }

      final rowsAffected = await db.update(
        'users',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Pengguna tidak ditemukan');
      }

      // Fetch and return the updated user
      final updatedUser = await getUser(id);
      return RepositoryResult.success(updatedUser);
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      return RepositoryResult.failure('Gagal mengubah status pengguna: $e');
    }
  }

  /// Get active users count for a tenant
  Future<int> getActiveUsersCount(String tenantId) async {
    try {
      final users = await getUsers(tenantId);
      return users.where((u) => u.isActive).length;
    } catch (e) {
      debugPrint('Error getting active users count: $e');
      return 0;
    }
  }

  /// Get users by role
  Future<List<User>> getUsersByRole(String tenantId, UserRole role) async {
    try {
      final users = await getUsers(tenantId);
      return users.where((u) => u.role == role).toList();
    } catch (e) {
      debugPrint('Error getting users by role: $e');
      return [];
    }
  }

  /// Reset web cache - useful for testing or when data needs to be refreshed
  /// This will reload data from MockData on next access
  static void resetWebCache() {
    _webUsersCache = null;
  }

  /// Check if email exists for a tenant (for validation before form submit)
  Future<bool> emailExists(String email, String tenantId,
      {String? excludeUserId}) async {
    try {
      if (kIsWeb) {
        return _webUsers.any((u) =>
            u.email.toLowerCase() == email.toLowerCase() &&
            u.tenantId == tenantId &&
            (excludeUserId == null || u.id != excludeUserId));
      }

      final db = await _db.database;
      String query =
          'SELECT COUNT(*) as count FROM users WHERE LOWER(email) = LOWER(?) AND tenant_id = ?';
      List<dynamic> args = [email, tenantId];

      if (excludeUserId != null) {
        query += ' AND id != ?';
        args.add(excludeUserId);
      }

      final result = await db.rawQuery(query, args);
      return (result.first['count'] as int) > 0;
    } catch (e) {
      debugPrint('Error checking email exists: $e');
      return false;
    }
  }
}
