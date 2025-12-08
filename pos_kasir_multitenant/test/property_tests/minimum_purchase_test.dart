/// **Feature: pos-comprehensive-fix, Property 18: Minimum Purchase Validation**
/// **Validates: Requirements 14.5**
///
/// Property: A discount with minPurchase requirement SHALL only be applicable
/// when the cart subtotal is greater than or equal to minPurchase.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/discount.dart';
import 'package:pos_kasir_multitenant/shared/services/discount_calculator.dart';

/// Generator for valid subtotal amounts
extension SubtotalGenerator on Any {
  Generator<double> get validSubtotal {
    return any.doubleInRange(1000.0, 1000000.0);
  }
}

/// Generator for minimum purchase amounts
extension MinPurchaseGenerator on Any {
  Generator<double> get minPurchaseAmount {
    return any.doubleInRange(10000.0, 500000.0);
  }
}

/// Generator for discount percentage
extension DiscountValueGenerator on Any {
  Generator<double> get discountPercentage {
    return any.doubleInRange(5.0, 50.0);
  }
}

/// Create a discount with minimum purchase requirement
Discount createDiscountWithMinPurchase({
  required double minPurchase,
  double value = 10.0,
}) {
  final now = DateTime.now();
  return Discount(
    id: 'test-discount',
    tenantId: 'tenant-test',
    name: 'Test Discount',
    type: DiscountType.percentage,
    value: value,
    minPurchase: minPurchase,
    promoCode: null,
    validFrom: now.subtract(const Duration(days: 1)),
    validUntil: now.add(const Duration(days: 1)),
    isActive: true,
    createdAt: now,
  );
}

/// Create a discount without minimum purchase requirement
Discount createDiscountWithoutMinPurchase({double value = 10.0}) {
  final now = DateTime.now();
  return Discount(
    id: 'test-discount',
    tenantId: 'tenant-test',
    name: 'Test Discount',
    type: DiscountType.percentage,
    value: value,
    minPurchase: null,
    promoCode: null,
    validFrom: now.subtract(const Duration(days: 1)),
    validUntil: now.add(const Duration(days: 1)),
    isActive: true,
    createdAt: now,
  );
}

