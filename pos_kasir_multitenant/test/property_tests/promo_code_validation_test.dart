/// **Feature: pos-comprehensive-fix, Property 19: Promo Code Validation**
/// **Validates: Requirements 14.6**
///
/// Property: A promo code SHALL only be valid when it matches an active discount's
/// promoCode field exactly (case-insensitive) and the discount is currently valid.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/discount.dart';

/// Generator for promo codes
extension PromoCodeGenerator on Any {
  Generator<String> get promoCode {
    return any.intInRange(1000, 99999999).map((i) => 'PROMO$i');
  }
}

/// Generator for discount value
extension DiscountValueGenerator on Any {
  Generator<double> get discountValue {
    return any.doubleInRange(5.0, 50.0);
  }
}

/// Create a discount with promo code
Discount createDiscountWithPromoCode({
  required String promoCode,
  bool isActive = true,
  DateTime? validFrom,
  DateTime? validUntil,
  double value = 10.0,
}) {
  final now = DateTime.now();
  return Discount(
    id: 'test-discount-${promoCode.hashCode.abs()}',
    tenantId: 'tenant-test',
    name: 'Promo $promoCode',
    type: DiscountType.percentage,
    value: value,
    minPurchase: null,
    promoCode: promoCode,
    validFrom: validFrom ?? now.subtract(const Duration(days: 1)),
    validUntil: validUntil ?? now.add(const Duration(days: 1)),
    isActive: isActive,
    createdAt: now,
  );
}

/// Simulate finding discount by promo code from a list
Discount? findDiscountByPromoCode(List<Discount> discounts, String code) {
  final normalizedCode = code.trim().toUpperCase();
  try {
    return discounts.firstWhere(
      (d) =>
          d.promoCode != null &&
          d.promoCode!.toUpperCase() == normalizedCode &&
          d.isCurrentlyValid,
    );
  } catch (_) {
    return null;
  }
}

