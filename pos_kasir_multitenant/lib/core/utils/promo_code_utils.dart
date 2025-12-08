/// Utility for promo code operations
/// Ensures case-insensitive promo code matching
class PromoCodeUtils {
  /// Normalize promo code to uppercase for consistent comparison
  /// Removes leading/trailing whitespace
  static String normalize(String? promoCode) {
    if (promoCode == null || promoCode.isEmpty) {
      return '';
    }
    return promoCode.trim().toUpperCase();
  }

  /// Check if two promo codes match (case-insensitive)
  static bool matches(String? code1, String? code2) {
    if (code1 == null || code2 == null) {
      return false;
    }
    return normalize(code1) == normalize(code2);
  }

  /// Validate promo code format
  /// Returns null if valid, error message if invalid
  static String? validate(String? promoCode) {
    if (promoCode == null || promoCode.trim().isEmpty) {
      return null; // Promo code is optional
    }

    final normalized = normalize(promoCode);

    if (normalized.length < 3) {
      return 'Kode promo minimal 3 karakter';
    }

    if (normalized.length > 20) {
      return 'Kode promo maksimal 20 karakter';
    }

    // Only allow alphanumeric and dash
    if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(normalized)) {
      return 'Kode promo hanya boleh huruf, angka, dan tanda hubung';
    }

    return null;
  }

  /// Format promo code for display (uppercase)
  static String format(String? promoCode) {
    return normalize(promoCode);
  }

  /// Generate a random promo code
  static String generate({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';

    for (var i = 0; i < length; i++) {
      code += chars[(random + i) % chars.length];
    }

    return code;
  }
}
