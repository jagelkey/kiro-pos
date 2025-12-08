/// Checkout Action Suggestions
enum CheckoutAction {
  retry,
  removeFromCart,
  refreshData,
  contactSupport,
  none,
}

/// Checkout Exception
/// Custom exception for checkout operations with user-friendly messages
class CheckoutException implements Exception {
  final String message;
  final String? userMessage;
  final CheckoutAction suggestedAction;
  final dynamic originalError;

  CheckoutException(
    this.message, {
    this.userMessage,
    this.suggestedAction = CheckoutAction.none,
    this.originalError,
  });

  /// Get display message for user
  String get displayMessage => userMessage ?? message;

  /// Get action button text
  String get actionText {
    switch (suggestedAction) {
      case CheckoutAction.retry:
        return 'Coba Lagi';
      case CheckoutAction.removeFromCart:
        return 'Hapus dari Keranjang';
      case CheckoutAction.refreshData:
        return 'Refresh Data';
      case CheckoutAction.contactSupport:
        return 'Hubungi Support';
      case CheckoutAction.none:
        return 'OK';
    }
  }

  @override
  String toString() => message;
}
