import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/tenant.dart';
import '../../data/database/database_helper.dart';
import '../auth/auth_provider.dart';

/// App Settings Model - untuk pengaturan yang tidak terkait tenant
class AppSettings {
  final bool autoPrintReceipt;
  final String printerConnection;
  final String paperSize;
  final bool lowStockNotification;
  final bool dailyReportNotification;
  final bool transactionSound;

  const AppSettings({
    this.autoPrintReceipt = true,
    this.printerConnection = 'Tidak terhubung',
    this.paperSize = '58mm',
    this.lowStockNotification = true,
    this.dailyReportNotification = false,
    this.transactionSound = true,
  });

  AppSettings copyWith({
    bool? autoPrintReceipt,
    String? printerConnection,
    String? paperSize,
    bool? lowStockNotification,
    bool? dailyReportNotification,
    bool? transactionSound,
  }) {
    return AppSettings(
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      printerConnection: printerConnection ?? this.printerConnection,
      paperSize: paperSize ?? this.paperSize,
      lowStockNotification: lowStockNotification ?? this.lowStockNotification,
      dailyReportNotification:
          dailyReportNotification ?? this.dailyReportNotification,
      transactionSound: transactionSound ?? this.transactionSound,
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_print_receipt': autoPrintReceipt,
        'printer_connection': printerConnection,
        'paper_size': paperSize,
        'low_stock_notification': lowStockNotification,
        'daily_report_notification': dailyReportNotification,
        'transaction_sound': transactionSound,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        autoPrintReceipt: json['auto_print_receipt'] ?? true,
        printerConnection: json['printer_connection'] ?? 'Tidak terhubung',
        paperSize: json['paper_size'] ?? '58mm',
        lowStockNotification: json['low_stock_notification'] ?? true,
        dailyReportNotification: json['daily_report_notification'] ?? false,
        transactionSound: json['transaction_sound'] ?? true,
      );
}

/// Provider untuk mengecek apakah user bisa mengakses pengaturan toko
/// Requirements: Hanya Owner yang bisa mengubah pengaturan toko
final canEditStoreSettingsProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return false;
  return user.hasOwnerAccess;
});

/// Provider untuk mengecek apakah user bisa mengakses pengaturan bisnis
final canEditBusinessSettingsProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) return false;
  return user.hasOwnerAccess;
});

/// Provider untuk app settings
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoPrint = prefs.getBool('auto_print_receipt') ?? true;
      final paperSize = prefs.getString('paper_size') ?? '58mm';
      final lowStock = prefs.getBool('low_stock_notification') ?? true;
      final dailyReport = prefs.getBool('daily_report_notification') ?? false;
      final sound = prefs.getBool('transaction_sound') ?? true;

      state = AppSettings(
        autoPrintReceipt: autoPrint,
        paperSize: paperSize,
        lowStockNotification: lowStock,
        dailyReportNotification: dailyReport,
        transactionSound: sound,
      );
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  void updateAutoPrint(bool value) {
    state = state.copyWith(autoPrintReceipt: value);
    _saveSettings();
  }

  void updatePaperSize(String value) {
    state = state.copyWith(paperSize: value);
    _saveSettings();
  }

  void updateLowStockNotification(bool value) {
    state = state.copyWith(lowStockNotification: value);
    _saveSettings();
  }

  void updateDailyReportNotification(bool value) {
    state = state.copyWith(dailyReportNotification: value);
    _saveSettings();
  }

  void updateTransactionSound(bool value) {
    state = state.copyWith(transactionSound: value);
    _saveSettings();
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_print_receipt', state.autoPrintReceipt);
      await prefs.setString('paper_size', state.paperSize);
      await prefs.setBool('low_stock_notification', state.lowStockNotification);
      await prefs.setBool(
          'daily_report_notification', state.dailyReportNotification);
      await prefs.setBool('transaction_sound', state.transactionSound);
    } catch (e) {
      debugPrint('Error saving app settings: $e');
    }
  }
}

