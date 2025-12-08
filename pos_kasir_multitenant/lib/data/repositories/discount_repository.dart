import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/discount.dart';
import '../mock/mock_data.dart';
import 'product_repository.dart'; // For RepositoryResult

/// Repository for managing discount data
/// Requirements 14.1, 14.6, 14.7: Discount management operations
class DiscountRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - initialized from MockData
  static List<Discount>? _webDiscounts;

  /// Initialize web discounts from MockData if not already done
  static List<Discount> get webDiscounts {
    _webDiscounts ??= List<Discount>.from(MockData.discounts);
    return _webDiscounts!;
  }

  /// Get all discounts for a tenant
  Future<List<Discount>> getDiscounts(String tenantId) async {
    try {
      if (kIsWeb) {
        return webDiscounts.where((d) => d.tenantId == tenantId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final db = await _db.database;
      final results = await db.query(
        'discounts',
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
        orderBy: 'created_at DESC',
      );

      return results.map((map) => Discount.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting discounts: $e');
      return [];
    }
  }

  /// Get active discounts for a tenant
  /// Requirements 14.7: Display list of currently valid discounts
  Future<List<Discount>> getActiveDiscounts(String tenantId) async {
    try {
      final discounts = await getDiscounts(tenantId);
      return discounts.where((d) => d.isCurrentlyValid).toList();
    } catch (e) {
      debugPrint('Error getting active discounts: $e');
      return [];
    }
  }

  /// Get a single discount by ID
  Future<Discount?> getDiscount(String id) async {
    try {
      if (kIsWeb) {
        final index = webDiscounts.indexWhere((d) => d.id == id);
        return index != -1 ? webDiscounts[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'discounts',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return Discount.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting discount: $e');
      return null;
    }
  }

  /// Get discount by promo code
  /// Requirements 14.6: Validate promo code and apply discount
  Future<Discount?> getByPromoCode(String tenantId, String code) async {
    try {
      if (kIsWeb) {
        final index = webDiscounts.indexWhere(
          (d) =>
              d.tenantId == tenantId &&
              d.promoCode?.toLowerCase() == code.toLowerCase() &&
              d.isCurrentlyValid,
        );
        return index != -1 ? webDiscounts[index] : null;
      }

      final db = await _db.database;
      final now = DateTime.now().toIso8601String();
      final results = await db.query(
        'discounts',
        where:
            'tenant_id = ? AND promo_code = ? COLLATE NOCASE AND is_active = 1 AND valid_from <= ? AND valid_until >= ?',
        whereArgs: [tenantId, code, now, now],
      );

      if (results.isEmpty) return null;
      return Discount.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting discount by promo code: $e');
      return null;
    }
  }

  /// Create a new discount
  /// Requirements 14.1: Save discount details
  /// Multi-branch support: Optional branchId for branch-specific discounts
  Future<RepositoryResult<Discount>> createDiscount(Discount discount) async {
    try {
      // Use model validation
      final validationError = discount.validate();
      if (validationError != null) {
        return RepositoryResult.failure(validationError);
      }

      // Check for duplicate promo code
      if (discount.hasPromoCode) {
        final existing =
            await getByPromoCode(discount.tenantId, discount.promoCode!);
        if (existing != null) {
          return RepositoryResult.failure('Kode promo sudah digunakan');
        }
      }

      if (kIsWeb) {
        // Check for duplicate ID
        final existingIndex =
            webDiscounts.indexWhere((d) => d.id == discount.id);
        if (existingIndex != -1) {
          return RepositoryResult.failure('Diskon dengan ID ini sudah ada');
        }
        webDiscounts.add(discount);
        return RepositoryResult.success(discount);
      }

      final db = await _db.database;
      await db.insert('discounts', discount.toMap());
      return RepositoryResult.success(discount);
    } catch (e) {
      debugPrint('Error creating discount: $e');
      return RepositoryResult.failure('Gagal membuat diskon: $e');
    }
  }

  /// Update an existing discount
  /// Multi-tenant validation: Only allows updating discounts belonging to the same tenant
  Future<RepositoryResult<Discount>> updateDiscount(Discount discount) async {
    try {
      // Use model validation
      final validationError = discount.validate();
      if (validationError != null) {
        return RepositoryResult.failure(validationError);
      }

      // Ensure updatedAt is set
      final discountToUpdate = discount.copyWith(updatedAt: DateTime.now());

      if (kIsWeb) {
        final index = webDiscounts.indexWhere((d) => d.id == discount.id);
        if (index == -1) {
          return RepositoryResult.failure('Diskon tidak ditemukan');
        }
        // Multi-tenant validation
        if (webDiscounts[index].tenantId != discount.tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat mengubah diskon tenant lain');
        }
        webDiscounts[index] = discountToUpdate;
        return RepositoryResult.success(discountToUpdate);
      }

      final db = await _db.database;
      // Multi-tenant validation: Only update if tenant matches
      final rowsAffected = await db.update(
        'discounts',
        discountToUpdate.toMap(),
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [discount.id, discount.tenantId],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure(
            'Diskon tidak ditemukan atau tidak dapat diubah');
      }
      return RepositoryResult.success(discountToUpdate);
    } catch (e) {
      debugPrint('Error updating discount: $e');
      return RepositoryResult.failure('Gagal mengubah diskon: $e');
    }
  }

  /// Delete a discount
  /// Validates tenant ownership before deletion
  Future<RepositoryResult<bool>> deleteDiscount(String id,
      {String? tenantId}) async {
    try {
      if (kIsWeb) {
        final index = webDiscounts.indexWhere((d) => d.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Diskon tidak ditemukan');
        }
        // Validate tenant ownership if tenantId provided
        if (tenantId != null && webDiscounts[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk menghapus diskon ini');
        }
        webDiscounts.removeAt(index);
        return RepositoryResult.success(true);
      }

      final db = await _db.database;

      // If tenantId provided, validate ownership first
      if (tenantId != null) {
        final existing = await db.query(
          'discounts',
          where: 'id = ? AND tenant_id = ?',
          whereArgs: [id, tenantId],
        );
        if (existing.isEmpty) {
          return RepositoryResult.failure(
              'Diskon tidak ditemukan atau tidak memiliki akses');
        }
      }

      final rowsAffected = await db.delete(
        'discounts',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Diskon tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting discount: $e');
      return RepositoryResult.failure('Gagal menghapus diskon: $e');
    }
  }

  /// Toggle discount active status
  Future<RepositoryResult<Discount>> toggleStatus(
      String id, bool isActive) async {
    try {
      final discount = await getDiscount(id);
      if (discount == null) {
        return RepositoryResult.failure('Diskon tidak ditemukan');
      }

      final updated =
          discount.copyWith(isActive: isActive, updatedAt: DateTime.now());
      return updateDiscount(updated);
    } catch (e) {
      debugPrint('Error toggling discount status: $e');
      return RepositoryResult.failure('Gagal mengubah status: $e');
    }
  }

  /// Get discounts filtered by branch (multi-branch support)
  /// If branchId is null, returns discounts available for all branches
  Future<List<Discount>> getDiscountsByBranch(
    String tenantId,
    String? branchId,
  ) async {
    try {
      final discounts = await getDiscounts(tenantId);
      // Return discounts that are either for all branches (null) or specific branch
      return discounts
          .where((d) => d.branchId == null || d.branchId == branchId)
          .toList();
    } catch (e) {
      debugPrint('Error getting discounts by branch: $e');
      return [];
    }
  }

  /// Get active discounts for a specific branch
  Future<List<Discount>> getActiveDiscountsByBranch(
    String tenantId,
    String? branchId,
  ) async {
    try {
      final discounts = await getDiscountsByBranch(tenantId, branchId);
      return discounts.where((d) => d.isCurrentlyValid).toList();
    } catch (e) {
      debugPrint('Error getting active discounts by branch: $e');
      return [];
    }
  }

  /// Get discounts by type
  Future<List<Discount>> getDiscountsByType(
    String tenantId,
    DiscountType type,
  ) async {
    try {
      final discounts = await getDiscounts(tenantId);
      return discounts.where((d) => d.type == type).toList();
    } catch (e) {
      debugPrint('Error getting discounts by type: $e');
      return [];
    }
  }

  /// Get discounts with promo codes
  Future<List<Discount>> getPromoCodeDiscounts(String tenantId) async {
    try {
      final discounts = await getDiscounts(tenantId);
      return discounts.where((d) => d.hasPromoCode).toList();
    } catch (e) {
      debugPrint('Error getting promo code discounts: $e');
      return [];
    }
  }

  /// Get expired discounts
  Future<List<Discount>> getExpiredDiscounts(String tenantId) async {
    try {
      final discounts = await getDiscounts(tenantId);
      final now = DateTime.now();
      return discounts.where((d) => now.isAfter(d.validUntil)).toList();
    } catch (e) {
      debugPrint('Error getting expired discounts: $e');
      return [];
    }
  }

  /// Get discount count by status
  Future<Map<String, int>> getDiscountStats(String tenantId) async {
    try {
      final discounts = await getDiscounts(tenantId);
      final now = DateTime.now();

      return {
        'total': discounts.length,
        'active': discounts.where((d) => d.isCurrentlyValid).length,
        'inactive': discounts.where((d) => !d.isActive).length,
        'expired': discounts.where((d) => now.isAfter(d.validUntil)).length,
        'upcoming': discounts.where((d) => now.isBefore(d.validFrom)).length,
      };
    } catch (e) {
      debugPrint('Error getting discount stats: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'expired': 0,
        'upcoming': 0
      };
    }
  }
}
