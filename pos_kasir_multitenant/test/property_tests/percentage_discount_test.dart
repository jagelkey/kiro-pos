/// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
/// **Validates: Requirements 14.2**
///
/// Property: For any percentage discount applied to a cart, the discount amount
/// SHALL equal subtotal multiplied by (discount value / 100).
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/shared/services/discount_calculator.dart';
import 'package:pos_kasir_multitenant/data/models/discount.dart';

/// Generator for valid subtotal amounts (positive values)
extension SubtotalGenerator on Any {
  Generator<double> get validSubtotal {
    return any.doubleInRange(0.01, 10000000.0);
  }
}

/// Generator for valid percentage values (0 < percentage <= 100)
extension PercentageGenerator on Any {
  Generator<double> get validPercentage {
    return any.doubleInRange(0.01, 100.0);
  }
}

/// Generator for percentage discount model
extension PercentageDiscountGenerator on Any {
  Generator<Discount> get percentageDiscount {
    return any.validPercentage.map((percentage) {
      final now = DateTime.now();
      return Discount(
        id: 'discount-${percentage.hashCode.abs()}',
        tenantId: 'tenant-test',
        name: 'Test Percentage Discount',
        type: DiscountType.percentage,
        value: percentage,
        minPurchase: null,
        promoCode: null,
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 1)),
        isActive: true,
        createdAt: now,
      );
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Percentage discount equals subtotal * (percentage / 100)
  Glados2(any.validSubtotal, any.validPercentage).test(
    'Percentage discount equals subtotal times percentage divided by 100',
    (subtotal, percentage) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, percentage);
      final expectedDiscount = subtotal * (percentage / 100);

      // Use tolerance for floating point comparison
      if ((discountAmount - expectedDiscount).abs() > 0.001) {
        throw Exception(
            'Discount mismatch: got $discountAmount, expected $expectedDiscount '
            '(subtotal: $subtotal, percentage: $percentage)');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Percentage discount is always less than or equal to subtotal
  Glados2(any.validSubtotal, any.validPercentage).test(
    'Percentage discount never exceeds subtotal',
    (subtotal, percentage) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, percentage);

      if (discountAmount > subtotal + 0.001) {
        throw Exception('Discount $discountAmount exceeds subtotal $subtotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: 100% discount equals the full subtotal
  Glados(any.validSubtotal).test(
    '100 percent discount equals full subtotal',
    (subtotal) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, 100.0);

      if ((discountAmount - subtotal).abs() > 0.001) {
        throw Exception(
            '100% discount should equal subtotal: got $discountAmount, expected $subtotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: 50% discount equals half the subtotal
  Glados(any.validSubtotal).test(
    '50 percent discount equals half subtotal',
    (subtotal) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, 50.0);
      final expectedDiscount = subtotal / 2;

      if ((discountAmount - expectedDiscount).abs() > 0.001) {
        throw Exception(
            '50% discount should equal half subtotal: got $discountAmount, expected $expectedDiscount');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Zero or negative percentage returns zero discount
  Glados(any.validSubtotal).test(
    'Zero or negative percentage returns zero discount',
    (subtotal) {
      final zeroDiscount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, 0.0);
      final negativeDiscount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, -10.0);

      if (zeroDiscount != 0) {
        throw Exception('Zero percentage should return 0 discount');
      }
      if (negativeDiscount != 0) {
        throw Exception('Negative percentage should return 0 discount');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Percentage > 100 returns zero discount (invalid input)
  Glados(any.validSubtotal).test(
    'Percentage over 100 returns zero discount',
    (subtotal) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, 150.0);

      if (discountAmount != 0) {
        throw Exception(
            'Percentage > 100 should return 0 discount, got $discountAmount');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Zero or negative subtotal returns zero discount
  Glados(any.validPercentage).test(
    'Zero or negative subtotal returns zero discount',
    (percentage) {
      final zeroSubtotalDiscount =
          DiscountCalculator.calculatePercentageDiscount(0.0, percentage);
      final negativeSubtotalDiscount =
          DiscountCalculator.calculatePercentageDiscount(-100.0, percentage);

      if (zeroSubtotalDiscount != 0) {
        throw Exception('Zero subtotal should return 0 discount');
      }
      if (negativeSubtotalDiscount != 0) {
        throw Exception('Negative subtotal should return 0 discount');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Discount model calculates same as static method for percentage type
  Glados2(any.validSubtotal, any.percentageDiscount).test(
    'Discount model calculates same as static method',
    (subtotal, discount) {
      final modelDiscount = discount.calculateDiscount(subtotal);
      final staticDiscount = DiscountCalculator.calculatePercentageDiscount(
          subtotal, discount.value);

      if ((modelDiscount - staticDiscount).abs() > 0.001) {
        throw Exception(
            'Model discount $modelDiscount differs from static $staticDiscount');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Discount is proportional - doubling subtotal doubles discount
  Glados2(any.validSubtotal, any.validPercentage).test(
    'Doubling subtotal doubles the discount amount',
    (subtotal, percentage) {
      final discount1 =
          DiscountCalculator.calculatePercentageDiscount(subtotal, percentage);
      final discount2 = DiscountCalculator.calculatePercentageDiscount(
          subtotal * 2, percentage);

      // discount2 should be approximately 2 * discount1
      if ((discount2 - (discount1 * 2)).abs() > 0.001) {
        throw Exception(
            'Doubling subtotal should double discount: got $discount2, expected ${discount1 * 2}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 15: Percentage Discount Calculation**
  /// **Validates: Requirements 14.2**
  ///
  /// Property: Discount is always non-negative
  Glados2(any.validSubtotal, any.validPercentage).test(
    'Discount amount is always non-negative',
    (subtotal, percentage) {
      final discountAmount =
          DiscountCalculator.calculatePercentageDiscount(subtotal, percentage);

      if (discountAmount < 0) {
        throw Exception('Discount should never be negative: $discountAmount');
      }
    },
  );
}
