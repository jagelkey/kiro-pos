import 'package:flutter/material.dart';

/// Confirmation dialog for destructive actions
class ConfirmationDialog {
  /// Show confirmation dialog
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Ya',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isDestructive ? Icons.warning_amber : Icons.help_outline,
                  color: isDestructive ? Colors.orange : Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: isDestructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show delete confirmation
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String itemName,
    String? additionalMessage,
  }) async {
    return await show(
      context,
      title: 'Hapus $itemName',
      message: additionalMessage ??
          'Apakah Anda yakin ingin menghapus $itemName ini? '
              'Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );
  }

  /// Show logout confirmation
  static Future<bool> confirmLogout(BuildContext context) async {
    return await show(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar dari aplikasi?',
      confirmText: 'Keluar',
      cancelText: 'Batal',
      isDestructive: false,
    );
  }

  /// Show discard changes confirmation
  static Future<bool> confirmDiscardChanges(BuildContext context) async {
    return await show(
      context,
      title: 'Buang Perubahan',
      message: 'Anda memiliki perubahan yang belum disimpan. '
          'Apakah Anda yakin ingin membuang perubahan?',
      confirmText: 'Buang',
      cancelText: 'Batal',
      isDestructive: true,
    );
  }

  /// Show clear cart confirmation
  static Future<bool> confirmClearCart(BuildContext context) async {
    return await show(
      context,
      title: 'Kosongkan Keranjang',
      message: 'Apakah Anda yakin ingin mengosongkan keranjang?',
      confirmText: 'Kosongkan',
      cancelText: 'Batal',
      isDestructive: true,
    );
  }
}
