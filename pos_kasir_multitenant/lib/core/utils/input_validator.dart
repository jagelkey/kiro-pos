/// Input validation utilities
/// Provides consistent validation across all forms
class InputValidator {
  /// Trim and validate required field
  static String? validateRequired(String? value, String fieldName) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  /// Validate and normalize email
  static String? validateEmail(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Email wajib diisi';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmed)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Validate positive number
  static String? validatePositiveNumber(String? value, String fieldName) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }

    final number = double.tryParse(trimmed);
    if (number == null) {
      return '$fieldName harus berupa angka';
    }
    if (number <= 0) {
      return '$fieldName harus lebih dari 0';
    }
    return null;
  }

  /// Validate non-negative number (allows zero)
  static String? validateNonNegativeNumber(String? value, String fieldName) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }

    final number = double.tryParse(trimmed);
    if (number == null) {
      return '$fieldName harus berupa angka';
    }
    if (number < 0) {
      return '$fieldName tidak boleh negatif';
    }
    return null;
  }

  /// Validate integer
  static String? validateInteger(String? value, String fieldName) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }

    final number = int.tryParse(trimmed);
    if (number == null) {
      return '$fieldName harus berupa angka bulat';
    }
    return null;
  }

  /// Validate phone number (Indonesian format)
  static String? validatePhone(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Nomor telepon wajib diisi';
    }

    // Remove common separators
    final cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if starts with valid prefix and has valid length
    if (!RegExp(r'^(0|62|\+62)[0-9]{8,12}$').hasMatch(cleaned)) {
      return 'Format nomor telepon tidak valid';
    }
    return null;
  }

  /// Validate minimum length
  static String? validateMinLength(
      String? value, String fieldName, int minLength) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }
    if (trimmed.length < minLength) {
      return '$fieldName minimal $minLength karakter';
    }
    return null;
  }

  /// Validate maximum length
  static String? validateMaxLength(
      String? value, String fieldName, int maxLength) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.length > maxLength) {
      return '$fieldName maksimal $maxLength karakter';
    }
    return null;
  }

  /// Normalize text for comparison (lowercase, trimmed)
  static String normalize(String text) {
    return text.trim().toLowerCase();
  }

  /// Validate barcode format
  static String? validateBarcode(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null; // Barcode is optional
    }

    // Allow alphanumeric and common barcode characters
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(trimmed)) {
      return 'Barcode hanya boleh berisi huruf, angka, dan tanda minus';
    }

    if (trimmed.length < 3) {
      return 'Barcode minimal 3 karakter';
    }

    return null;
  }

  /// Validate percentage (0-100)
  static String? validatePercentage(String? value, String fieldName) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$fieldName wajib diisi';
    }

    final number = double.tryParse(trimmed);
    if (number == null) {
      return '$fieldName harus berupa angka';
    }
    if (number < 0 || number > 100) {
      return '$fieldName harus antara 0 dan 100';
    }
    return null;
  }
}
