import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/discount.dart';
import '../../data/models/user.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_provider.dart';
import 'discount_provider.dart';

/// Provider for discount list with enhanced state management
final discountListProvider =
    StateNotifierProvider<DiscountListNotifier, DiscountListState>((ref) {
  return DiscountListNotifier(ref);
});

/// State class for discount list
class DiscountListState {
  final List<Discount> discounts;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  DiscountListState({
    this.discounts = const [],
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  bool get hasError => error != null && error!.isNotEmpty;

  DiscountListState copyWith({
    List<Discount>? discounts,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isOffline,
  }) {
    return DiscountListState(
      discounts: discounts ?? this.discounts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class DiscountListNotifier extends StateNotifier<DiscountListState> {
  final Ref ref;
  final DiscountProvider _provider = DiscountProvider();

  DiscountListNotifier(this.ref) : super(DiscountListState(isLoading: true)) {
    loadDiscounts();
  }

  Future<void> loadDiscounts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user != null) {
        await _provider.loadDiscounts(user.tenantId);
        state = state.copyWith(
          discounts: _provider.discounts,
          isLoading: false,
          isOffline: !kIsWeb,
        );
      } else {
        state = state.copyWith(
          discounts: [],
          isLoading: false,
          error: 'User tidak ditemukan. Silakan login ulang.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data diskon: $e',
      );
    }
  }

  void retry() {
    state = state.copyWith(clearError: true);
    loadDiscounts();
  }

  DiscountProvider get provider => _provider;
}

/// Discount management screen
/// Requirements 14.1, 14.7: Discount management UI
class DiscountScreen extends ConsumerWidget {
  const DiscountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountState = ref.watch(discountListProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Check if user is logged in
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('🏷️ Manajemen Diskon'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Silakan login untuk mengakses diskon',
                  style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    // Check role - only owner/manager can manage discounts
    final canManage =
        user.role == UserRole.owner || user.role == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            const Text('🏷️ Manajemen Diskon'),
            const SizedBox(width: 8),
            // Offline indicator
            if (discountState.isOffline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_bolt,
                        size: 12, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style:
                          TextStyle(fontSize: 10, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(discountListProvider.notifier).loadDiscounts(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showDiscountDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Diskon'),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
      body: _buildBody(context, ref, discountState, canManage),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      DiscountListState state, bool canManage) {
    // Loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state with retry
    if (state.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Gagal Memuat Diskon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error ?? 'Terjadi kesalahan',
                style: TextStyle(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(discountListProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Data state
    return _DiscountList(discounts: state.discounts, canManage: canManage);
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref,
      {Discount? discount}) {
    showDialog(
      context: context,
      builder: (context) => _DiscountFormDialog(discount: discount),
    ).then((result) {
      if (result == true) {
        ref.read(discountListProvider.notifier).loadDiscounts();
      }
    });
  }
}

/// Discount list widget
class _DiscountList extends ConsumerWidget {
  final List<Discount> discounts;
  final bool canManage;

  const _DiscountList({required this.discounts, this.canManage = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (discounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'Belum ada diskon',
              style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              canManage
                  ? 'Tambahkan diskon untuk menarik pelanggan'
                  : 'Belum ada diskon yang tersedia',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    // Summary stats
    final activeCount = discounts.where((d) => d.isCurrentlyValid).length;
    final expiredCount =
        discounts.where((d) => DateTime.now().isAfter(d.validUntil)).length;

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  label: 'Total',
                  value: '${discounts.length}',
                  color: Colors.blue),
              _StatItem(
                  label: 'Aktif', value: '$activeCount', color: Colors.green),
              _StatItem(
                  label: 'Kadaluarsa',
                  value: '$expiredCount',
                  color: Colors.red),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: discounts.length,
            itemBuilder: (context, index) => _DiscountCard(
              discount: discounts[index],
              canManage: canManage,
              onEdit: canManage
                  ? () => _showEditDialog(context, ref, discounts[index])
                  : null,
              onDelete: canManage
                  ? () => _confirmDelete(context, ref, discounts[index])
                  : null,
              onToggle: canManage
                  ? () => _toggleStatus(context, ref, discounts[index])
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Discount discount) {
    showDialog(
      context: context,
      builder: (context) => _DiscountFormDialog(discount: discount),
    ).then((result) {
      if (result == true) {
        ref.read(discountListProvider.notifier).loadDiscounts();
      }
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Discount discount) {
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Diskon'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yakin ingin menghapus diskon "${discount.name}"?'),
              const SizedBox(height: 8),
              Text(
                'Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        final authState = ref.read(authProvider);
                        final provider =
                            ref.read(discountListProvider.notifier).provider;
                        // Pass tenantId for multi-tenant validation
                        final result = await provider.deleteDiscount(
                          discount.id,
                          tenantId: authState.user?.tenantId,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (result.success) {
                            ref
                                .read(discountListProvider.notifier)
                                .loadDiscounts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Diskon berhasil dihapus'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(result.error ?? 'Gagal menghapus'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(
      BuildContext context, WidgetRef ref, Discount discount) async {
    try {
      final provider = ref.read(discountListProvider.notifier).provider;
      final result =
          await provider.toggleStatus(discount.id, !discount.isActive);
      ref.read(discountListProvider.notifier).loadDiscounts();

      if (result.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(discount.isActive
                  ? 'Diskon dinonaktifkan'
                  : 'Diskon diaktifkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Gagal mengubah status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Stat item widget for summary bar
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }
}

/// Discount card widget
class _DiscountCard extends StatelessWidget {
  final Discount discount;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggle;

  const _DiscountCard({
    required this.discount,
    this.canManage = true,
    this.onEdit,
    this.onDelete,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = discount.isCurrentlyValid;
    final isExpired = DateTime.now().isAfter(discount.validUntil);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getTypeColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  discount.isPercentage ? Icons.percent : Icons.attach_money,
                  color: _getTypeColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      discount.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getDiscountValueText(),
                      style: TextStyle(
                        color: _getTypeColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                isActive: discount.isActive,
                isValid: isValid,
                isExpired: isExpired,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.calendar_today,
                label:
                    '${DateFormat('dd/MM/yy').format(discount.validFrom)} - ${DateFormat('dd/MM/yy').format(discount.validUntil)}',
              ),
              if (discount.minPurchase != null)
                _DetailChip(
                  icon: Icons.shopping_cart,
                  label: 'Min. ${_formatCurrency(discount.minPurchase!)}',
                ),
              if (discount.hasPromoCode)
                _DetailChip(
                  icon: Icons.confirmation_number,
                  label: discount.promoCode!,
                  highlight: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions (only if canManage)
          if (canManage) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onToggle != null)
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      discount.isActive ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(discount.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text('Hapus',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor() {
    return discount.isPercentage ? Colors.purple : Colors.teal;
  }

  String _getDiscountValueText() {
    if (discount.isPercentage) {
      return '${discount.value.toStringAsFixed(0)}% OFF';
    } else {
      return '${_formatCurrency(discount.value)} OFF';
    }
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

/// Status badge widget
class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isValid;
  final bool isExpired;

  const _StatusBadge({
    required this.isActive,
    required this.isValid,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (!isActive) {
      color = Colors.grey;
      label = 'Nonaktif';
    } else if (isExpired) {
      color = Colors.red;
      label = 'Kadaluarsa';
    } else if (isValid) {
      color = Colors.green;
      label = 'Aktif';
    } else {
      color = Colors.orange;
      label = 'Belum Mulai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Detail chip widget
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _DetailChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppTheme.primaryColor : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: highlight ? AppTheme.primaryColor : AppTheme.textMuted,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Discount form dialog
class _DiscountFormDialog extends ConsumerStatefulWidget {
  final Discount? discount;

  const _DiscountFormDialog({this.discount});

  @override
  ConsumerState<_DiscountFormDialog> createState() =>
      _DiscountFormDialogState();
}

class _DiscountFormDialogState extends ConsumerState<_DiscountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _valueController;
  late TextEditingController _minPurchaseController;
  late TextEditingController _promoCodeController;
  late DiscountType _type;
  late DateTime _validFrom;
  late DateTime _validUntil;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.discount;
    _nameController = TextEditingController(text: d?.name ?? '');
    _valueController = TextEditingController(text: d?.value.toString() ?? '');
    _minPurchaseController =
        TextEditingController(text: d?.minPurchase?.toString() ?? '');
    _promoCodeController = TextEditingController(text: d?.promoCode ?? '');
    _type = d?.type ?? DiscountType.percentage;
    _validFrom = d?.validFrom ?? DateTime.now();
    _validUntil = d?.validUntil ?? DateTime.now().add(const Duration(days: 30));
    _isActive = d?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _minPurchaseController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.discount != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit : Icons.add_circle,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Diskon' : 'Tambah Diskon'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Diskon *',
                    prefixIcon: Icon(Icons.label),
                    hintText: 'Contoh: Diskon Akhir Tahun',
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DiscountType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Tipe Diskon',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DiscountType.percentage,
                            child: Text('Persentase (%)'),
                          ),
                          DropdownMenuItem(
                            value: DiscountType.fixed,
                            child: Text('Nominal (Rp)'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        decoration: InputDecoration(
                          labelText: 'Nilai *',
                          prefixIcon: Icon(
                            _type == DiscountType.percentage
                                ? Icons.percent
                                : Icons.attach_money,
                          ),
                          suffixText:
                              _type == DiscountType.percentage ? '%' : 'Rp',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) {
                            return 'Nilai tidak valid';
                          }
                          if (_type == DiscountType.percentage && val > 100) {
                            return 'Max 100%';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minPurchaseController,
                  decoration: const InputDecoration(
                    labelText: 'Minimal Pembelian (opsional)',
                    prefixIcon: Icon(Icons.shopping_cart),
                    hintText: 'Kosongkan jika tidak ada minimum',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _promoCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Promo (opsional)',
                    prefixIcon: Icon(Icons.confirmation_number),
                    hintText: 'Contoh: NEWYEAR2024',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Mulai Berlaku',
                        date: _validFrom,
                        onChanged: (d) => setState(() => _validFrom = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Berakhir',
                        date: _validUntil,
                        onChanged: (d) => setState(() => _validUntil = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  subtitle: const Text('Diskon dapat digunakan'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate date range
    if (_validUntil.isBefore(_validFrom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal berakhir harus setelah tanggal mulai'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate date is not in the past for new discounts
    if (widget.discount == null) {
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      if (_validUntil.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal berakhir tidak boleh di masa lalu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) throw Exception('User tidak terautentikasi');

      // Validate role - only owner/manager can create/edit discounts
      if (user.role != UserRole.owner && user.role != UserRole.manager) {
        throw Exception('Anda tidak memiliki akses untuk mengelola diskon');
      }

      final discount = Discount(
        id: widget.discount?.id ?? const Uuid().v4(),
        tenantId: user.tenantId,
        name: _nameController.text.trim(),
        type: _type,
        value: double.parse(_valueController.text),
        minPurchase: _minPurchaseController.text.isNotEmpty
            ? double.parse(_minPurchaseController.text)
            : null,
        promoCode: _promoCodeController.text.trim().isNotEmpty
            ? _promoCodeController.text.trim().toUpperCase()
            : null,
        validFrom: _validFrom,
        validUntil: _validUntil,
        isActive: _isActive,
        createdAt: widget.discount?.createdAt ?? DateTime.now(),
      );

      final provider = ref.read(discountListProvider.notifier).provider;
      final result = widget.discount != null
          ? await provider.updateDiscount(discount)
          : await provider.createDiscount(discount);

      if (mounted) {
        if (result.success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.discount != null
                  ? 'Diskon berhasil diperbarui'
                  : 'Diskon berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Gagal menyimpan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/// Date picker field widget
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(date)),
      ),
    );
  }
}
