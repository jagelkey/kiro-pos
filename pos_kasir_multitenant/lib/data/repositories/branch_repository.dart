import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/branch.dart';
import '../mock/mock_data.dart';
import 'product_repository.dart'; // For RepositoryResult

/// Repository for managing branch data
/// Requirements 11.1, 11.2, 11.5: Branch management operations
class BranchRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - initialized from MockData
  static List<Branch>? _webBranches;

  /// Initialize web branches from MockData if not already done
  static List<Branch> get webBranches {
    _webBranches ??= List<Branch>.from(MockData.branches);
    return _webBranches!;
  }

  /// Get all branches for an owner
  /// Requirements 11.1: Owner can create and manage multiple branches
  Future<List<Branch>> getBranchesByOwner(String ownerId) async {
    try {
      if (kIsWeb) {
        return webBranches.where((b) => b.ownerId == ownerId).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      }

      final db = await _db.database;
      final results = await db.query(
        'branches',
        where: 'owner_id = ?',
        whereArgs: [ownerId],
        orderBy: 'name ASC',
      );

      return results.map((map) => Branch.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting branches: $e');
      return [];
    }
  }

  /// Get active branches for an owner
  Future<List<Branch>> getActiveBranches(String ownerId) async {
    try {
      final branches = await getBranchesByOwner(ownerId);
      return branches.where((b) => b.isActive).toList();
    } catch (e) {
      debugPrint('Error getting active branches: $e');
      return [];
    }
  }

  /// Get a single branch by ID
  Future<Branch?> getBranch(String id) async {
    try {
      if (kIsWeb) {
        final index = webBranches.indexWhere((b) => b.id == id);
        return index != -1 ? webBranches[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'branches',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return Branch.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting branch: $e');
      return null;
    }
  }

  /// Get branch by code
  /// Requirements 11.3: Each branch has unique code
  Future<Branch?> getBranchByCode(String code) async {
    try {
      if (kIsWeb) {
        final index = webBranches.indexWhere(
          (b) => b.code.toLowerCase() == code.toLowerCase(),
        );
        return index != -1 ? webBranches[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'branches',
        where: 'code = ? COLLATE NOCASE',
        whereArgs: [code],
      );

      if (results.isEmpty) return null;
      return Branch.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting branch by code: $e');
      return null;
    }
  }

  /// Create a new branch
  /// Requirements 11.1: Owner can create branches
  Future<RepositoryResult<Branch>> createBranch(Branch branch) async {
    try {
      // Validate required fields
      if (branch.name.trim().isEmpty) {
        return RepositoryResult.failure('Branch name is required');
      }
      if (branch.code.trim().isEmpty) {
        return RepositoryResult.failure('Branch code is required');
      }

      // Check for duplicate code
      final existing = await getBranchByCode(branch.code);
      if (existing != null) {
        return RepositoryResult.failure('Branch code already exists');
      }

      if (kIsWeb) {
        webBranches.add(branch);
        return RepositoryResult.success(branch);
      }

      final db = await _db.database;
      await db.insert('branches', branch.toMap());
      return RepositoryResult.success(branch);
    } catch (e) {
      debugPrint('Error creating branch: $e');
      return RepositoryResult.failure('Failed to create branch: $e');
    }
  }

  /// Update an existing branch
  /// Requirements 11.2: Owner can update branch settings
  Future<RepositoryResult<Branch>> updateBranch(Branch branch) async {
    try {
      // Validate required fields
      if (branch.name.trim().isEmpty) {
        return RepositoryResult.failure('Branch name is required');
      }

      final updated = branch.copyWith(updatedAt: DateTime.now());

      if (kIsWeb) {
        final index = webBranches.indexWhere((b) => b.id == branch.id);
        if (index == -1) {
          return RepositoryResult.failure('Branch not found');
        }
        webBranches[index] = updated;
        return RepositoryResult.success(updated);
      }

      final db = await _db.database;
      final rowsAffected = await db.update(
        'branches',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [branch.id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Branch not found');
      }
      return RepositoryResult.success(updated);
    } catch (e) {
      debugPrint('Error updating branch: $e');
      return RepositoryResult.failure('Failed to update branch: $e');
    }
  }

  /// Deactivate a branch (soft delete)
  /// Requirements 11.5: Owner can deactivate branches
  Future<RepositoryResult<Branch>> deactivateBranch(String id) async {
    try {
      final branch = await getBranch(id);
      if (branch == null) {
        return RepositoryResult.failure('Branch not found');
      }

      final updated = branch.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
      return updateBranch(updated);
    } catch (e) {
      debugPrint('Error deactivating branch: $e');
      return RepositoryResult.failure('Failed to deactivate branch: $e');
    }
  }

  /// Activate a branch
  Future<RepositoryResult<Branch>> activateBranch(String id) async {
    try {
      final branch = await getBranch(id);
      if (branch == null) {
        return RepositoryResult.failure('Branch not found');
      }

      final updated = branch.copyWith(
        isActive: true,
        updatedAt: DateTime.now(),
      );
      return updateBranch(updated);
    } catch (e) {
      debugPrint('Error activating branch: $e');
      return RepositoryResult.failure('Failed to activate branch: $e');
    }
  }

  /// Delete a branch permanently
  /// Validates owner ownership before deletion
  Future<RepositoryResult<bool>> deleteBranch(String id,
      {String? ownerId}) async {
    try {
      if (kIsWeb) {
        final index = webBranches.indexWhere((b) => b.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Cabang tidak ditemukan');
        }
        // Validate owner ownership if ownerId provided
        if (ownerId != null && webBranches[index].ownerId != ownerId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk menghapus cabang ini');
        }
        webBranches.removeAt(index);
        return RepositoryResult.success(true);
      }

      final db = await _db.database;

      // If ownerId provided, validate ownership first
      if (ownerId != null) {
        final existing = await db.query(
          'branches',
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
        if (existing.isEmpty) {
          return RepositoryResult.failure(
              'Cabang tidak ditemukan atau tidak memiliki akses');
        }
      }

      final rowsAffected = await db.delete(
        'branches',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Cabang tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      return RepositoryResult.failure('Gagal menghapus cabang: $e');
    }
  }

  /// Get branch count for an owner
  Future<int> getBranchCount(String ownerId) async {
    try {
      final branches = await getBranchesByOwner(ownerId);
      return branches.length;
    } catch (e) {
      debugPrint('Error getting branch count: $e');
      return 0;
    }
  }
}
