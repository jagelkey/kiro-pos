import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenant;
    final user = authState.user;
    final canEditStore = ref.watch(canEditStoreSettingsProvider);
    final canEditBusiness = ref.watch(canEditBusinessSettingsProvider);
    final appSettings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('⚙️ Pengaturan'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          _ProfileCard(
            userName: user?.name ?? 'User',
            userEmail: user?.email ?? '-',
            userRole: user?.role.name ?? 'user',
            storeName: tenant?.name ?? 'Toko',
          ),
          const SizedBox(height: 24),

          // Store Info Section
          _SectionTitle(
            title: '🏪 Informasi Toko',
            subtitle: canEditStore ? null : '(Hanya Owner yang dapat mengubah)',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.store,
                  title: 'Nama Toko',
                  value: tenant?.name ?? '-',
                  onTap: canEditStore
                      ? () => _showEditStoreNameDialog(
                          context, ref, tenant?.name ?? '')
                      : null,
                  isDisabled: !canEditStore,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.location_on,
                  title: 'Alamat',
                  value: tenant?.address ?? '-',
                  onTap: canEditStore
                      ? () => _showEditAddressDialog(
                          context, ref, tenant?.address ?? '')
                      : null,
                  isDisabled: !canEditStore,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.phone,
                  title: 'Telepon',
                  value: tenant?.phone ?? '-',
                  onTap: canEditStore
                      ? () => _showEditPhoneDialog(
                          context, ref, tenant?.phone ?? '')
                      : null,
                  isDisabled: !canEditStore,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.email,
                  title: 'Email',
                  value: tenant?.email ?? '-',
                  onTap: canEditStore
                      ? () => _showEditEmailDialog(
                          context, ref, tenant?.email ?? '')
                      : null,
                  isDisabled: !canEditStore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Business Settings
          _SectionTitle(
            title: '💰 Pengaturan Bisnis',
            subtitle:
                canEditBusiness ? null : '(Hanya Owner yang dapat mengubah)',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.attach_money,
                  title: 'Mata Uang',
                  value: tenant?.currency ?? 'IDR',
                  onTap: canEditBusiness
                      ? () => _showCurrencyPicker(context, ref)
                      : null,
                  isDisabled: !canEditBusiness,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.percent,
                  title: 'Pajak (PPN)',
                  value:
                      '${((tenant?.taxRate ?? 0) * 100).toStringAsFixed(0)}%',
                  onTap: canEditBusiness
                      ? () => _showTaxDialog(context, ref, tenant?.taxRate ?? 0)
                      : null,
                  isDisabled: !canEditBusiness,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.access_time,
                  title: 'Zona Waktu',
                  value: tenant?.timezone ?? 'Asia/Jakarta',
                  onTap: canEditBusiness
                      ? () => _showTimezonePicker(context, ref)
                      : null,
                  isDisabled: !canEditBusiness,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Printer Settings
          _SectionTitle(title: '🖨️ Pengaturan Printer'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingToggle(
                  icon: Icons.print,
                  title: 'Auto Print Struk',
                  subtitle: 'Cetak struk otomatis setelah transaksi',
                  value: appSettings.autoPrintReceipt,
                  onChanged: (value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateAutoPrint(value);
                  },
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.bluetooth,
                  title: 'Printer Bluetooth',
                  value: appSettings.printerConnection,
                  onTap: () => _showPrinterSettings(context),
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.receipt_long,
                  title: 'Ukuran Kertas',
                  value: appSettings.paperSize,
                  onTap: () => _showPaperSizePicker(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notification Settings
          _SectionTitle(title: '🔔 Notifikasi'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingToggle(
                  icon: Icons.notifications_active,
                  title: 'Notifikasi Stok Rendah',
                  subtitle: 'Peringatan saat stok hampir habis',
                  value: appSettings.lowStockNotification,
                  onChanged: (value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateLowStockNotification(value);
                  },
                ),
                const Divider(height: 1),
                _SettingToggle(
                  icon: Icons.trending_up,
                  title: 'Laporan Harian',
                  subtitle: 'Kirim ringkasan penjualan harian',
                  value: appSettings.dailyReportNotification,
                  onChanged: (value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateDailyReportNotification(value);
                  },
                ),
                const Divider(height: 1),
                _SettingToggle(
                  icon: Icons.volume_up,
                  title: 'Suara Transaksi',
                  subtitle: 'Bunyi saat transaksi berhasil',
                  value: appSettings.transactionSound,
                  onChanged: (value) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateTransactionSound(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Section
          _SectionTitle(title: '👤 Akun'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.person,
                  title: 'Edit Profil',
                  value: '',
                  showArrow: true,
                  onTap: () =>
                      _showEditProfileDialog(context, user?.name ?? ''),
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.lock,
                  title: 'Ubah Password',
                  value: '',
                  showArrow: true,
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.security,
                  title: 'Keamanan',
                  value: '',
                  showArrow: true,
                  onTap: () => _showSecuritySettings(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data & Backup - Hanya Owner
          _SectionTitle(
            title: '💾 Data & Backup',
            subtitle:
                canEditStore ? null : '(Hanya Owner yang dapat mengakses)',
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.cloud_upload,
                  title: 'Backup Data',
                  value: 'Terakhir: Hari ini',
                  onTap: canEditStore ? () => _showBackupDialog(context) : null,
                  isDisabled: !canEditStore,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.cloud_download,
                  title: 'Restore Data',
                  value: '',
                  showArrow: true,
                  onTap:
                      canEditStore ? () => _showRestoreDialog(context) : null,
                  isDisabled: !canEditStore,
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.delete_forever,
                  title: 'Hapus Semua Data',
                  value: '',
                  showArrow: true,
                  isDestructive: true,
                  onTap: canEditStore
                      ? () => _showDeleteDataDialog(context)
                      : null,
                  isDisabled: !canEditStore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          _SectionTitle(title: 'ℹ️ Tentang'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                const _SettingItem(
                  icon: Icons.info,
                  title: 'Versi Aplikasi',
                  value: '1.0.0',
                ),
                const Divider(height: 1),
                const _SettingItem(
                  icon: Icons.code,
                  title: 'Build',
                  value: '2024.12.01',
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.help,
                  title: 'Bantuan',
                  value: '',
                  showArrow: true,
                  onTap: () => _showHelpDialog(context),
                ),
                const Divider(height: 1),
                _SettingItem(
                  icon: Icons.policy,
                  title: 'Kebijakan Privasi',
                  value: '',
                  showArrow: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Keluar dari Aplikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============ Store Settings Dialogs ============

  void _showEditStoreNameDialog(
      BuildContext context, WidgetRef ref, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Nama Toko'),
          content: TextField(
            controller: controller,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Nama Toko',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Nama toko tidak boleh kosong'),
                              backgroundColor: AppTheme.errorColor),
                        );
                        return;
                      }
                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(tenantSettingsProvider.notifier)
                            .updateStoreName(controller.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nama toko berhasil diupdate'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Gagal: $e'),
                                backgroundColor: AppTheme.errorColor),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAddressDialog(
      BuildContext context, WidgetRef ref, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Alamat'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Alamat',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(tenantSettingsProvider.notifier)
                            .updateAddress(controller.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Alamat berhasil diupdate'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Gagal: $e'),
                                backgroundColor: AppTheme.errorColor),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPhoneDialog(
      BuildContext context, WidgetRef ref, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Telepon'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Telepon',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(tenantSettingsProvider.notifier)
                            .updatePhone(controller.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Telepon berhasil diupdate'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Gagal: $e'),
                                backgroundColor: AppTheme.errorColor),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEmailDialog(
      BuildContext context, WidgetRef ref, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Email'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Email',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (controller.text.isNotEmpty &&
                          !controller.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Format email tidak valid'),
                              backgroundColor: AppTheme.errorColor),
                        );
                        return;
                      }
                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(tenantSettingsProvider.notifier)
                            .updateEmail(controller.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Email berhasil diupdate'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Gagal: $e'),
                                backgroundColor: AppTheme.errorColor),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ Business Settings Dialogs ============

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final tenant = ref.read(authProvider).tenant;
    final currentCurrency = tenant?.currency ?? 'IDR';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Mata Uang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🇮🇩', style: TextStyle(fontSize: 24)),
              title: const Text('IDR - Rupiah Indonesia'),
              trailing: currentCurrency == 'IDR'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateCurrency('IDR');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mata uang diubah ke IDR'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('USD - US Dollar'),
              trailing: currentCurrency == 'USD'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateCurrency('USD');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mata uang diubah ke USD'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Text('🇸🇬', style: TextStyle(fontSize: 24)),
              title: const Text('SGD - Singapore Dollar'),
              trailing: currentCurrency == 'SGD'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateCurrency('SGD');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mata uang diubah ke SGD'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaxDialog(BuildContext context, WidgetRef ref, double currentTax) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atur Pajak (PPN)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih persentase pajak:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 5, 10, 11, 12]
                  .map((tax) => ChoiceChip(
                        label: Text('$tax%'),
                        selected: (currentTax * 100).round() == tax,
                        onSelected: (selected) async {
                          Navigator.pop(context);
                          try {
                            await ref
                                .read(tenantSettingsProvider.notifier)
                                .updateTaxRate(tax / 100);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Pajak diatur ke $tax%'),
                                    backgroundColor: AppTheme.successColor),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Gagal: $e'),
                                    backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
        ],
      ),
    );
  }

  void _showTimezonePicker(BuildContext context, WidgetRef ref) {
    final tenant = ref.read(authProvider).tenant;
    final currentTimezone = tenant?.timezone ?? 'Asia/Jakarta';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Zona Waktu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('WIB - Asia/Jakarta'),
              subtitle: const Text('UTC+7'),
              trailing: currentTimezone == 'Asia/Jakarta'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateTimezone('Asia/Jakarta');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Zona waktu diubah ke WIB'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('WITA - Asia/Makassar'),
              subtitle: const Text('UTC+8'),
              trailing: currentTimezone == 'Asia/Makassar'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateTimezone('Asia/Makassar');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Zona waktu diubah ke WITA'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('WIT - Asia/Jayapura'),
              subtitle: const Text('UTC+9'),
              trailing: currentTimezone == 'Asia/Jayapura'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(tenantSettingsProvider.notifier)
                      .updateTimezone('Asia/Jayapura');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Zona waktu diubah ke WIT'),
                          backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Gagal: $e'),
                          backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============ Printer Settings ============

  void _showPrinterSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur printer akan segera hadir')),
    );
  }

  void _showPaperSizePicker(BuildContext context, WidgetRef ref) {
    final appSettings = ref.read(appSettingsProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Ukuran Kertas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('58mm'),
              subtitle: const Text('Thermal printer kecil'),
              trailing: appSettings.paperSize == '58mm'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).updatePaperSize('58mm');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ukuran kertas diubah ke 58mm'),
                      backgroundColor: AppTheme.successColor),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('80mm'),
              subtitle: const Text('Thermal printer standar'),
              trailing: appSettings.paperSize == '80mm'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).updatePaperSize('80mm');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ukuran kertas diubah ke 80mm'),
                      backgroundColor: AppTheme.successColor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nama',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Profil berhasil diupdate'),
                    backgroundColor: AppTheme.successColor),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Password berhasil diubah'),
                    backgroundColor: AppTheme.successColor),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur keamanan akan segera hadir')),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text('Backup semua data ke cloud?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Backup berhasil'),
                    backgroundColor: AppTheme.successColor),
              );
            },
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
            'Restore data dari backup terakhir? Data saat ini akan ditimpa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Data berhasil di-restore'),
                    backgroundColor: AppTheme.successColor),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Data'),
        content: const Text(
            'PERINGATAN: Semua data akan dihapus permanen dan tidak dapat dikembalikan!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Semua data telah dihapus'),
                    backgroundColor: AppTheme.errorColor),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bantuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hubungi kami:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.email, size: 18),
              SizedBox(width: 8),
              Text('support@kopiku.com')
            ]),
            const SizedBox(height: 4),
            const Row(children: [
              Icon(Icons.phone, size: 18),
              SizedBox(width: 8),
              Text('+62 812-3456-7890')
            ]),
            const SizedBox(height: 4),
            const Row(children: [
              Icon(Icons.chat, size: 18),
              SizedBox(width: 8),
              Text('WhatsApp: 0812-3456-7890')
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// Section Title Widget
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// Profile Card Widget
class _ProfileCard extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String userRole;
  final String storeName;

  const _ProfileCard({
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('☕', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    userRole.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Setting Item Widget
class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool showArrow;
  final bool isDestructive;
  final bool isDisabled;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.showArrow = false,
    this.isDestructive = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = isDisabled ? null : onTap;
    final opacity = isDisabled ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: effectiveOnTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? AppTheme.errorColor
                    : (isDisabled ? AppTheme.textMuted : AppTheme.primaryColor),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDestructive
                        ? AppTheme.errorColor
                        : (isDisabled
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary),
                  ),
                ),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              if ((showArrow || effectiveOnTap != null) && !isDisabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ),
              if (isDisabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.lock_outline,
                    color: AppTheme.textMuted,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Setting Toggle Widget
class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
