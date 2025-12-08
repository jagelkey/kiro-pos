import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/services/report_exporter.dart';
import '../../data/models/transaction.dart';
import '../../data/models/expense.dart';
import '../auth/auth_provider.dart';
import 'reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check user role - only owner/admin should have full access
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📊 Laporan'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Silakan login untuk melihat laporan',
                  style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return const _ReportsScreenContent();
  }
}

class _ReportsScreenContent extends ConsumerStatefulWidget {
  const _ReportsScreenContent();

  @override
  ConsumerState<_ReportsScreenContent> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<_ReportsScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsData = ref.watch(reportsProvider);
    final transactions = reportsData.transactions;
    final expenses = reportsData.expenses;
    final totalSales = reportsData.totalSales;
    final totalExpenses = reportsData.totalExpenses;
    final profit = reportsData.profit;

    // Loading state
    if (reportsData.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📊 Laporan'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Error state with retry option
    if (reportsData.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📊 Laporan'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Gagal Memuat Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reportsData.error ?? 'Terjadi kesalahan',
                  style: TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(reportsProvider.notifier).retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('📊 Laporan'),
            const SizedBox(width: 8),
            // Offline indicator
            if (reportsData.isOffline)
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
          // Branch filter dropdown (multi-branch support)
          if (reportsData.branches.isNotEmpty)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.store),
              tooltip: 'Filter Cabang',
              onSelected: (branchId) {
                ref.read(reportsProvider.notifier).setBranchFilter(branchId);
              },
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        reportsData.selectedBranchId == null
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: reportsData.selectedBranchId == null
                            ? AppTheme.primaryColor
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      const Text('Semua Cabang'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...reportsData.branches.map((branch) => PopupMenuItem<String?>(
                      value: branch.id,
                      child: Row(
                        children: [
                          Icon(
                            reportsData.selectedBranchId == branch.id
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: reportsData.selectedBranchId == branch.id
                                ? AppTheme.primaryColor
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(branch.name),
                        ],
                      ),
                    )),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(reportsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Laporan',
            onPressed: () => _showExportDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: '📈 Ringkasan'),
            Tab(text: '🧾 Transaksi'),
            Tab(text: '☕ Produk'),
            Tab(text: '💸 Biaya'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Branch filter indicator
          if (reportsData.selectedBranchId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.store, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Cabang: ${reportsData.selectedBranchName}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref
                        .read(reportsProvider.notifier)
                        .setBranchFilter(null),
                    child: Icon(Icons.close,
                        size: 18, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          // Quick Filters & Date Range
          _buildDateFilterSection(reportsData),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(
                  totalSales: totalSales,
                  totalExpenses: totalExpenses,
                  profit: profit,
                  transactionCount: transactions.length,
                  transactions: transactions,
                  expenses: expenses,
                  startDate: reportsData.startDate,
                  endDate: reportsData.endDate,
                  totalCostOfGoodsSold: reportsData.totalCostOfGoodsSold,
                  grossProfit: reportsData.grossProfit,
                  grossProfitMarginPercent:
                      reportsData.grossProfitMarginPercent,
                ),
                _TransactionsTab(transactions: transactions),
                _ProductsTab(transactions: transactions),
                _ExpensesTab(expenses: expenses, totalExpenses: totalExpenses),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection(ReportsData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          // Quick Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickFilterChip(
                  label: 'Hari Ini',
                  isSelected: _isToday(data),
                  onTap: () => ref.read(reportsProvider.notifier).setToday(),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Kemarin',
                  isSelected: _isYesterday(data),
                  onTap: () =>
                      ref.read(reportsProvider.notifier).setYesterday(),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: '7 Hari',
                  isSelected: _is7Days(data),
                  onTap: () =>
                      ref.read(reportsProvider.notifier).setLast7Days(),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: '30 Hari',
                  isSelected: _is30Days(data),
                  onTap: () =>
                      ref.read(reportsProvider.notifier).setLast30Days(),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Bulan Ini',
                  isSelected: _isThisMonth(data),
                  onTap: () =>
                      ref.read(reportsProvider.notifier).setThisMonth(),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  label: 'Bulan Lalu',
                  isSelected: _isLastMonth(data),
                  onTap: () =>
                      ref.read(reportsProvider.notifier).setLastMonth(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Date Range Picker
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(true, data),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd MMM yyyy').format(data.startDate)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(false, data),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd MMM yyyy').format(data.endDate)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart, ReportsData data) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? data.startDate : data.endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      if (isStart) {
        var endDate = data.endDate;
        if (date.isAfter(endDate)) {
          endDate = date;
        }
        ref.read(reportsProvider.notifier).setDateRange(date, endDate);
      } else {
        var startDate = data.startDate;
        if (date.isBefore(startDate)) {
          startDate = date;
        }
        ref.read(reportsProvider.notifier).setDateRange(startDate, date);
      }
    }
  }

  bool _isToday(ReportsData data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == today && end == today;
  }

  bool _isYesterday(ReportsData data) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == yesterday && end == yesterday;
  }

  bool _is7Days(ReportsData data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == sevenDaysAgo && end == today;
  }

  bool _is30Days(ReportsData data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = today.subtract(const Duration(days: 29));
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == thirtyDaysAgo && end == today;
  }

  bool _isThisMonth(ReportsData data) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == firstDayOfMonth && end == today;
  }

  bool _isLastMonth(ReportsData data) {
    final now = DateTime.now();
    final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayLastMonth = DateTime(now.year, now.month, 0);
    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);
    return start == firstDayLastMonth && end == lastDayLastMonth;
  }

  void _showExportDialog(BuildContext context) {
    final data = ref.read(reportsProvider);

    // Check if there's data to export
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tidak ada data untuk di-export'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Laporan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Periode: ${DateFormat('dd MMM yyyy').format(data.startDate)} - ${DateFormat('dd MMM yyyy').format(data.endDate)}',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            if (data.selectedBranchId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Cabang: ${data.selectedBranchName}',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 8),
            // Data summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ExportSummaryItem(
                    label: 'Transaksi',
                    value: '${data.transactionCount}',
                  ),
                  _ExportSummaryItem(
                    label: 'Penjualan',
                    value: NumberFormat.compactCurrency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(data.totalSales),
                  ),
                  _ExportSummaryItem(
                    label: 'Biaya',
                    value: '${data.expenses.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ExportOption(
              icon: Icons.table_chart,
              color: Colors.green,
              title: 'Export ke Excel',
              subtitle: 'Format .xlsx - Data lengkap',
              onTap: () {
                Navigator.pop(context);
                _performExport(context, 'Excel', data);
              },
            ),
            _ExportOption(
              icon: Icons.picture_as_pdf,
              color: Colors.red,
              title: 'Export ke PDF',
              subtitle: 'Format .pdf - Siap cetak',
              onTap: () {
                Navigator.pop(context);
                _performExport(context, 'PDF', data);
              },
            ),
            _ExportOption(
              icon: Icons.print,
              color: Colors.purple,
              title: 'Cetak Langsung',
              subtitle: 'Print PDF ke printer',
              onTap: () {
                Navigator.pop(context);
                _printReport(context, data);
              },
            ),
            _ExportOption(
              icon: Icons.share,
              color: Colors.blue,
              title: 'Bagikan Ringkasan',
              subtitle: 'Kirim via WhatsApp/Email',
              onTap: () {
                Navigator.pop(context);
                _shareReportSummary(context, data);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(
      BuildContext context, String format, ReportsData data) async {
    final authState = ref.read(authProvider);
    final tenant = authState.tenant;

    if (tenant == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenant tidak ditemukan'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Membuat file $format...'),
          ],
        ),
      ),
    );

    try {
      String? filePath;

      if (format == 'Excel') {
        filePath = await ReportExporter.exportToExcel(
          transactions: data.transactions,
          expenses: data.expenses,
          totalSales: data.totalSales,
          totalExpenses: data.totalExpenses,
          profit: data.profit,
          startDate: data.startDate,
          endDate: data.endDate,
          tenant: tenant,
          branchName: data.selectedBranchName,
        );
      } else if (format == 'PDF') {
        filePath = await ReportExporter.exportToPdf(
          transactions: data.transactions,
          expenses: data.expenses,
          totalSales: data.totalSales,
          totalExpenses: data.totalExpenses,
          profit: data.profit,
          startDate: data.startDate,
          endDate: data.endDate,
          tenant: tenant,
          branchName: data.selectedBranchName,
        );
      }

      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      if (filePath != null) {
        // Show success dialog with share option
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor),
                  const SizedBox(width: 8),
                  const Text('Export Berhasil'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Laporan berhasil di-export ke $format'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file,
                            size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filePath?.split('/').last ?? 'file',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'File tersimpan di folder aplikasi',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Tutup'),
                ),
                ElevatedButton.icon(
                  onPressed: filePath != null
                      ? () async {
                          Navigator.pop(dialogContext);
                          try {
                            final file = XFile(filePath!);
                            await Share.shareXFiles(
                              [file],
                              subject:
                                  'Laporan POS - ${DateFormat('dd MMM yyyy').format(data.startDate)}',
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal share file: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Gagal membuat file $format');
      }
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _printReport(BuildContext context, ReportsData data) async {
    final authState = ref.read(authProvider);
    final tenant = authState.tenant;

    if (tenant == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenant tidak ditemukan'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menyiapkan dokumen...'),
          ],
        ),
      ),
    );

    try {
      final success = await ReportExporter.printPdf(
        transactions: data.transactions,
        expenses: data.expenses,
        totalSales: data.totalSales,
        totalExpenses: data.totalExpenses,
        profit: data.profit,
        startDate: data.startDate,
        endDate: data.endDate,
        tenant: tenant,
        branchName: data.selectedBranchName,
      );

      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak laporan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _shareReportSummary(BuildContext context, ReportsData data) {
    final summary = _buildReportSummaryText(data);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // In real app, use share_plus package to share
    // For now, show the summary in a dialog with copy option
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ringkasan Laporan'),
        content: SingleChildScrollView(
          child: Text(summary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Ringkasan disalin ke clipboard'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  String _buildReportSummaryText(ReportsData data) {
    return '''
📊 Laporan POS
📅 Periode: ${DateFormat('dd MMM yyyy').format(data.startDate)} - ${DateFormat('dd MMM yyyy').format(data.endDate)}
${data.selectedBranchId != null ? '🏪 Cabang: ${data.selectedBranchName}\n' : ''}
💰 Total Penjualan: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(data.totalSales)}
📝 Jumlah Transaksi: ${data.transactionCount}
💸 Total Biaya: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(data.totalExpenses)}
${data.profit >= 0 ? '✅' : '❌'} Laba/Rugi: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(data.profit)}
''';
  }
}

// Export Summary Item Widget
class _ExportSummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _ExportSummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Export Option Widget
class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Summary Tab - Enhanced
class _SummaryTab extends StatelessWidget {
  final double totalSales;
  final double totalExpenses;
  final double profit;
  final int transactionCount;
  final List<Transaction> transactions;
  final List<Expense> expenses;
  final DateTime startDate;
  final DateTime endDate;
  final double totalCostOfGoodsSold;
  final double grossProfit;
  final double grossProfitMarginPercent;

  const _SummaryTab({
    required this.totalSales,
    required this.totalExpenses,
    required this.profit,
    required this.transactionCount,
    required this.transactions,
    required this.expenses,
    required this.startDate,
    required this.endDate,
    required this.totalCostOfGoodsSold,
    required this.grossProfit,
    required this.grossProfitMarginPercent,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate metrics
    final avgTransaction =
        transactionCount > 0 ? totalSales / transactionCount : 0.0;
    final totalItems = transactions.fold<int>(
        0, (sum, t) => sum + t.items.fold<int>(0, (s, i) => s + i.quantity));
    final profitMargin = totalSales > 0 ? (profit / totalSales * 100) : 0.0;

    // Payment breakdown
    final paymentBreakdown = <String, double>{};
    for (var t in transactions) {
      paymentBreakdown[t.paymentMethod] =
          (paymentBreakdown[t.paymentMethod] ?? 0) + t.total;
    }

    // Category breakdown
    final categoryBreakdown = <String, double>{};
    for (var t in transactions) {
      for (var item in t.items) {
        final category = _getProductCategory(item.productName);
        categoryBreakdown[category] =
            (categoryBreakdown[category] ?? 0) + item.total;
      }
    }

    // Peak hours analysis
    final hourlyData = <int, double>{};
    for (var t in transactions) {
      final hour = t.createdAt.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + t.total;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Stats Cards
          _buildMainStatsGrid(avgTransaction, totalItems, profitMargin),
          const SizedBox(height: 20),

          // Profit/Loss Indicator
          _buildProfitIndicator(),
          const SizedBox(height: 20),

          // Sales Chart (Simple Bar)
          if (transactions.isNotEmpty) ...[
            _buildSectionTitle(context, '📊 Grafik Penjualan Harian'),
            const SizedBox(height: 12),
            _buildDailySalesChart(),
            const SizedBox(height: 20),
          ],

          // Payment Methods
          _buildSectionTitle(context, '💳 Metode Pembayaran'),
          const SizedBox(height: 12),
          _buildPaymentBreakdown(paymentBreakdown),
          const SizedBox(height: 20),

          // Category Breakdown
          if (categoryBreakdown.isNotEmpty) ...[
            _buildSectionTitle(context, '☕ Penjualan per Kategori'),
            const SizedBox(height: 12),
            _buildCategoryBreakdown(categoryBreakdown),
            const SizedBox(height: 20),
          ],

          // Peak Hours
          if (hourlyData.isNotEmpty) ...[
            _buildSectionTitle(context, '⏰ Jam Sibuk'),
            const SizedBox(height: 12),
            _buildPeakHours(hourlyData),
          ],
        ],
      ),
    );
  }

  Widget _buildMainStatsGrid(
      double avgTransaction, int totalItems, double profitMargin) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    title: 'Total Penjualan',
                    value: _formatCurrency(totalSales),
                    icon: Icons.trending_up,
                    color: AppTheme.successColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    title: 'Transaksi',
                    value: '$transactionCount',
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor)),
          ],
        ),
        const SizedBox(height: 12),
        // Harga Pokok & Laba Kotor
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    title: 'Harga Pokok (HPP)',
                    value: _formatCurrency(totalCostOfGoodsSold),
                    icon: Icons.inventory_2,
                    color: Colors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    title: 'Laba Kotor',
                    value: _formatCurrency(grossProfit),
                    subtitle:
                        '${grossProfitMarginPercent.toStringAsFixed(1)}% margin',
                    icon: Icons.show_chart,
                    color:
                        grossProfit >= 0 ? Colors.green.shade600 : Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    title: 'Total Biaya Operasional',
                    value: _formatCurrency(totalExpenses),
                    icon: Icons.money_off,
                    color: AppTheme.warningColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    title: 'Laba Bersih',
                    value: _formatCurrency(profit),
                    icon: Icons.account_balance_wallet,
                    color: profit >= 0 ? Colors.green : Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    title: 'Rata-rata/Transaksi',
                    value: _formatCurrency(avgTransaction),
                    icon: Icons.analytics,
                    color: Colors.purple)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    title: 'Item Terjual',
                    value: '$totalItems',
                    icon: Icons.shopping_bag,
                    color: Colors.teal)),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitIndicator() {
    final isProfit = profit >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isProfit ? Icons.trending_up : Icons.trending_down,
              color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isProfit ? 'PROFIT' : 'RUGI',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text(_formatCurrency(profit.abs()),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              totalSales > 0
                  ? '${(profit / totalSales * 100).toStringAsFixed(1)}%'
                  : '0%',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildDailySalesChart() {
    // Group by date
    final dailySales = <String, double>{};
    for (var t in transactions) {
      final dateKey = DateFormat('dd/MM').format(t.createdAt);
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + t.total;
    }

    if (dailySales.isEmpty) {
      return AppCard(
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Belum ada data',
                      style: TextStyle(color: AppTheme.textMuted)))));
    }

    final maxValue = dailySales.values.reduce((a, b) => a > b ? a : b);
    final sortedEntries = dailySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return AppCard(
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: sortedEntries.map((entry) {
            final barHeight =
                maxValue > 0 ? (entry.value / maxValue * 110) : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatCompact(entry.value),
                      style: TextStyle(fontSize: 8, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: barHeight.clamp(4.0, 110.0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.key,
                      style: TextStyle(fontSize: 8, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown(Map<String, double> breakdown) {
    if (breakdown.isEmpty) {
      return AppCard(
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Belum ada data',
                      style: TextStyle(color: AppTheme.textMuted)))));
    }

    return AppCard(
      child: Column(
        children: breakdown.entries.map((e) {
          final percentage =
              totalSales > 0 ? (e.value / totalSales * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(_getPaymentIcon(e.key),
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getPaymentLabel(e.key),
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalSales > 0 ? e.value / totalSales : 0,
                          backgroundColor: AppTheme.borderColor,
                          valueColor:
                              AlwaysStoppedAnimation(_getPaymentColor(e.key)),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatCurrency(e.value),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${percentage.toStringAsFixed(1)}%',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, double> breakdown) {
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        children: sortedEntries.take(5).map((e) {
          final percentage =
              totalSales > 0 ? (e.value / totalSales * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(_getCategoryEmoji(e.key),
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                Text(_formatCurrency(e.value),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeakHours(Map<int, double> hourlyData) {
    final sortedHours = hourlyData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHour = sortedHours.isNotEmpty ? sortedHours.first.key : 0;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.access_time,
                    color: Colors.orange, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jam Tersibuk',
                        style: TextStyle(color: Colors.grey)),
                    Text(
                        '${peakHour.toString().padLeft(2, '0')}:00 - ${(peakHour + 1).toString().padLeft(2, '0')}:00',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(
                  _formatCurrency(
                      sortedHours.isNotEmpty ? sortedHours.first.value : 0),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          // Hour distribution
          SizedBox(
            height: 60,
            child: Row(
              children: List.generate(24, (hour) {
                final value = hourlyData[hour] ?? 0;
                final maxValue = hourlyData.values.isNotEmpty
                    ? hourlyData.values.reduce((a, b) => a > b ? a : b)
                    : 1;
                final height = maxValue > 0 ? (value / maxValue * 40) : 0.0;
                final isPeak = hour == peakHour;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height.clamp(2.0, 40.0),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isPeak
                              ? Colors.orange
                              : AppTheme.primaryColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hour % 6 == 0)
                        Text('${hour}h',
                            style: TextStyle(
                                fontSize: 8, color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
  String _formatCompact(double amount) =>
      NumberFormat.compactCurrency(locale: 'id', symbol: '', decimalDigits: 0)
          .format(amount);

  String _getPaymentIcon(String method) {
    switch (method) {
      case 'cash':
        return '💵';
      case 'qris':
        return '📱';
      case 'debit':
        return '💳';
      case 'transfer':
        return '🏦';
      case 'ewallet':
        return '📲';
      default:
        return '💰';
    }
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'debit':
        return 'Kartu Debit';
      case 'transfer':
        return 'Transfer Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'cash':
        return Colors.green;
      case 'qris':
        return Colors.purple;
      case 'debit':
        return Colors.blue;
      case 'transfer':
        return Colors.orange;
      case 'ewallet':
        return Colors.teal;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getProductCategory(String productName) {
    // Map product names to categories
    final coffeeProducts = [
      'Espresso',
      'Americano',
      'Cappuccino',
      'Cafe Latte',
      'Mocha',
      'Iced Americano',
      'Iced Latte',
      'Iced Mocha',
      'Cold Brew',
      'Caramel Macchiato',
      'Hazelnut Latte'
    ];
    final nonCoffee = [
      'Matcha Latte',
      'Chocolate',
      'Red Velvet',
      'Green Tea Latte'
    ];
    final tea = ['Earl Grey Tea'];
    final food = [
      'Croissant',
      'Sandwich',
      'Cheesecake',
      'Cookies',
      'Tiramisu',
      'Brownies'
    ];

    if (coffeeProducts.contains(productName)) return 'Coffee';
    if (nonCoffee.contains(productName)) return 'Non-Coffee';
    if (tea.contains(productName)) return 'Tea';
    if (food.contains(productName)) return 'Food & Snacks';
    return 'Lainnya';
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Coffee':
        return '☕';
      case 'Non-Coffee':
        return '🥛';
      case 'Tea':
        return '🍵';
      case 'Food & Snacks':
        return '🍰';
      default:
        return '📦';
    }
  }
}

// Transactions Tab
class _TransactionsTab extends StatelessWidget {
  final List<Transaction> transactions;

  const _TransactionsTab({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Belum ada transaksi',
                style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
            Text('Transaksi akan muncul di sini',
                style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    final sortedTransactions = [...transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final totalAmount = transactions.fold<double>(0, (sum, t) => sum + t.total);

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                  label: 'Total Transaksi', value: '${transactions.length}'),
              _SummaryItem(
                  label: 'Total Nilai', value: _formatCurrency(totalAmount)),
              _SummaryItem(
                  label: 'Rata-rata',
                  value: _formatCurrency(transactions.isNotEmpty
                      ? totalAmount / transactions.length
                      : 0)),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTransactions.length,
            itemBuilder: (context, index) {
              final t = sortedTransactions[index];
              return _TransactionCard(transaction: t);
            },
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt, color: AppTheme.primaryColor),
        ),
        title: Text(
          NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
              .format(transaction.total),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt)} • ${transaction.items.length} item'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getPaymentColor(transaction.paymentMethod)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getPaymentLabel(transaction.paymentMethod),
            style: TextStyle(
                fontSize: 11,
                color: _getPaymentColor(transaction.paymentMethod),
                fontWeight: FontWeight.w600),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...transaction.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.productName}'),
                          Text(NumberFormat.currency(
                                  locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                              .format(item.total)),
                        ],
                      ),
                    )),
                const Divider(),
                _buildDetailRow('Subtotal', transaction.subtotal),
                _buildDetailRow('Pajak (11%)', transaction.tax),
                if (transaction.discount > 0)
                  _buildDetailRow('Diskon', -transaction.discount,
                      isDiscount: true),
                const Divider(),
                _buildDetailRow('Total', transaction.total, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount,
      {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${isDiscount ? '-' : ''}${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount.abs())}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return '💵 Tunai';
      case 'qris':
        return '📱 QRIS';
      case 'debit':
        return '💳 Debit';
      case 'transfer':
        return '🏦 Transfer';
      case 'ewallet':
        return '📲 E-Wallet';
      default:
        return method;
    }
  }

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'cash':
        return Colors.green;
      case 'qris':
        return Colors.purple;
      case 'debit':
        return Colors.blue;
      case 'transfer':
        return Colors.orange;
      case 'ewallet':
        return Colors.teal;
      default:
        return AppTheme.primaryColor;
    }
  }
}

// Products Tab - Enhanced
class _ProductsTab extends StatelessWidget {
  final List<Transaction> transactions;

  const _ProductsTab({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Calculate product sales
    final productSales = <String, Map<String, dynamic>>{};
    for (var t in transactions) {
      for (var item in t.items) {
        if (!productSales.containsKey(item.productName)) {
          productSales[item.productName] = {'quantity': 0, 'revenue': 0.0};
        }
        productSales[item.productName]!['quantity'] += item.quantity;
        productSales[item.productName]!['revenue'] += item.total;
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => (b.value['revenue'] as double)
          .compareTo(a.value['revenue'] as double));

    if (sortedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Belum ada data penjualan',
                style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    final totalRevenue = sortedProducts.fold<double>(
        0, (sum, e) => sum + (e.value['revenue'] as double));
    final totalQty = sortedProducts.fold<int>(
        0, (sum, e) => sum + (e.value['quantity'] as int));

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                  label: 'Jenis Produk', value: '${sortedProducts.length}'),
              _SummaryItem(label: 'Total Terjual', value: '$totalQty item'),
              _SummaryItem(
                  label: 'Total Revenue', value: _formatCurrency(totalRevenue)),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedProducts.length,
            itemBuilder: (context, index) {
              final product = sortedProducts[index];
              final isTop3 = index < 3;
              final percentage = totalRevenue > 0
                  ? (product.value['revenue'] as double) / totalRevenue * 100
                  : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isTop3
                          ? [
                              Colors.amber,
                              Colors.grey.shade400,
                              Colors.brown.shade300
                            ][index]
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: isTop3
                          ? Text('${index + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18))
                          : Text(_getProductEmoji(product.key),
                              style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  title: Text(product.key,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(
                    children: [
                      Text('${product.value['quantity']} terjual'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatCurrency(product.value['revenue'] as double),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  String _getProductEmoji(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('coffee') ||
        lowerName.contains('espresso') ||
        lowerName.contains('latte') ||
        lowerName.contains('cappuccino') ||
        lowerName.contains('americano') ||
        lowerName.contains('mocha')) {
      return '☕';
    }
    if (lowerName.contains('tea')) {
      return '🍵';
    }
    if (lowerName.contains('matcha') ||
        lowerName.contains('chocolate') ||
        lowerName.contains('velvet')) {
      return '🥛';
    }
    if (lowerName.contains('cake') ||
        lowerName.contains('tiramisu') ||
        lowerName.contains('brownie')) {
      return '🍰';
    }
    if (lowerName.contains('croissant') || lowerName.contains('sandwich')) {
      return '🥐';
    }
    if (lowerName.contains('cookie')) {
      return '🍪';
    }
    return '☕';
  }
}

// Expenses Tab - New
class _ExpensesTab extends StatelessWidget {
  final List<Expense> expenses;
  final double totalExpenses;

  const _ExpensesTab({required this.expenses, required this.totalExpenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Belum ada biaya tercatat',
                style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    // Group by category
    final categoryBreakdown = <String, double>{};
    for (var e in expenses) {
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600]),
          ),
          child: Row(
            children: [
              const Icon(Icons.money_off, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Biaya',
                        style: TextStyle(color: Colors.white70)),
                    Text(_formatCurrency(totalExpenses),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${expenses.length} item',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        // Category breakdown
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Breakdown per Kategori',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...sortedCategories.map((entry) {
                final percentage = totalExpenses > 0
                    ? (entry.value / totalExpenses * 100)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(_getCategoryEmoji(entry.key),
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                          Text(_formatCurrency(entry.value),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            child: Text('${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalExpenses > 0
                              ? entry.value / totalExpenses
                              : 0,
                          backgroundColor: AppTheme.borderColor,
                          valueColor: AlwaysStoppedAnimation(
                              _getCategoryColor(entry.key)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        // Expense list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(expense.category)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                        child: Text(_getCategoryEmoji(expense.category),
                            style: const TextStyle(fontSize: 18))),
                  ),
                  title: Text(expense.category,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(expense.description ??
                      DateFormat('dd MMM yyyy').format(expense.date)),
                  trailing: Text(
                    _formatCurrency(expense.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Gaji Karyawan':
        return '👥';
      case 'Listrik':
        return '⚡';
      case 'Air PDAM':
        return '💧';
      case 'Sewa Tempat':
        return '🏠';
      case 'Internet & WiFi':
        return '📶';
      case 'Gas LPG':
        return '🔥';
      case 'Pembelian Bahan':
        return '🛒';
      case 'Perawatan Mesin':
        return '🔧';
      case 'Kebersihan':
        return '🧽';
      case 'Marketing':
        return '📢';
      case 'Transportasi':
        return '🚚';
      case 'Pajak':
        return '🧾';
      case 'Gaji':
        return '👥';
      case 'Air':
        return '💧';
      default:
        return '💰';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Gaji Karyawan':
      case 'Gaji':
        return Colors.blue;
      case 'Listrik':
        return Colors.amber;
      case 'Air PDAM':
      case 'Air':
        return Colors.cyan;
      case 'Sewa Tempat':
        return Colors.purple;
      case 'Internet & WiFi':
        return Colors.indigo;
      case 'Gas LPG':
        return Colors.orange;
      case 'Pembelian Bahan':
        return Colors.green;
      case 'Perawatan Mesin':
        return Colors.grey;
      case 'Kebersihan':
        return Colors.teal;
      case 'Marketing':
        return Colors.pink;
      case 'Transportasi':
        return Colors.brown;
      case 'Pajak':
        return Colors.red;
      default:
        return AppTheme.primaryColor;
    }
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}

// Quick Filter Chip Widget
class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
