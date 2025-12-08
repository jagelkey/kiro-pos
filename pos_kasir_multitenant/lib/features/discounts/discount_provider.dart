import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../data/models/discount.dart';
import '../../data/repositories/discount_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../data/repositories/product_repository.dart'; // For RepositoryResult

/// Provider for managing discount state and operations
/// Requirements 14.1, 14.7: Discount management and display
class DiscountProvider extends ChangeNotifier {
  final DiscountRepository _repository = DiscountRepository();
  final CloudRepository _cloudRepository = CloudRepository();

  List<Discount> _discounts = [];
  List<Discount> _activeDiscounts = [];
  Discount? _selectedDiscount;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Discount> get discounts => _discounts;
  List<Discount> get activeDiscounts => _activeDiscounts;
  Discount? get selectedDiscount => _selectedDiscount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all discounts for a tenant
  Future<void> loadDiscounts(String tenantId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          _discounts = await _cloudRepository.getDiscounts(tenantId);
          _activeDiscounts =
              _discounts.where((d) => d.isCurrentlyValid).toList();
          _isLoading = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Cloud discounts load failed, falling back to local: $e');
        }
      }

      _discounts = await _repository.getDiscounts(tenantId);
      _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
    } catch (e) {
      _error = 'Failed to load discounts: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load only active discounts for POS
  /// Requirements 14.7: Display list of currently valid discounts
  Future<void> loadActiveDiscounts(String tenantId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          _activeDiscounts =
              await _cloudRepository.getActiveDiscounts(tenantId);
          _isLoading = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint(
              'Cloud active discounts load failed, falling back to local: $e');
        }
      }

      _activeDiscounts = await _repository.getActiveDiscounts(tenantId);
    } catch (e) {
      _error = 'Failed to load active discounts: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a discount for application
  void selectDiscount(Discount? discount) {
    _selectedDiscount = discount;
    notifyListeners();
  }

  /// Clear selected discount
  void clearSelectedDiscount() {
    _selectedDiscount = null;
    notifyListeners();
  }

  /// Validate and apply promo code
  /// Requirements 14.6: Validate promo code and apply discount
  Future<RepositoryResult<Discount>> applyPromoCode(
      String tenantId, String code) async {
    if (code.trim().isEmpty) {
      return RepositoryResult.failure('Please enter a promo code');
    }

    try {
      Discount? discount;

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          discount = await _cloudRepository.getDiscountByPromoCode(
              code.trim(), tenantId);
        } catch (e) {
          debugPrint('Cloud promo check failed: $e');
          // Fallback to local on error
          discount = await _repository.getByPromoCode(tenantId, code.trim());
        }
      } else {
        discount = await _repository.getByPromoCode(tenantId, code.trim());
      }

      if (discount == null) {
        return RepositoryResult.failure('Invalid or expired promo code');
      }

      _selectedDiscount = discount;
      notifyListeners();
      return RepositoryResult.success(discount);
    } catch (e) {
      return RepositoryResult.failure('Failed to apply promo code: $e');
    }
  }

  /// Calculate discount amount for a subtotal
  /// Requirements 14.2, 14.3: Calculate percentage or fixed discount
  double calculateDiscountAmount(double subtotal) {
    if (_selectedDiscount == null) return 0;
    return _selectedDiscount!.calculateDiscount(subtotal);
  }

  /// Check if selected discount meets minimum purchase
  /// Requirements 14.5: Validate cart total before applying discount
  bool meetsMinimumPurchase(double subtotal) {
    if (_selectedDiscount == null) return true;
    return _selectedDiscount!.meetsMinPurchase(subtotal);
  }

  /// Get discount validation message
  String? getValidationMessage(double subtotal) {
    if (_selectedDiscount == null) return null;

    if (!_selectedDiscount!.isCurrentlyValid) {
      return 'This discount is no longer valid';
    }

    if (!_selectedDiscount!.meetsMinPurchase(subtotal)) {
      final minPurchase = _selectedDiscount!.minPurchase ?? 0;
      return 'Minimum purchase of Rp ${minPurchase.toStringAsFixed(0)} required';
    }

    return null;
  }

  /// Create a new discount
  /// Requirements 14.1: Save discount details
  Future<RepositoryResult<Discount>> createDiscount(Discount discount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final created = await _cloudRepository.createDiscount(discount);
          _discounts.insert(0, created);
          if (created.isCurrentlyValid) {
            _activeDiscounts.insert(0, created);
          }
          return RepositoryResult.success(created);
        } catch (e) {
          debugPrint('Cloud discount create failed, falling back to local: $e');
        }
      }

      final result = await _repository.createDiscount(discount);
      if (result.success) {
        _discounts.insert(0, result.data!);
        if (result.data!.isCurrentlyValid) {
          _activeDiscounts.insert(0, result.data!);
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing discount
  Future<RepositoryResult<Discount>> updateDiscount(Discount discount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          await _cloudRepository.updateDiscount(discount);
          final index = _discounts.indexWhere((d) => d.id == discount.id);
          if (index != -1) {
            _discounts[index] = discount;
          }
          _activeDiscounts =
              _discounts.where((d) => d.isCurrentlyValid).toList();
          return RepositoryResult.success(discount);
        } catch (e) {
          debugPrint('Cloud discount update failed, falling back to local: $e');
        }
      }

      final result = await _repository.updateDiscount(discount);
      if (result.success) {
        final index = _discounts.indexWhere((d) => d.id == discount.id);
        if (index != -1) {
          _discounts[index] = result.data!;
        }
        // Update active discounts list
        _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a discount with tenant validation
  Future<RepositoryResult<bool>> deleteDiscount(String id,
      {String? tenantId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          await _cloudRepository.deleteDiscount(id);
          _discounts.removeWhere((d) => d.id == id);
          _activeDiscounts.removeWhere((d) => d.id == id);
          if (_selectedDiscount?.id == id) {
            _selectedDiscount = null;
          }
          return RepositoryResult.success(true);
        } catch (e) {
          debugPrint('Cloud discount delete failed, falling back to local: $e');
        }
      }

      final result = await _repository.deleteDiscount(id, tenantId: tenantId);
      if (result.success) {
        _discounts.removeWhere((d) => d.id == id);
        _activeDiscounts.removeWhere((d) => d.id == id);
        if (_selectedDiscount?.id == id) {
          _selectedDiscount = null;
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle discount active status
  Future<RepositoryResult<Discount>> toggleStatus(
      String id, bool isActive) async {
    try {
      final result = await _repository.toggleStatus(id, isActive);
      if (result.success) {
        final index = _discounts.indexWhere((d) => d.id == id);
        if (index != -1) {
          _discounts[index] = result.data!;
        }
        _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
      }
      return result;
    } finally {
      notifyListeners();
    }
  }

  /// Get discounts filtered by type
  List<Discount> getDiscountsByType(DiscountType type) {
    return _discounts.where((d) => d.type == type).toList();
  }

  /// Get discounts with promo codes
  List<Discount> getPromoCodeDiscounts() {
    return _discounts.where((d) => d.hasPromoCode).toList();
  }

  /// Get discounts for a specific branch (multi-branch support)
  List<Discount> getDiscountsForBranch(String? branchId) {
    return _discounts
        .where((d) => d.branchId == null || d.branchId == branchId)
        .toList();
  }

  /// Get active discounts for a specific branch
  List<Discount> getActiveDiscountsForBranch(String? branchId) {
    return _activeDiscounts
        .where((d) => d.branchId == null || d.branchId == branchId)
        .toList();
  }

  /// Load discounts for a specific branch
  Future<void> loadDiscountsForBranch(String tenantId, String? branchId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _discounts = await _repository.getDiscountsByBranch(tenantId, branchId);
      _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
    } catch (e) {
      _error = 'Gagal memuat diskon: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get discount statistics
  Future<Map<String, int>> getDiscountStats(String tenantId) async {
    return _repository.getDiscountStats(tenantId);
  }

  /// Clear all state
  void clear() {
    _discounts = [];
    _activeDiscounts = [];
    _selectedDiscount = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
