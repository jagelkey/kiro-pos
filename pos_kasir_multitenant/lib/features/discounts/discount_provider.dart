import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/discount.dart';
import '../../data/repositories/discount_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../data/repositories/product_repository.dart'; // For RepositoryResult

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

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Queue discount operation for sync when back online (Android only)
  Future<void> _queueForSync(String operation, Discount discount) async {
    if (kIsWeb) return; // Web doesn't support offline sync

    try {
      final syncOp = SyncOperation(
        id: '${discount.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'discounts',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: discount.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue discount sync operation: $e');
    }
  }

  /// Load all discounts for a tenant
  Future<void> loadDiscounts(String tenantId) async {
    if (tenantId.isEmpty) {
      _error = 'Tenant ID tidak valid';
      _discounts = [];
      _activeDiscounts = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          _discounts = await _cloudRepository.getDiscounts(tenantId);
          _activeDiscounts =
              _discounts.where((d) => d.isCurrentlyValid).toList();
          _isLoading = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Cloud discounts load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      _discounts = await _repository.getDiscounts(tenantId);
      _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
    } catch (e) {
      _error = 'Gagal memuat diskon: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load only active discounts for POS
  /// Requirements 14.7: Display list of currently valid discounts
  Future<void> loadActiveDiscounts(String tenantId) async {
    if (tenantId.isEmpty) {
      _error = 'Tenant ID tidak valid';
      _activeDiscounts = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          _activeDiscounts =
              await _cloudRepository.getActiveDiscounts(tenantId);
          _isLoading = false;
          notifyListeners();
          return;
        } catch (e) {
          debugPrint(
              'Cloud active discounts load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      _activeDiscounts = await _repository.getActiveDiscounts(tenantId);
    } catch (e) {
      _error = 'Gagal memuat diskon aktif: $e';
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
      return RepositoryResult.failure('Masukkan kode promo');
    }

    if (tenantId.isEmpty) {
      return RepositoryResult.failure('Tenant ID tidak valid');
    }

    try {
      final isOnline = await _checkConnectivity();
      Discount? discount;

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
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
        return RepositoryResult.failure(
            'Kode promo tidak valid atau sudah kadaluarsa');
      }

      _selectedDiscount = discount;
      notifyListeners();
      return RepositoryResult.success(discount);
    } catch (e) {
      return RepositoryResult.failure('Gagal menerapkan kode promo: $e');
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
    // Validate discount
    final validationError = discount.validate();
    if (validationError != null) {
      return RepositoryResult.failure(validationError);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final created = await _cloudRepository.createDiscount(discount);
          _discounts.insert(0, created);
          if (created.isCurrentlyValid) {
            _activeDiscounts.insert(0, created);
          }
          return RepositoryResult.success(created);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud discount create failed, saving locally: $e');
            final result = await _repository.createDiscount(discount);
            if (result.success) {
              _discounts.insert(0, result.data!);
              if (result.data!.isCurrentlyValid) {
                _activeDiscounts.insert(0, result.data!);
              }
              // Queue for sync when online
              await _queueForSync('insert', result.data!);
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal membuat diskon: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.createDiscount(discount);
      if (result.success) {
        _discounts.insert(0, result.data!);
        if (result.data!.isCurrentlyValid) {
          _activeDiscounts.insert(0, result.data!);
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('insert', result.data!);
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
    // Validate discount
    final validationError = discount.validate();
    if (validationError != null) {
      return RepositoryResult.failure(validationError);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();
      final discountToUpdate = discount.copyWith(updatedAt: DateTime.now());

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          await _cloudRepository.updateDiscount(discountToUpdate);
          final index = _discounts.indexWhere((d) => d.id == discount.id);
          if (index != -1) {
            _discounts[index] = discountToUpdate;
          }
          _activeDiscounts =
              _discounts.where((d) => d.isCurrentlyValid).toList();
          return RepositoryResult.success(discountToUpdate);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud discount update failed, saving locally: $e');
            final result = await _repository.updateDiscount(discountToUpdate);
            if (result.success) {
              final index = _discounts.indexWhere((d) => d.id == discount.id);
              if (index != -1) {
                _discounts[index] = result.data!;
              }
              _activeDiscounts =
                  _discounts.where((d) => d.isCurrentlyValid).toList();
              // Queue for sync when online
              await _queueForSync('update', result.data!);
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal memperbarui diskon: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.updateDiscount(discountToUpdate);
      if (result.success) {
        final index = _discounts.indexWhere((d) => d.id == discount.id);
        if (index != -1) {
          _discounts[index] = result.data!;
        }
        _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('update', result.data!);
        }
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
      final isOnline = await _checkConnectivity();

      // Find discount for sync queue (before deletion)
      final discountToDelete = _discounts.firstWhere(
        (d) => d.id == id,
        orElse: () => Discount(
          id: id,
          tenantId: tenantId ?? '',
          name: '',
          type: DiscountType.percentage,
          value: 0,
          validFrom: DateTime.now(),
          validUntil: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          await _cloudRepository.deleteDiscount(id);
          _discounts.removeWhere((d) => d.id == id);
          _activeDiscounts.removeWhere((d) => d.id == id);
          if (_selectedDiscount?.id == id) {
            _selectedDiscount = null;
          }
          return RepositoryResult.success(true);
        } catch (e) {
          // Offline fallback: delete locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud discount delete failed, deleting locally: $e');
            final result =
                await _repository.deleteDiscount(id, tenantId: tenantId);
            if (result.success) {
              _discounts.removeWhere((d) => d.id == id);
              _activeDiscounts.removeWhere((d) => d.id == id);
              if (_selectedDiscount?.id == id) {
                _selectedDiscount = null;
              }
              // Queue for sync when online
              await _queueForSync('delete', discountToDelete);
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal menghapus diskon: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.deleteDiscount(id, tenantId: tenantId);
      if (result.success) {
        _discounts.removeWhere((d) => d.id == id);
        _activeDiscounts.removeWhere((d) => d.id == id);
        if (_selectedDiscount?.id == id) {
          _selectedDiscount = null;
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('delete', discountToDelete);
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _checkConnectivity();

      // Find the discount to update
      final discountIndex = _discounts.indexWhere((d) => d.id == id);
      if (discountIndex == -1) {
        return RepositoryResult.failure('Diskon tidak ditemukan');
      }

      final discountToUpdate = _discounts[discountIndex].copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          await _cloudRepository.updateDiscount(discountToUpdate);
          _discounts[discountIndex] = discountToUpdate;
          _activeDiscounts =
              _discounts.where((d) => d.isCurrentlyValid).toList();
          return RepositoryResult.success(discountToUpdate);
        } catch (e) {
          // Offline fallback: update locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud discount toggle failed, updating locally: $e');
            final result = await _repository.toggleStatus(id, isActive);
            if (result.success) {
              _discounts[discountIndex] = result.data!;
              _activeDiscounts =
                  _discounts.where((d) => d.isCurrentlyValid).toList();
              // Queue for sync when online
              await _queueForSync('update', result.data!);
            }
            return result;
          } else {
            return RepositoryResult.failure('Gagal mengubah status: $e');
          }
        }
      }

      // Local mode
      final result = await _repository.toggleStatus(id, isActive);
      if (result.success) {
        _discounts[discountIndex] = result.data!;
        _activeDiscounts = _discounts.where((d) => d.isCurrentlyValid).toList();
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('update', result.data!);
        }
      }
      return result;
    } finally {
      _isLoading = false;
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
