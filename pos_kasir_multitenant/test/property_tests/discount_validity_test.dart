/// **Feature: pos-comprehensive-fix, Property 17: Discount Validity Period**
/// **Validates: Requirements 14.4**
///
/// Property: A discount SHALL only be applicable when the current date
/// is within the validFrom and validUntil range AND isActive is true.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/discount.dart';
import 'package:pos_kasir_multitenant/shared/services/discount_calculator.dart';

/// Generator for days offset (for date manipulation)
extension DaysOffsetGenerator on Any {
  Generator<int> get daysOffset {
    return any.intInRange(1, 365);
  }
}

/// Generator for valid subtotal amounts
extension SubtotalGenerator on Any {
  Generator<double> get validSubtotal {
    return any.doubleInRange(100.0, 10000.0);
  }
}

/// Generator for discount value
extension DiscountValueGenerator on Any {
  Generator<double> get discountValue {
    return any.doubleInRange(5.0, 50.0);
  }
}

/// Create a discount with specific validity period
Discount createDiscount({
  required DateTime validFrom,
  required DateTime validUntil,
  required bool isActive,
  double value = 10.0,
}) {
  return Discount(
    id: 'test-discount',
    tenantId: 'tenant-test',
    name: 'Test Discount',
    type: DiscountType.percentage,
    value: value,
    minPurchase: null,
    promoCode: null,
    validFrom: validFrom,
    validUntil: validUntil,
    isActive: isActive,
    createdAt: DateTime.now(),
  );
}

