/// **Feature: pos-comprehensive-fix, Property 16: Fixed Discount Calculation**
/// **Validates: Requirements 14.3**
///
/// Property: For any fixed discount applied to a cart, the discount amount
/// SHALL equal the fixed value OR the subtotal (whichever is smaller).
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

/// Generator for valid fixed discount amounts
extension FixedAmountGenerator on Any {
  Generator<double> get validFixedAmount {
    return any.doubleInRange(0.01, 10000000.0);
  }
}

/// Generator for fixed discount model
extension FixedDiscountGenerator on Any {
  Generator<Discount> get fixedDiscount {
    return any.validFixedAmount.map((amount) {
      final now = DateTime.now();
      return Discount(
        id: 'discount-${amount.hashCode.abs()}',
        tenantId: 'tenant-test',
        name: 'Test Fixed Discount',
        type: DiscountType.fixed,
        value: amount,
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
  /// **Property 16: Fixed Discount Calculation**
  /// **Validates: Requirements 14.3**
  ///
  /// Property: Fixed discount equals min(fixedAmount, subtotal)
  Glados2(any.validSubtotal, any.validFixedAmount).test(
    'Fixed discount equals minimum of fixed amount and subtotal',
    (subtotal, fixedAmount) {
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);
      final expectedDiscount = fixedAmount > subtotal ? subtotal : fixedAmount;

      if ((discountAmount - expectedDiscount).abs() > 0.001) {
        throw Exception(
            'Discount mismatch: got $discountAmount, expected $expectedDiscount '
            '(subtotal: $subtotal, fixedAmount: $fixedAmount)');
      }
    },
  );

  /// Property: Fixed discount never exceeds subtotal
  Glados2(any.validSubtotal, any.validFixedAmount).test(
    'Fixed discount never exceeds subtotal',
    (subtotal, fixedAmount) {
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);

      if (discountAmount > subtotal + 0.001) {
        throw Exception('Discount $discountAmount exceeds subtotal $subtotal');
      }
    },
  );

  /// Property: Fixed discount never exceeds the fixed amount
  Glados2(any.validSubtotal, any.validFixedAmount).test(
    'Fixed discount never exceeds fixed amount',
    (subtotal, fixedAmount) {
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);

      if (discountAmount > fixedAmount + 0.001) {
        throw Exception(
            'Discount $discountAmount exceeds fixed amount $fixedAmount');
      }
    },
  );

  /// Property: When fixed amount < subtotal, discount equals fixed amount
  Glados(any.validSubtotal).test(
    'When fixed amount is less than subtotal, discount equals fixed amount',
    (subtotal) {
      final fixedAmount = subtotal / 2; // Always less than subtotal
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);

      if ((discountAmount - fixedAmount).abs() > 0.001) {
        throw Exception(
            'Discount should equal fixed amount: got $discountAmount, expected $fixedAmount');
      }
    },
  );

  /// Property: When fixed amount > subtotal, discount equals subtotal
  Glados(any.validSubtotal).test(
    'When fixed amount exceeds subtotal, discount equals subtotal',
    (subtotal) {
      final fixedAmount = subtotal * 2; // Always greater than subtotal
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);

      if ((discountAmount - subtotal).abs() > 0.001) {
        throw Exception(
            'Discount should equal subtotal: got $discountAmount, expected $subtotal');
      }
    },
  );

  /// Property: Zero or negative fixed amount returns zero discount
  Glados(any.validSubtotal).test(
    'Zero or negative fixed amount returns zero discount',
    (subtotal) {
      final zeroDiscount =
          DiscountCalculator.calculateFixedDiscount(subtotal, 0.0);
      final negativeDiscount =
          DiscountCalculator.calculateFixedDiscount(subtotal, -100.0);

      if (zeroDiscount != 0) {
        throw Exception('Zero fixed amount should return 0 discount');
      }
      if (negativeDiscount != 0) {
        throw Exception('Negative fixed amount should return 0 discount');
      }
    },
  );

  /// Property: Zero or negative subtotal returns zero discount
  Glados(any.validFixedAmount).test(
    'Zero or negative subtotal returns zero discount',
    (fixedAmount) {
      final zeroSubtotalDiscount =
          DiscountCalculator.calculateFixedDiscount(0.0, fixedAmount);
      final negativeSubtotalDiscount =
          DiscountCalculator.calculateFixedDiscount(-100.0, fixedAmount);

      if (zeroSubtotalDiscount != 0) {
        throw Exception('Zero subtotal should return 0 discount');
      }
      if (negativeSubtotalDiscount != 0) {
        throw Exception('Negative subtotal should return 0 discount');
      }
    },
  );

  /// Property: Discount model calculates same as static method for fixed type
  Glados2(any.validSubtotal, any.fixedDiscount).test(
    'Discount model calculates same as static method for fixed type',
    (subtotal, discount) {
      final modelDiscount = discount.calculateDiscount(subtotal);
      final staticDiscount =
          DiscountCalculator.calculateFixedDiscount(subtotal, discount.value);

      if ((modelDiscount - staticDiscount).abs() > 0.001) {
        throw Exception(
            'Model discount $modelDiscount differs from static $staticDiscount');
      }
    },
  );

  /// Property: Discount is always non-negative
  Glados2(any.validSubtotal, any.validFixedAmount).test(
    'Fixed discount amount is always non-negative',
    (subtotal, fixedAmount) {
      final discountAmount =
          DiscountCalculator.calculateFixedDiscount(subtotal, fixedAmount);

      if (discountAmount < 0) {
        throw Exception('Discount should never be negative: $discountAmount');
      }
    },
  );

  /// Property: Final total after discount is always non-negative
  Glados2(any.validSubtotal, any.fixedDiscount).test(
    'Final total after fixed discount is always non-negative',
    (subtotal, discount) {
      final finalTotal =
          DiscountCalculator.calculateFinalTotal(subtotal, discount);

      if (finalTotal < -0.001) {
        throw Exception('Final total should never be negative: $finalTotal');
      }
    },
  );
}
