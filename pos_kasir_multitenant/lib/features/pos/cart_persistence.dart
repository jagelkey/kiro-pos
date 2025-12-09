import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/cart_item.dart';
import '../../data/repositories/product_repository.dart';

/// Cart Persistence Helper
/// Handles saving and loading cart state for offline persistence
/// Supports multi-tenant and multi-branch data isolation
class CartPersistence {
  static const String _cartKey = 'pos_cart';
  static const String _tenantKey = 'pos_cart_tenant';
  static const String _branchKey = 'pos_cart_branch';
  static const String _timestampKey = 'pos_cart_timestamp';

  /// Maximum cart age in hours before auto-clear (for stale data protection)
  static const int _maxCartAgeHours = 24;

  /// Save cart to persistent storage with tenant and branch isolation
  static Future<void> saveCart(
    List<CartItem> cart,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = cart.map((item) => item.toMap()).toList();
      await prefs.setString(_cartKey, jsonEncode(cartData));
      await prefs.setString(_tenantKey, tenantId);
      if (branchId != null) {
        await prefs.setString(_branchKey, branchId);
      } else {
        await prefs.remove(_branchKey);
      }
      // Save timestamp for stale cart detection
      await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// Load cart from persistent storage with multi-tenant and multi-branch validation
  static Future<List<CartItem>> loadCart(
    ProductRepository productRepo,
    String currentTenantId, {
    String? currentBranchId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      final savedTenantId = prefs.getString(_tenantKey);
      final savedBranchId = prefs.getString(_branchKey);
      final savedTimestamp = prefs.getString(_timestampKey);

      // Clear cart if tenant changed (multi-tenant isolation)
      if (savedTenantId != currentTenantId) {
        await clearCart();
        return [];
      }

      // Clear cart if branch changed (multi-branch isolation)
      if (savedBranchId != currentBranchId) {
        await clearCart();
        return [];
      }

      // Clear cart if too old (stale data protection for offline mode)
      if (savedTimestamp != null) {
        final cartTime = DateTime.tryParse(savedTimestamp);
        if (cartTime != null) {
          final age = DateTime.now().difference(cartTime);
          if (age.inHours > _maxCartAgeHours) {
            debugPrint(
                'Cart expired after $_maxCartAgeHours hours, clearing...');
            await clearCart();
            return [];
          }
        }
      }

      if (cartJson == null) return [];

      final cartData = jsonDecode(cartJson) as List;
      final cart = <CartItem>[];
      final invalidProducts = <String>[];

      for (final itemData in cartData) {
        final productId = itemData['product_id'] as String;
        final product = await productRepo.getProduct(productId);

        // Only add if product still exists and belongs to current tenant
        if (product != null && product.tenantId == currentTenantId) {
          // Validate stock availability
          final quantity = itemData['quantity'] as int;
          if (product.stock >= quantity) {
            cart.add(CartItem.fromMap(itemData, product));
          } else if (product.stock > 0) {
            // Adjust quantity to available stock
            final adjustedData = Map<String, dynamic>.from(itemData);
            adjustedData['quantity'] = product.stock;
            cart.add(CartItem.fromMap(adjustedData, product));
          } else {
            invalidProducts.add(product.name);
          }
        } else {
          invalidProducts.add(productId);
        }
      }

      if (invalidProducts.isNotEmpty) {
        debugPrint(
            'Removed ${invalidProducts.length} invalid/out-of-stock products from cart');
      }

      return cart;
    } catch (e) {
      debugPrint('Error loading cart: $e');
      return [];
    }
  }

  /// Clear cart from persistent storage
  static Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      await prefs.remove(_tenantKey);
      await prefs.remove(_branchKey);
      await prefs.remove(_timestampKey);
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }

  /// Check if cart exists in storage
  static Future<bool> hasCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cartKey);
    } catch (e) {
      return false;
    }
  }
}