/// Provider untuk tenant settings
final tenantSettingsProvider =
    StateNotifierProvider<TenantSettingsNotifier, AsyncValue<Tenant?>>((ref) {
  return TenantSettingsNotifier(ref);
});

class TenantSettingsNotifier extends StateNotifier<AsyncValue<Tenant?>> {
  final Ref ref;

  TenantSettingsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadTenant();
  }

  void _loadTenant() {
    final authState = ref.read(authProvider);
    state = AsyncValue.data(authState.tenant);
  }

  /// Refresh tenant from auth state
  void refresh() {
    _loadTenant();
  }

  /// Get current tenant from auth state (always fresh)
  Tenant? get _currentTenant => ref.read(authProvider).tenant;

  /// Update tenant info
  /// Requirements: Hanya Owner yang bisa mengubah
  Future<void> updateTenant(Tenant tenant) async {
    final authState = ref.read(authProvider);
    if (authState.user == null || !authState.user!.hasOwnerAccess) {
      throw Exception('Anda tidak memiliki izin untuk mengubah pengaturan');
    }

    // Validate tenant ID matches current tenant
    if (authState.tenant?.id != tenant.id) {
      throw Exception('Tidak dapat mengubah pengaturan tenant lain');
    }

    try {
      if (kIsWeb) {
        // Update auth state dengan tenant baru (in-memory untuk web)
        ref.read(authProvider.notifier).setTenant(tenant);
        state = AsyncValue.data(tenant);
      } else {
        final db = await DatabaseHelper.instance.database;

        // Validate tenant exists
        final existing = await db.query(
          'tenants',
          where: 'id = ?',
          whereArgs: [tenant.id],
        );
        if (existing.isEmpty) {
          throw Exception('Tenant tidak ditemukan');
        }

        await db.update(
          'tenants',
          tenant.toMap(),
          where: 'id = ?',
          whereArgs: [tenant.id],
        );
        ref.read(authProvider.notifier).setTenant(tenant);
        state = AsyncValue.data(tenant);
      }
    } catch (e, stack) {
      debugPrint('Error updating tenant: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update nama toko
  Future<void> updateStoreName(String name) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    if (name.trim().isEmpty) {
      throw Exception('Nama toko tidak boleh kosong');
    }
    await updateTenant(current.copyWith(name: name.trim()));
  }

  /// Update alamat
  Future<void> updateAddress(String address) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    await updateTenant(
        current.copyWith(address: address.isEmpty ? null : address.trim()));
  }

  /// Update telepon
  Future<void> updatePhone(String phone) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    await updateTenant(
        current.copyWith(phone: phone.isEmpty ? null : phone.trim()));
  }

  /// Update email
  Future<void> updateEmail(String email) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    if (email.isNotEmpty && !email.contains('@')) {
      throw Exception('Format email tidak valid');
    }
    await updateTenant(
        current.copyWith(email: email.isEmpty ? null : email.trim()));
  }

  /// Update mata uang
  Future<void> updateCurrency(String currency) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    if (!['IDR', 'USD', 'SGD'].contains(currency)) {
      throw Exception('Mata uang tidak valid');
    }
    await updateTenant(current.copyWith(currency: currency));
  }

  /// Update pajak
  Future<void> updateTaxRate(double taxRate) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    if (taxRate < 0 || taxRate > 1) {
      throw Exception('Nilai pajak tidak valid (0-100%)');
    }
    await updateTenant(current.copyWith(taxRate: taxRate));
  }

  /// Update timezone
  Future<void> updateTimezone(String timezone) async {
    final current = _currentTenant;
    if (current == null) {
      throw Exception('Tenant tidak ditemukan');
    }
    if (!['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura']
        .contains(timezone)) {
      throw Exception('Zona waktu tidak valid');
    }
    await updateTenant(current.copyWith(timezone: timezone));
  }
}
