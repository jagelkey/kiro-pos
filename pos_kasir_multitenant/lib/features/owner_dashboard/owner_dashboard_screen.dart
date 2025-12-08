import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import 'owner_dashboard_provider.dart';

/// Owner dashboard screen
/// Requirements 12.1, 12.2, 12.5: Owner dashboard with branch metrics
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(ownerDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Dashboard Owner'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangePicker(context, ref),
            tooltip: 'Filter Tanggal',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(ownerDashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: dashboardData.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dashboardData.error != null
              ? _buildErrorWidget(context, ref, dashboardData.error!)
              : _buildContent(context, dashboardData),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(ownerDashboardProvider.notifier).refresh(),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, OwnerDashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(data),
          const SizedBox(height: 24),
          // Top Performing Branches
          _buildTopBranches(data),
          const SizedBox(height: 24),
          // All Branches Performance
          _buildAllBranches(data),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(OwnerDashboardData data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _SummaryCard(
          title: 'Total Penjualan',
          value: _formatCurrency(data.totalSalesAllBranches),
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _SummaryCard(
          title: 'Total Transaksi',
          value: data.totalTransactions.toString(),
          icon: Icons.receipt_long,
          color: AppTheme.primaryColor,
        ),
        _SummaryCard(
          title: 'Cabang Aktif',
          value: '${data.activeBranchCount}/${data.totalBranchCount}',
          icon: Icons.store,
          color: Colors.blue,
        ),
        _SummaryCard(
          title: 'Rata-rata/Transaksi',
          value: data.totalTransactions > 0
              ? _formatCurrency(
                  data.totalSalesAllBranches / data.totalTransactions)
              : 'Rp 0',
          icon: Icons.analytics,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildTopBranches(OwnerDashboardData data) {
    if (data.topBranches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 Cabang Terbaik',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...data.topBranches.asMap().entries.map((entry) {
          final index = entry.key;
          final metrics = entry.value;
          return _BranchPerformanceCard(
            metrics: metrics,
            rank: index + 1,
            isTop: true,
          );
        }),
      ],
    );
  }

  Widget _buildAllBranches(OwnerDashboardData data) {
    if (data.branchMetrics.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.store_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum ada cabang',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📈 Performa Semua Cabang',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...data.branchMetrics.map((metrics) => _BranchPerformanceCard(
              metrics: metrics,
            )),
      ],
    );
  }

  void _showDateRangePicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      ref.read(ownerDashboardProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
    }
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Branch performance card widget
class _BranchPerformanceCard extends StatelessWidget {
  final BranchMetrics metrics;
  final int? rank;
  final bool isTop;

  const _BranchPerformanceCard({
    required this.metrics,
    this.rank,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (rank != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getRankColor().withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getRankColor(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: metrics.branch.isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.store,
              color: metrics.branch.isActive ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics.branch.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  metrics.branch.code,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(metrics.totalSales),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isTop ? Colors.green : null,
                ),
              ),
              Text(
                '${metrics.transactionCount} transaksi',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return AppTheme.textMuted;
    }
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);
}