void main() {
  /// **Property 17: Discount Validity Period**
  /// **Validates: Requirements 14.4**
  ///
  /// Property: Active discount within valid date range is applicable
  Glados2(any.daysOffset, any.discountValue).test(
    'Active discount within valid date range is applicable',
    (daysOffset, value) {
      final now = DateTime.now();
      final discount = createDiscount(
        validFrom: now.subtract(Duration(days: daysOffset)),
        validUntil: now.add(Duration(days: daysOffset)),
        isActive: true,
        value: value,
      );

      if (!discount.isCurrentlyValid) {
        throw Exception(
            'Discount should be valid: validFrom=${discount.validFrom}, '
            'validUntil=${discount.validUntil}, isActive=${discount.isActive}');
      }
    },
  );

  /// Property: Inactive discount is not applicable even within valid dates
  Glados(any.daysOffset).test(
    'Inactive discount is not applicable even within valid dates',
    (daysOffset) {
      final now = DateTime.now();
      final discount = createDiscount(
        validFrom: now.subtract(Duration(days: daysOffset)),
        validUntil: now.add(Duration(days: daysOffset)),
        isActive: false,
      );

      if (discount.isCurrentlyValid) {
        throw Exception('Inactive discount should not be valid');
      }
    },
  );

  /// Property: Discount before validFrom date is not applicable
  Glados(any.daysOffset).test(
    'Discount before validFrom date is not applicable',
    (daysOffset) {
      final now = DateTime.now();
      final discount = createDiscount(
        validFrom: now.add(Duration(days: daysOffset)), // Future start
        validUntil: now.add(Duration(days: daysOffset + 30)),
        isActive: true,
      );

      if (discount.isCurrentlyValid) {
        throw Exception(
            'Discount should not be valid before validFrom date');
      }
    },
  );

  /// Property: Discount after validUntil date is not applicable
  Glados(any.daysOffset).test(
    'Discount after validUntil date is not applicable',
    (daysOffset) {
      final now = DateTime.now();
      final discount = createDiscount(
        validFrom: now.subtract(Duration(days: daysOffset + 30)), // Past start
        validUntil: now.subtract(Duration(days: daysOffset)), // Past end
        isActive: true,
      );

      if (discount.isCurrentlyValid) {
        throw Exception('Discount should not be valid after validUntil date');
      }
    },
  );

  /// Property: Invalid discount returns zero discount amount
  Glados2(any.validSubtotal, any.daysOffset).test(
    'Invalid discount returns zero discount amount',
    (subtotal, daysOffset) {
      final now = DateTime.now();
      
      // Expired discount
      final expiredDiscount = createDiscount(
        validFrom: now.subtract(Duration(days: daysOffset + 30)),
        validUntil: now.subtract(Duration(days: daysOffset)),
        isActive: true,
        value: 20.0,
      );
      
      // Inactive discount
      final inactiveDiscount = createDiscount(
        validFrom: now.subtract(Duration(days: daysOffset)),
        validUntil: now.add(Duration(days: daysOffset)),
        isActive: false,
        value: 20.0,
      );

      final expiredAmount = expiredDiscount.calculateDiscount(subtotal);
      final inactiveAmount = inactiveDiscount.calculateDiscount(subtotal);

      if (expiredAmount != 0) {
        throw Exception('Expired discount should return 0, got $expiredAmount');
      }
      if (inactiveAmount != 0) {
        throw Exception(
            'Inactive discount should return 0, got $inactiveAmount');
      }
    },
  );

  /// Property: Valid discount returns positive discount amount
  Glados2(any.validSubtotal, any.discountValue).test(
    'Valid discount returns positive discount amount',
    (subtotal, value) {
      final now = DateTime.now();
      final discount = createDiscount(
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 1)),
        isActive: true,
        value: value,
      );

      final discountAmount = discount.calculateDiscount(subtotal);
      final expectedAmount = subtotal * (value / 100);

      if ((discountAmount - expectedAmount).abs() > 0.001) {
        throw Exception(
            'Valid discount should return $expectedAmount, got $discountAmount');
      }
    },
  );

  /// Property: DiscountCalculator.validateDiscount returns correct validation
  Glados(any.validSubtotal).test(
    'DiscountCalculator validates expired discount correctly',
    (subtotal) {
      final now = DateTime.now();
      final expiredDiscount = createDiscount(
        validFrom: now.subtract(const Duration(days: 30)),
        validUntil: now.subtract(const Duration(days: 1)),
        isActive: true,
      );

      final result =
          DiscountCalculator.validateDiscount(expiredDiscount, subtotal);

      if (result.isValid) {
        throw Exception('Expired discount should fail validation');
      }
      if (result.message == null || result.message!.isEmpty) {
        throw Exception('Validation should provide error message');
      }
    },
  );

  /// Property: DiscountCalculator validates inactive discount correctly
  Glados(any.validSubtotal).test(
    'DiscountCalculator validates inactive discount correctly',
    (subtotal) {
      final now = DateTime.now();
      final inactiveDiscount = createDiscount(
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 1)),
        isActive: false,
      );

      final result =
          DiscountCalculator.validateDiscount(inactiveDiscount, subtotal);

      if (result.isValid) {
        throw Exception('Inactive discount should fail validation');
      }
    },
  );

  /// Property: Discount on exact validFrom date is valid
  Glados(any.discountValue).test(
    'Discount on exact validFrom date is valid',
    (value) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final discount = createDiscount(
        validFrom: startOfDay,
        validUntil: startOfDay.add(const Duration(days: 7)),
        isActive: true,
        value: value,
      );

      // Should be valid on the start date
      if (!discount.isCurrentlyValid) {
        throw Exception('Discount should be valid on validFrom date');
      }
    },
  );

  /// Property: Discount on exact validUntil date is valid
  Glados(any.discountValue).test(
    'Discount on exact validUntil date is valid',
    (value) {
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final discount = createDiscount(
        validFrom: now.subtract(const Duration(days: 7)),
        validUntil: endOfDay,
        isActive: true,
        value: value,
      );

      // Should be valid on the end date
      if (!discount.isCurrentlyValid) {
        throw Exception('Discount should be valid on validUntil date');
      }
    },
  );
}
