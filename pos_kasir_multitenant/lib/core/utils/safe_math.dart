/// Safe math operations to prevent division by zero and other edge cases
class SafeMath {
  /// Safe division that returns 0 if divisor is 0
  static double safeDivide(double numerator, double denominator,
      {double defaultValue = 0.0}) {
    if (denominator == 0 || denominator.isNaN || denominator.isInfinite) {
      return defaultValue;
    }
    final result = numerator / denominator;
    if (result.isNaN || result.isInfinite) {
      return defaultValue;
    }
    return result;
  }

  /// Calculate percentage safely
  /// Returns 0 if total is 0
  static double safePercentage(double value, double total,
      {double defaultValue = 0.0}) {
    if (total == 0 || total.isNaN || total.isInfinite) {
      return defaultValue;
    }
    final result = (value / total) * 100;
    if (result.isNaN || result.isInfinite) {
      return defaultValue;
    }
    return result;
  }

  /// Calculate average safely
  /// Returns 0 if count is 0
  static double safeAverage(double sum, int count,
      {double defaultValue = 0.0}) {
    if (count == 0) return defaultValue;
    return safeDivide(sum, count.toDouble(), defaultValue: defaultValue);
  }

  /// Calculate growth rate safely
  /// Returns 0 if previous value is 0
  static double safeGrowthRate(double current, double previous,
      {double defaultValue = 0.0}) {
    if (previous == 0) return defaultValue;
    return safeDivide(current - previous, previous,
            defaultValue: defaultValue) *
        100;
  }

  /// Clamp value between min and max
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Round to specified decimal places
  static double roundTo(double value, int decimalPlaces) {
    final multiplier = 10.0 * decimalPlaces;
    return (value * multiplier).round() / multiplier;
  }

  /// Check if value is valid (not NaN, not infinite)
  static bool isValid(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  /// Get valid value or default
  static double getValidOrDefault(double value, {double defaultValue = 0.0}) {
    return isValid(value) ? value : defaultValue;
  }
}