void main() {
  /// **Property 18: Minimum Purchase Validation**
  /// **Validates: Requirements 14.5**
  ///
  /// Property: Subtotal >= minPurchase meets requirement
  Glados2(any.minPurchaseAmount, any.discountPercentage).test(
    'Subtotal equal to minPurchase meets requirement',
    (minPurchase, value) {
      final discount = createDiscountWithMinPurchase(
        minPurchase: minPurchase,
        value: value,
      );

      // Subtotal exactly equals minPurchase
      if (!discount.meetsMinPurchase(minPurchase)) {
        throw Exception(
            'Subtotal equal to minPurchase should meet requirement');
      }
    },
  );

  /// Property: Subtotal > minPurchase meets requirement
  Glados2(any.minPurchaseAmount, any.validSubtotal).test(
    'Subtotal greater than minPurchase meets requirement',
    (minPurchase, extraAmount) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase + extraAmount;

      if (!discount.meetsMinPurchase(subtotal)) {
        throw Exception(
            'Subtotal $subtotal > minPurchase $minPurchase should meet requirement');
      }
    },
  );

  /// Property: Subtotal < minPurchase does not meet requirement
  Glados(any.minPurchaseAmount).test(
    'Subtotal less than minPurchase does not meet requirement',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase - 1; // Just below minimum

      if (discount.meetsMinPurchase(subtotal)) {
        throw Exception(
            'Subtotal $subtotal < minPurchase $minPurchase should not meet requirement');
      }
    },
  );

  /// Property: Discount without minPurchase always meets requirement
  Glados(any.validSubtotal).test(
    'Discount without minPurchase always meets requirement',
    (subtotal) {
      final discount = createDiscountWithoutMinPurchase();

      if (!discount.meetsMinPurchase(subtotal)) {
        throw Exception(
            'Discount without minPurchase should always meet requirement');
      }
    },
  );

  /// Property: Zero subtotal does not meet minPurchase requirement
  Glados(any.minPurchaseAmount).test(
    'Zero subtotal does not meet minPurchase requirement',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);

      if (discount.meetsMinPurchase(0)) {
        throw Exception(
            'Zero subtotal should not meet minPurchase requirement');
      }
    },
  );

  /// Property: calculateDiscount returns 0 when minPurchase not met
  Glados2(any.minPurchaseAmount, any.discountPercentage).test(
    'calculateDiscount returns 0 when minPurchase not met',
    (minPurchase, value) {
      final discount = createDiscountWithMinPurchase(
        minPurchase: minPurchase,
        value: value,
      );
      final subtotal = minPurchase - 1; // Below minimum

      final discountAmount = discount.calculateDiscount(subtotal);

      if (discountAmount != 0) {
        throw Exception(
            'Discount should be 0 when minPurchase not met, got $discountAmount');
      }
    },
  );

  /// Property: calculateDiscount returns correct amount when minPurchase met
  Glados2(any.minPurchaseAmount, any.discountPercentage).test(
    'calculateDiscount returns correct amount when minPurchase met',
    (minPurchase, value) {
      final discount = createDiscountWithMinPurchase(
        minPurchase: minPurchase,
        value: value,
      );
      final subtotal = minPurchase + 10000; // Above minimum

      final discountAmount = discount.calculateDiscount(subtotal);
      final expectedAmount = subtotal * (value / 100);

      if ((discountAmount - expectedAmount).abs() > 0.001) {
        throw Exception(
            'Discount should be $expectedAmount, got $discountAmount');
      }
    },
  );

  /// Property: DiscountCalculator.validateDiscount fails when minPurchase not met
  Glados(any.minPurchaseAmount).test(
    'DiscountCalculator.validateDiscount fails when minPurchase not met',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase - 1;

      final result = DiscountCalculator.validateDiscount(discount, subtotal);

      if (result.isValid) {
        throw Exception('Validation should fail when minPurchase not met');
      }
      if (result.message == null || !result.message!.contains('Minimum')) {
        throw Exception('Validation message should mention minimum purchase');
      }
    },
  );

  /// Property: DiscountCalculator.validateDiscount passes when minPurchase met
  Glados(any.minPurchaseAmount).test(
    'DiscountCalculator.validateDiscount passes when minPurchase met',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase + 10000;

      final result = DiscountCalculator.validateDiscount(discount, subtotal);

      if (!result.isValid) {
        throw Exception(
            'Validation should pass when minPurchase met: ${result.message}');
      }
      if (result.discountAmount <= 0) {
        throw Exception('Discount amount should be positive');
      }
    },
  );

  /// Property: Negative minPurchase is treated as no minimum
  Glados(any.validSubtotal).test(
    'Discount with null minPurchase has no minimum requirement',
    (subtotal) {
      final discount = createDiscountWithoutMinPurchase();

      // Even very small subtotal should meet requirement
      if (!discount.meetsMinPurchase(0.01)) {
        throw Exception('Null minPurchase should have no minimum requirement');
      }
    },
  );

  /// Property: Exact boundary - subtotal == minPurchase - 0.01 fails
  Glados(any.minPurchaseAmount).test(
    'Subtotal just below minPurchase fails requirement',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase - 0.01;

      if (discount.meetsMinPurchase(subtotal)) {
        throw Exception(
            'Subtotal $subtotal just below minPurchase $minPurchase should fail');
      }
    },
  );

  /// Property: Exact boundary - subtotal == minPurchase + 0.01 passes
  Glados(any.minPurchaseAmount).test(
    'Subtotal just above minPurchase passes requirement',
    (minPurchase) {
      final discount = createDiscountWithMinPurchase(minPurchase: minPurchase);
      final subtotal = minPurchase + 0.01;

      if (!discount.meetsMinPurchase(subtotal)) {
        throw Exception(
            'Subtotal $subtotal just above minPurchase $minPurchase should pass');
      }
    },
  );
}
