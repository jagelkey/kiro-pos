import '../../data/models/discount.dart';

/// Service class for discount calculations
/// Requirements 14.2, 14.3: Calculate percentage or fixed discount
class DiscountCalculator {
  /// Calculate percentage discount
  /// Requirements 14.2: Percentage discount reduces total by percentage
  static double calculatePercentageDiscount(
      double subtotal, double percentage) {
    if (percentage <= 0 || percentage > 100) return 0;
    if (subtotal <= 0) return 0;
    return subtotal * (percentage / 100);
  }

  /// Calculate fixed discount
  /// Requirements 14.3: Fixed discount reduces total by fixed amount (capped at subtotal)
  static double calculateFixedDiscount(double subtotal, double fixedAmount) {
    if (fixedAmount <= 0) return 0;
    if (subtotal <= 0) return 0;
    // Fixed discount cannot exceed subtotal
    return fixedAmount > subtotal ? subtotal : fixedAmount;
  }

  /// Calculate discount from Discount model
  static double calculateFromDiscount(Discount? discount, double subtotal) {
    if (discount == null) return 0;
    return discount.calculateDiscount(subtotal);
  }

  /// Validate discount can be applied
  /// Requirements 14.4, 14.5: Validate validity period and minimum purchase
  static DiscountValidationResult validateDiscount(
      Discount? discount, double subtotal) {
    if (discount == null) {
      return DiscountValidationResult(
        isValid: false,
        message: 'No discount selected',
      );
    }

    if (!discount.isActive) {
      return DiscountValidationResult(
        isValid: false,
        message: 'Discount is not active',
      );
    }

    if (!discount.isCurrentlyValid) {
      return DiscountValidationResult(
        isValid: false,
        message: 'Discount is outside valid date range',
      );
    }

    if (!discount.meetsMinPurchase(subtotal)) {
      return DiscountValidationResult(
        isValid: false,
        message:
            'Minimum purchase of Rp ${discount.minPurchase?.toStringAsFixed(0) ?? 0} required',
      );
    }

    return DiscountValidationResult(
      isValid: true,
      discountAmount: discount.calculateDiscount(subtotal),
    );
  }

  /// Calculate final total after discount
  static double calculateFinalTotal(double subtotal, Discount? discount) {
    final discountAmount = calculateFromDiscount(discount, subtotal);
    return subtotal - discountAmount;
  }

  /// Format discount display string
  static String formatDiscountDisplay(Discount discount) {
    if (discount.type == DiscountType.percentage) {
      return '${discount.value.toStringAsFixed(0)}%';
    } else {
      return 'Rp ${discount.value.toStringAsFixed(0)}';
    }
  }
}

/// Result of discount validation
class DiscountValidationResult {
  final bool isValid;
  final String? message;
  final double discountAmount;

  DiscountValidationResult({
    required this.isValid,
    this.message,
    this.discountAmount = 0,
  });
}