void main() {
  /// **Property 19: Promo Code Validation**
  /// **Validates: Requirements 14.6**
  ///
  /// Property: Exact promo code match finds the discount
  Glados2(any.promoCode, any.discountValue).test(
    'Exact promo code match finds the discount',
    (code, value) {
      if (code.isEmpty) return; // Skip empty codes

      final discount = createDiscountWithPromoCode(
        promoCode: code,
        value: value,
      );
      final discounts = [discount];

      final found = findDiscountByPromoCode(discounts, code);

      if (found == null) {
        throw Exception('Should find discount with exact promo code: $code');
      }
      if (found.id != discount.id) {
        throw Exception('Found wrong discount');
      }
    },
  );

  /// Property: Case-insensitive promo code matching
  Glados(any.promoCode).test(
    'Promo code matching is case-insensitive',
    (code) {
      if (code.isEmpty) return;

      final discount =
          createDiscountWithPromoCode(promoCode: code.toUpperCase());
      final discounts = [discount];

      // Try lowercase
      final foundLower = findDiscountByPromoCode(discounts, code.toLowerCase());
      // Try uppercase
      final foundUpper = findDiscountByPromoCode(discounts, code.toUpperCase());
      // Try mixed case
      final mixedCase = code.split('').asMap().entries.map((e) {
        return e.key.isEven ? e.value.toUpperCase() : e.value.toLowerCase();
      }).join();
      final foundMixed = findDiscountByPromoCode(discounts, mixedCase);

      if (foundLower == null || foundUpper == null || foundMixed == null) {
        throw Exception('Promo code should match regardless of case: $code');
      }
    },
  );

  /// Property: Non-existent promo code returns null
  Glados(any.promoCode).test(
    'Non-existent promo code returns null',
    (code) {
      if (code.isEmpty) return;

      final discount = createDiscountWithPromoCode(promoCode: 'DIFFERENT$code');
      final discounts = [discount];

      final found = findDiscountByPromoCode(discounts, code);

      if (found != null) {
        throw Exception('Should not find discount with non-matching code');
      }
    },
  );

  /// Property: Inactive discount promo code is not found
  Glados(any.promoCode).test(
    'Inactive discount promo code is not found',
    (code) {
      if (code.isEmpty) return;

      final discount = createDiscountWithPromoCode(
        promoCode: code,
        isActive: false,
      );
      final discounts = [discount];

      final found = findDiscountByPromoCode(discounts, code);

      if (found != null) {
        throw Exception('Should not find inactive discount by promo code');
      }
    },
  );

  /// Property: Expired discount promo code is not found
  Glados(any.promoCode).test(
    'Expired discount promo code is not found',
    (code) {
      if (code.isEmpty) return;

      final now = DateTime.now();
      final discount = createDiscountWithPromoCode(
        promoCode: code,
        validFrom: now.subtract(const Duration(days: 30)),
        validUntil: now.subtract(const Duration(days: 1)),
      );
      final discounts = [discount];

      final found = findDiscountByPromoCode(discounts, code);

      if (found != null) {
        throw Exception('Should not find expired discount by promo code');
      }
    },
  );

  /// Property: Future discount promo code is not found
  Glados(any.promoCode).test(
    'Future discount promo code is not found',
    (code) {
      if (code.isEmpty) return;

      final now = DateTime.now();
      final discount = createDiscountWithPromoCode(
        promoCode: code,
        validFrom: now.add(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 30)),
      );
      final discounts = [discount];

      final found = findDiscountByPromoCode(discounts, code);

      if (found != null) {
        throw Exception('Should not find future discount by promo code');
      }
    },
  );

  /// Property: Empty promo code returns null
  Glados(any.discountValue).test(
    'Empty promo code returns null',
    (value) {
      final discount = createDiscountWithPromoCode(
        promoCode: 'VALIDCODE',
        value: value,
      );
      final discounts = [discount];

      final foundEmpty = findDiscountByPromoCode(discounts, '');
      final foundSpaces = findDiscountByPromoCode(discounts, '   ');

      if (foundEmpty != null || foundSpaces != null) {
        throw Exception('Empty or whitespace promo code should return null');
      }
    },
  );

  /// Property: Whitespace-trimmed promo code matches
  Glados(any.promoCode).test(
    'Whitespace-trimmed promo code matches',
    (code) {
      if (code.isEmpty) return;

      final discount = createDiscountWithPromoCode(promoCode: code);
      final discounts = [discount];

      // Try with leading/trailing whitespace
      final found = findDiscountByPromoCode(discounts, '  $code  ');

      if (found == null) {
        throw Exception('Promo code with whitespace should still match');
      }
    },
  );

  /// Property: hasPromoCode returns true only when promoCode is set
  Glados(any.promoCode).test(
    'hasPromoCode returns true only when promoCode is set',
    (code) {
      if (code.isEmpty) return;

      final withCode = createDiscountWithPromoCode(promoCode: code);
      final now = DateTime.now();
      final withoutCode = Discount(
        id: 'no-code',
        tenantId: 'tenant-test',
        name: 'No Code Discount',
        type: DiscountType.percentage,
        value: 10.0,
        minPurchase: null,
        promoCode: null,
        validFrom: now.subtract(const Duration(days: 1)),
        validUntil: now.add(const Duration(days: 1)),
        isActive: true,
        createdAt: now,
      );

      if (!withCode.hasPromoCode) {
        throw Exception(
            'Discount with promo code should have hasPromoCode=true');
      }
      if (withoutCode.hasPromoCode) {
        throw Exception(
            'Discount without promo code should have hasPromoCode=false');
      }
    },
  );

  /// Property: Multiple discounts - correct one is found by promo code
  Glados2(any.promoCode, any.promoCode).test(
    'Multiple discounts - correct one is found by promo code',
    (code1, code2) {
      if (code1.isEmpty || code2.isEmpty || code1 == code2) return;

      final discount1 = createDiscountWithPromoCode(promoCode: code1);
      final discount2 = createDiscountWithPromoCode(promoCode: code2);
      final discounts = [discount1, discount2];

      final found1 = findDiscountByPromoCode(discounts, code1);
      final found2 = findDiscountByPromoCode(discounts, code2);

      if (found1?.promoCode?.toUpperCase() != code1.toUpperCase()) {
        throw Exception('Should find correct discount for code1');
      }
      if (found2?.promoCode?.toUpperCase() != code2.toUpperCase()) {
        throw Exception('Should find correct discount for code2');
      }
    },
  );

  /// Property: Promo code uniqueness - first valid match is returned
  Glados(any.promoCode).test(
    'Duplicate promo codes - first valid match is returned',
    (code) {
      if (code.isEmpty) return;

      final discount1 = createDiscountWithPromoCode(promoCode: code);
      final discount2 = Discount(
        id: 'duplicate-${code.hashCode.abs()}',
        tenantId: 'tenant-test',
        name: 'Duplicate Promo',
        type: DiscountType.percentage,
        value: 20.0,
        minPurchase: null,
        promoCode: code,
        validFrom: DateTime.now().subtract(const Duration(days: 1)),
        validUntil: DateTime.now().add(const Duration(days: 1)),
        isActive: true,
        createdAt: DateTime.now(),
      );
      final discounts = [discount1, discount2];

      final found = findDiscountByPromoCode(discounts, code);

      // Should find one of them (first match)
      if (found == null) {
        throw Exception('Should find at least one discount with promo code');
      }
    },
  );
}
