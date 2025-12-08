/// Application Configuration for Production
///
/// Ubah nilai-nilai ini sesuai kebutuhan produksi
class AppConfig {
  // ============ APP INFO ============
  static const String appName = 'POS Kasir';
  static const String appVersion = '3.5.0';
  static const String buildNumber = '7';

  // ============ PRODUCTION FLAGS ============
  /// Set true untuk mode produksi (tanpa demo data)
  static const bool isProduction = true;

  /// Set true untuk mengaktifkan logging di production
  static const bool enableLogging = true;

  /// Set true untuk mengaktifkan analytics
  static const bool enableAnalytics = false;

  // ============ CLOUD SYNC ============
  /// Flag to indicate if Supabase is available and should be used
  /// This is set at runtime during initialization
  static bool useSupabase = false;

  /// Prefer cloud data over local when both are available
  static const bool preferCloudData = true;

  // ============ BUSINESS DEFAULTS ============
  /// Default tax rate (11% = 0.11)
  static const double defaultTaxRate = 0.11;

  /// Default currency
  static const String defaultCurrency = 'IDR';

  /// Default timezone
  static const String defaultTimezone = 'Asia/Jakarta';

  /// Low stock threshold
  static const int lowStockThreshold = 10;

  // ============ DATABASE ============
  /// Database name
  static const String databaseName = 'pos_kasir.db';

  /// Database version (increment when schema changes)
  static const int databaseVersion = 1;

  // ============ UI SETTINGS ============
  /// Items per page for pagination
  static const int itemsPerPage = 20;

  /// Max image size in bytes (5MB)
  static const int maxImageSize = 5 * 1024 * 1024;

  // ============ SECURITY ============
  /// Session timeout in minutes
  static const int sessionTimeoutMinutes = 480; // 8 hours

  /// Max login attempts before lockout
  static const int maxLoginAttempts = 5;

  /// Lockout duration in minutes
  static const int lockoutDurationMinutes = 15;
}
