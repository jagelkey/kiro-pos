import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/cart_item.dart';
import '../../data/repositories/product_repository.dart';

/// Cart Persistence Helper
/// Handles saving and loading cart state for offline persistence
class CartPersistence {
  static const String _cartKey = 'pos_cart';
  static const String _tenantKey = 'pos_cart_tenant';

  /// Save cart to persistent storage
  static Future<void> saveCart(
    List<CartItem> cart,
    String tenantId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = cart.map((item) => item.toMap()).toList();
      await prefs.setString(_cartKey, jsonEncode(cartData));
      await prefs.setString(_tenantKey, tenantId);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// Load cart from persistent storage
  static Future<List<CartItem>> loadCart(
    ProductRepository productRepo,
    String currentTenantId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      final savedTenantId = prefs.getString(_tenantKey);

      // Clear cart if tenant changed
      if (savedTenantId != currentTenantId) {
        await clearCart();
        return [];
      }

      if (cartJson == null) return [];

      final cartData = jsonDecode(cartJson) as List;
      final cart = <CartItem>[];

      for (final itemData in cartData) {
        final productId = itemData['product_id'] as String;
        final product = await productRepo.getProduct(productId);

        // Only add if product still exists and belongs to current tenant
        if (product != null && product.tenantId == currentTenantId) {
          cart.add(CartItem.fromMap(itemData, product));
        }
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
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }
}
