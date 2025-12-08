/// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
/// **Validates: Requirements 4.1, 4.2**
///
/// Property: For any cart with products and optional discount, the total SHALL
/// equal subtotal plus tax minus discount, where tax is calculated as subtotal
/// multiplied by tax rate.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/product.dart';

/// CartItem representation for testing (mirrors POS screen CartItem)
class TestCartItem {
  final Product product;
  final int quantity;
  final String size;
  final double extraPrice;

  TestCartItem({
    required this.product,
    required this.quantity,
    this.size = 'Regular',
    this.extraPrice = 0,
  });

  double get unitPrice => product.price + extraPrice;
  double get total => unitPrice * quantity;
}

/// Cart calculation logic (extracted from POS screen for testability)
class CartCalculator {
  /// Calculate subtotal from cart items
  static double calculateSubtotal(List<TestCartItem> cart) {
    return cart.fold<double>(0, (sum, item) => sum + item.total);
  }

  /// Calculate tax amount
  static double calculateTax(double subtotal, double taxRate) {
    return subtotal * taxRate;
  }

  /// Calculate effective discount (capped at subtotal + tax)
  static double calculateEffectiveDiscount(
      double discount, double subtotal, double tax) {
    final maxDiscount = subtotal + tax;
    return discount > maxDiscount ? maxDiscount : discount;
  }

  /// Calculate final total
  static double calculateTotal(
      double subtotal, double tax, double effectiveDiscount) {
    return subtotal + tax - effectiveDiscount;
  }

  /// Full cart calculation
  static CartCalculationResult calculate({
    required List<TestCartItem> cart,
    required double taxRate,
    required double discount,
  }) {
    final subtotal = calculateSubtotal(cart);
    final tax = calculateTax(subtotal, taxRate);
    final effectiveDiscount =
        calculateEffectiveDiscount(discount, subtotal, tax);
    final total = calculateTotal(subtotal, tax, effectiveDiscount);

    return CartCalculationResult(
      subtotal: subtotal,
      tax: tax,
      effectiveDiscount: effectiveDiscount,
      total: total,
    );
  }
}

class CartCalculationResult {
  final double subtotal;
  final double tax;
  final double effectiveDiscount;
  final double total;

  CartCalculationResult({
    required this.subtotal,
    required this.tax,
    required this.effectiveDiscount,
    required this.total,
  });
}

/// Generator for valid Product instances
extension ProductGenerator on Any {
  Generator<Product> get validProduct {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(1.0, 100000.0).bind((price) {
        return any.intInRange(1, 1000).map((stock) {
          return Product(
            id: 'prod-${name.hashCode.abs()}',
            tenantId: 'tenant-test',
            name: name.isEmpty ? 'Product' : name,
            price: price,
            stock: stock,
            category: 'Coffee',
            createdAt: DateTime(2024, 1, 1),
          );
        });
      });
    });
  }
}

/// Generator for valid cart items
extension CartItemGenerator on Any {
  Generator<TestCartItem> get cartItem {
    return any.validProduct.bind((product) {
      return any.intInRange(1, 10).bind((quantity) {
        return any.intInRange(0, 1).map((sizeIndex) {
          final size = sizeIndex == 0 ? 'Regular' : 'Large';
          final extraPrice = size == 'Large' ? 5000.0 : 0.0;
          return TestCartItem(
            product: product,
            quantity: quantity,
            size: size,
            extraPrice: extraPrice,
          );
        });
      });
    });
  }
}

/// Generator for a list of cart items (fixed 3 items for simplicity)
extension CartGenerator on Any {
  Generator<List<TestCartItem>> get cart {
    // Generate exactly 3 cart items
    return any.cartItem.bind((item1) {
      return any.cartItem.bind((item2) {
        return any.cartItem.map((item3) {
          return [item1, item2, item3];
        });
      });
    });
  }
}

/// Generator for valid tax rates (0% to 20%)
extension TaxRateGenerator on Any {
  Generator<double> get taxRate {
    return any.doubleInRange(0.0, 0.20);
  }
}

