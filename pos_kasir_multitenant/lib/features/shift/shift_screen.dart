import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/shift.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_provider.dart';
import 'shift_provider.dart';

/// Shift management screen
/// Requirements 13.1, 13.2, 13.3, 13.4: Shift management UI
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShiftAsync = ref.watch(activeShiftProvider);
    final shiftHistoryAsync = ref.watch(shiftHistoryProvider);
    final isOfflineCapable = ref.watch(isOfflineCapableProvider);
    final authState = ref.watch(authProvider);

    // Check if user is logged in
    if (authState.user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('⏰ Manajemen Shift'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Silakan login untuk mengakses shift',
                  style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

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
            const Text('⏰ Manajemen Shift'),
            const SizedBox(width: 8),
            // Offline indicator
            if (isOfflineCapable)
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
            onPressed: () {
              ref.read(activeShiftProvider.notifier).loadActiveShift();
              ref.read(shiftHistoryProvider.notifier).loadShiftHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Shift Card with error handling
          activeShiftAsync.when(
            data: (shift) => _ActiveShiftCard(shift: shift),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorCard(
              message: 'Gagal memuat shift aktif: $e',
              onRetry: () => ref.read(activeShiftProvider.notifier).retry(),
            ),
          ),
          // Shift Statistics (only when shift is active)
          activeShiftAsync.when(
            data: (shift) => shift != null
                ? _ShiftStatsCard(shift: shift)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Shift History with error handling
          Expanded(
            child: shiftHistoryAsync.when(
              data: (shifts) => _ShiftHistoryList(shifts: shifts),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: 'Gagal memuat riwayat shift: $e',
                onRetry: () => ref.read(shiftHistoryProvider.notifier).retry(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error card widget for inline errors
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppCard(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view for full-screen errors
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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
}

/// Shift statistics card showing transaction info during active shift
class _ShiftStatsCard extends ConsumerWidget {
  final Shift shift;

  const _ShiftStatsCard({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(shiftStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final transactionCount = stats['transactionCount'] as int;
        final totalCashSales = stats['totalCashSales'] as double;
        final totalNonCashSales = stats['totalNonCashSales'] as double;
        final totalSales = totalCashSales + totalNonCashSales;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.receipt_long,
                  label: 'Transaksi',
                  value: '$transactionCount',
                  color: Colors.blue,
                ),
                _StatItem(
                  icon: Icons.payments,
                  label: 'Kas Tunai',
                  value: _formatCompact(totalCashSales),
                  color: Colors.green,
                ),
                _StatItem(
                  icon: Icons.credit_card,
                  label: 'Non-Tunai',
                  value: _formatCompact(totalNonCashSales),
                  color: Colors.purple,
                ),
                _StatItem(
                  icon: Icons.trending_up,
                  label: 'Total',
                  value: _formatCompact(totalSales),
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatCompact(double amount) =>
      NumberFormat.compactCurrency(locale: 'id', symbol: 'Rp', decimalDigits: 0)
          .format(amount);
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }
}

/// Active shift card widget
class _ActiveShiftCard extends ConsumerWidget {
  final Shift? shift;

  const _ActiveShiftCard({this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shift == null) {
      return _NoActiveShiftCard(
        onStartShift: () => _showStartShiftDialog(context, ref),
      );
    }

    return _CurrentShiftCard(
      shift: shift!,
      onEndShift: () => _showEndShiftDialog(context, ref, shift!),
    );
  }

  void _showStartShiftDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool isLoading = false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.play_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Mulai Shift'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan jumlah kas awal untuk memulai shift.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Kas Awal (Rp)',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                enabled: !isLoading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isLoading
                  ? null
                  : () async {
                      final openingCash = double.tryParse(controller.text) ?? 0;
                      if (openingCash < 0) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Kas awal tidak boleh negatif'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (openingCash > 999999999) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Kas awal melebihi batas maksimal'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(activeShiftProvider.notifier)
                            .startShift(openingCash);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Shift berhasil dimulai'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() => isLoading = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Gagal memulai shift: $e'),
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
                  : const Text('Mulai Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndShiftDialog(BuildContext context, WidgetRef ref, Shift shift) {
    final cashController = TextEditingController();
    final noteController = TextEditingController();
    bool isLoading = false;
    double? expectedCash;
    int? transactionCount;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          // Load expected cash and transaction count once
          if (expectedCash == null) {
            ref
                .read(activeShiftProvider.notifier)
                .calculateExpectedCash(shift)
                .then((value) {
              if (dialogContext.mounted) {
                setState(() => expectedCash = value);
              }
            });
            ref
                .read(activeShiftProvider.notifier)
                .getTransactionCount()
                .then((count) {
              if (dialogContext.mounted) {
                setState(() => transactionCount = count);
              }
            });
          }

          final displayExpectedCash = expectedCash ?? shift.openingCash;
          final duration = DateTime.now().difference(shift.startTime);
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.stop_circle, color: Colors.orange),
                SizedBox(width: 8),
                Text('Akhiri Shift'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shift summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Durasi Shift:'),
                            Text(
                              '${hours}j ${minutes}m',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jumlah Transaksi:'),
                            transactionCount == null
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    '$transactionCount',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cash info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kas Awal:'),
                            Text(
                              _formatCurrency(shift.openingCash),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kas Diharapkan:'),
                            expectedCash == null
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _formatCurrency(displayExpectedCash),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cashController,
                    decoration: const InputDecoration(
                      labelText: 'Kas Aktual (Rp)',
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'Hitung uang tunai di laci kas',
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (wajib jika ada selisih)',
                      prefixIcon: Icon(Icons.note),
                      helperText: 'Jelaskan penyebab selisih jika ada',
                    ),
                    maxLines: 2,
                    enabled: !isLoading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: isLoading
                    ? null
                    : () async {
                        final closingCash =
                            double.tryParse(cashController.text) ?? 0;
                        final note = noteController.text.trim();

                        if (closingCash < 0) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Kas aktual tidak boleh negatif'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (closingCash > 999999999) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Kas aktual melebihi batas maksimal'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Check if variance exists and note is required
                        final variance = closingCash - displayExpectedCash;
                        if (variance.abs() > 0.01 && note.isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Catatan wajib diisi jika ada selisih kas'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // Show confirmation dialog
                        final confirmed = await _showEndShiftConfirmation(
                          dialogContext,
                          closingCash,
                          displayExpectedCash,
                          variance,
                        );

                        if (!confirmed) return;
                        if (!dialogContext.mounted) return;

                        setState(() => isLoading = true);
                        try {
                          await ref.read(activeShiftProvider.notifier).endShift(
                                closingCash,
                                varianceNote: note.isNotEmpty ? note : null,
                              );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Shift berhasil diakhiri'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setState(() => isLoading = false);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengakhiri shift: $e'),
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
                    : const Text('Akhiri Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _showEndShiftConfirmation(
    BuildContext context,
    double closingCash,
    double expectedCash,
    double variance,
  ) async {
    final hasVariance = variance.abs() > 0.01;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  hasVariance ? Icons.warning_amber : Icons.check_circle,
                  color: hasVariance ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                const Text('Konfirmasi'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVariance
                      ? 'Terdapat selisih kas sebesar ${_formatCurrency(variance.abs())}.'
                      : 'Kas sesuai dengan yang diharapkan.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda yakin ingin mengakhiri shift?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasVariance ? Colors.orange : Colors.green,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya, Akhiri'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

/// No active shift card
class _NoActiveShiftCard extends StatelessWidget {
  final VoidCallback onStartShift;

  const _NoActiveShiftCard({required this.onStartShift});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppCard(
        child: Column(
          children: [
            const Icon(Icons.access_time_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Tidak Ada Shift Aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai shift untuk mencatat transaksi',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onStartShift,
              icon: const Icon(Icons.play_circle),
              label: const Text('Mulai Shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current active shift card
class _CurrentShiftCard extends StatelessWidget {
  final Shift shift;
  final VoidCallback onEndShift;

  const _CurrentShiftCard({required this.shift, required this.onEndShift});

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(shift.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.timer, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shift Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mulai: ${DateFormat('HH:mm').format(shift.startTime)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${hours}j ${minutes}m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Durasi',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Kas Awal',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _formatCurrency(shift.openingCash),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onEndShift,
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Akhiri Shift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

/// Shift history list
class _ShiftHistoryList extends StatelessWidget {
  final List<Shift> shifts;

  const _ShiftHistoryList({required this.shifts});

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat shift',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Riwayat Shift',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shifts.length,
            itemBuilder: (context, index) =>
                _ShiftHistoryCard(shift: shifts[index]),
          ),
        ),
      ],
    );
  }
}

/// Shift history card
class _ShiftHistoryCard extends StatelessWidget {
  final Shift shift;

  const _ShiftHistoryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final hasVariance = shift.variance != null && shift.variance!.abs() > 0.01;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(shift.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(shift.status),
                  color: _getStatusColor(shift.status),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(shift.startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(shift.startTime)} - ${shift.endTime != null ? DateFormat('HH:mm').format(shift.endTime!) : 'Aktif'}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(shift.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(shift.status),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(shift.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (shift.status != ShiftStatus.active) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoColumn(
                    label: 'Kas Awal',
                    value: _formatCurrency(shift.openingCash)),
                _InfoColumn(
                  label: 'Kas Akhir',
                  value: _formatCurrency(shift.closingCash ?? 0),
                ),
                _InfoColumn(
                  label: 'Selisih',
                  value: _formatCurrency(shift.variance ?? 0),
                  valueColor: hasVariance ? Colors.red : Colors.green,
                ),
              ],
            ),
            if (hasVariance && shift.varianceNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shift.varianceNote!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.active:
        return Colors.green;
      case ShiftStatus.closed:
        return Colors.blue;
      case ShiftStatus.flagged:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.active:
        return Icons.play_circle;
      case ShiftStatus.closed:
        return Icons.check_circle;
      case ShiftStatus.flagged:
        return Icons.warning;
    }
  }

  String _getStatusLabel(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.active:
        return 'Aktif';
      case ShiftStatus.closed:
        return 'Selesai';
      case ShiftStatus.flagged:
        return 'Ada Selisih';
    }
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

/// Info column widget
class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
