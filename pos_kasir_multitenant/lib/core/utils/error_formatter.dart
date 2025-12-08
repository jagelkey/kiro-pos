import 'package:flutter/material.dart';

/// Error message formatter
/// Converts technical errors to user-friendly messages
class ErrorFormatter {
  /// Format error to user-friendly message
  static String format(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Database errors
    if (errorStr.contains('unique constraint') ||
        errorStr.contains('duplicate')) {
      return 'Data sudah ada. Silakan gunakan nama atau kode lain.';
    }

    if (errorStr.contains('foreign key constraint')) {
      return 'Data tidak dapat dihapus karena masih digunakan di tempat lain.';
    }

    if (errorStr.contains('not found') && errorStr.contains('table')) {
      return 'Terjadi kesalahan database. Silakan hubungi support.';
    }

    // Network errors
    if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Koneksi internet bermasalah. Silakan cek koneksi Anda dan coba lagi.';
    }

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Permintaan memakan waktu terlalu lama. Silakan coba lagi.';
    }

    if (errorStr.contains('connection refused') ||
        errorStr.contains('failed to connect')) {
      return 'Tidak dapat terhubung ke server. Silakan cek koneksi internet Anda.';
    }

    // Authentication errors
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Sesi Anda telah berakhir. Silakan login kembali.';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'Anda tidak memiliki akses ke fitur ini.';
    }

    if (errorStr.contains('password') && errorStr.contains('salah')) {
      return 'Password yang Anda masukkan salah.';
    }

    if (errorStr.contains('email') && errorStr.contains('tidak ditemukan')) {
      return 'Email tidak terdaftar dalam sistem.';
    }

    // Validation errors
    if (errorStr.contains('insufficient stock') ||
        errorStr.contains('stok tidak mencukupi')) {
      return 'Stok tidak mencukupi untuk transaksi ini.';
    }

    if (errorStr.contains('invalid') || errorStr.contains('tidak valid')) {
      return 'Data yang dimasukkan tidak valid. Silakan periksa kembali.';
    }

    if (errorStr.contains('required') || errorStr.contains('wajib')) {
      return 'Mohon lengkapi semua field yang wajib diisi.';
    }

    // Business logic errors
    if (errorStr.contains('shift') && errorStr.contains('aktif')) {
      return 'Anda masih memiliki shift aktif. Silakan tutup shift sebelumnya terlebih dahulu.';
    }

    if (errorStr.contains('minimum purchase') ||
        errorStr.contains('minimal pembelian')) {
      return 'Total pembelian belum memenuhi syarat minimum untuk diskon ini.';
    }

    if (errorStr.contains('expired') || errorStr.contains('kadaluarsa')) {
      return 'Diskon atau promo telah kadaluarsa.';
    }

    // File/Image errors
    if (errorStr.contains('file') && errorStr.contains('too large')) {
      return 'Ukuran file terlalu besar. Maksimal 500KB.';
    }

    if (errorStr.contains('image') && errorStr.contains('format')) {
      return 'Format gambar tidak didukung. Gunakan JPG atau PNG.';
    }

    // Generic fallback
    if (errorStr.contains('exception:')) {
      // Extract message after "Exception:"
      final parts = errorStr.split('exception:');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }

    return 'Terjadi kesalahan. Silakan coba lagi atau hubungi support jika masalah berlanjut.';
  }

  /// Show error as SnackBar
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(format(error)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show info message
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning message
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