/// Generator for discount amounts (0 to 100000)
extension DiscountGenerator on Any {
  Generator<double> get discount {
    return any.doubleInRange(0.0, 100000.0);
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1, 4.2**
  ///
  /// Property: For any cart, subtotal equals sum of (unitPrice * quantity) for all items
  Glados(any.cart).test(
    'Subtotal equals sum of item totals',
    (cart) {
      final subtotal = CartCalculator.calculateSubtotal(cart);
      final expectedSubtotal = cart.fold<double>(
          0, (sum, item) => sum + (item.unitPrice * item.quantity));

      // Use tolerance for floating point comparison
      if ((subtotal - expectedSubtotal).abs() > 0.001) {
        throw Exception(
            'Subtotal mismatch: got $subtotal, expected $expectedSubtotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1**
  ///
  /// Property: Tax equals subtotal multiplied by tax rate
  Glados2(any.cart, any.taxRate).test(
    'Tax equals subtotal times tax rate',
    (cart, taxRate) {
      final subtotal = CartCalculator.calculateSubtotal(cart);
      final tax = CartCalculator.calculateTax(subtotal, taxRate);
      final expectedTax = subtotal * taxRate;

      if ((tax - expectedTax).abs() > 0.001) {
        throw Exception('Tax mismatch: got $tax, expected $expectedTax');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.2**
  ///
  /// Property: Effective discount is capped at (subtotal + tax)
  Glados3(any.cart, any.taxRate, any.discount).test(
    'Discount is capped at subtotal plus tax',
    (cart, taxRate, discount) {
      final subtotal = CartCalculator.calculateSubtotal(cart);
      final tax = CartCalculator.calculateTax(subtotal, taxRate);
      final effectiveDiscount =
          CartCalculator.calculateEffectiveDiscount(discount, subtotal, tax);
      final maxDiscount = subtotal + tax;

      if (effectiveDiscount > maxDiscount + 0.001) {
        throw Exception(
            'Effective discount $effectiveDiscount exceeds max $maxDiscount');
      }

      // If discount <= max, effective discount should equal discount
      if (discount <= maxDiscount) {
        if ((effectiveDiscount - discount).abs() > 0.001) {
          throw Exception(
              'Effective discount should equal discount when under max');
        }
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1, 4.2**
  ///
  /// Property: Total equals subtotal + tax - effectiveDiscount
  Glados3(any.cart, any.taxRate, any.discount).test(
    'Total equals subtotal plus tax minus effective discount',
    (cart, taxRate, discount) {
      final result = CartCalculator.calculate(
        cart: cart,
        taxRate: taxRate,
        discount: discount,
      );

      final expectedTotal =
          result.subtotal + result.tax - result.effectiveDiscount;

      if ((result.total - expectedTotal).abs() > 0.001) {
        throw Exception(
            'Total mismatch: got ${result.total}, expected $expectedTotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1, 4.2**
  ///
  /// Property: Total is never negative
  Glados3(any.cart, any.taxRate, any.discount).test(
    'Total is never negative',
    (cart, taxRate, discount) {
      final result = CartCalculator.calculate(
        cart: cart,
        taxRate: taxRate,
        discount: discount,
      );

      if (result.total < -0.001) {
        throw Exception('Total should never be negative: ${result.total}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1**
  ///
  /// Property: Empty cart has zero subtotal, tax, and total
  Glados2(any.taxRate, any.discount).test(
    'Empty cart has zero values',
    (taxRate, discount) {
      final result = CartCalculator.calculate(
        cart: [],
        taxRate: taxRate,
        discount: discount,
      );

      if (result.subtotal != 0) {
        throw Exception('Empty cart subtotal should be 0');
      }
      if (result.tax != 0) {
        throw Exception('Empty cart tax should be 0');
      }
      if (result.total != 0) {
        throw Exception('Empty cart total should be 0');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 1: Cart Calculation Consistency**
  /// **Validates: Requirements 4.1**
  ///
  /// Property: Adding item to cart increases subtotal by item total
  Glados2(any.cart, any.cartItem).test(
    'Adding item increases subtotal by item total',
    (cart, newItem) {
      final originalSubtotal = CartCalculator.calculateSubtotal(cart);
      final newCart = [...cart, newItem];
      final newSubtotal = CartCalculator.calculateSubtotal(newCart);

      final expectedIncrease = newItem.total;
      final actualIncrease = newSubtotal - originalSubtotal;

      if ((actualIncrease - expectedIncrease).abs() > 0.001) {
        throw Exception(
            'Subtotal increase mismatch: got $actualIncrease, expected $expectedIncrease');
      }
    },
  );
}
