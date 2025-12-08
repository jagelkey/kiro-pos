import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/breakpoints.dart';
import '../../shared/widgets/app_card.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('☕ Dashboard'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(dashboardProvider.notifier).loadDashboardData(),
        child: _buildBody(context, ref, dashboardData),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, DashboardData dashboardData) {
    // Show loading state
    if (dashboardData.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat data dashboard...'),
          ],
        ),
      );
    }

    // Show error state with retry option
    if (dashboardData.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                dashboardData.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(dashboardProvider.notifier).loadDashboardData(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Breakpoints.isTabletOrLarger(constraints.maxWidth);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              GridView.count(
                crossAxisCount: isTablet ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isTablet ? 1.8 : 1.5,
                children: [
                  _StatCard(
                    title: 'Penjualan Hari Ini',
                    value: _formatCurrency(dashboardData.todaySales),
                    icon: Icons.trending_up,
                    color: AppTheme.successColor,
                  ),
                  _StatCard(
                    title: 'Transaksi',
                    value: '${dashboardData.todayTransactionCount}',
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor,
                  ),
                  _StatCard(
                    title: 'Laba Kotor',
                    value: _formatCurrency(dashboardData.grossProfit),
                    subtitle:
                        '${dashboardData.grossProfitMarginPercent.toStringAsFixed(1)}% margin',
                    icon: Icons.show_chart,
                    color: dashboardData.grossProfit >= 0
                        ? Colors.green.shade600
                        : Colors.red,
                  ),
                  _StatCard(
                    title: 'Laba Bersih',
                    value: _formatCurrency(dashboardData.profit),
                    icon: Icons.account_balance_wallet,
                    color:
                        dashboardData.profit >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Production Capacity
              _buildProductionCapacity(context, dashboardData),

              // Low Stock Warning
              if (dashboardData.lowStockMaterialCount > 0)
                _buildLowStockWarning(context, dashboardData),

              // Recent Transactions
              _buildRecentTransactions(context, dashboardData),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  Widget _buildProductionCapacity(
      BuildContext context, DashboardData dashboardData) {
    // Only show if there are products with recipes
    if (dashboardData.canProduceCount == 0 &&
        dashboardData.outOfStockCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.factory, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Kapasitas Produksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade400, Colors.purple.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${dashboardData.canProduceCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bisa Dibuat',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${dashboardData.outOfStockCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bahan Habis',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLowStockWarning(
      BuildContext context, DashboardData dashboardData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stok Bahan Rendah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      '${dashboardData.lowStockMaterialCount} bahan perlu diisi ulang',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, DashboardData dashboardData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaksi Terbaru',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (dashboardData.recentTransactions.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada transaksi hari ini',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          AppCard(
            child: Column(
              children: dashboardData.recentTransactions.map((t) {
                final diff = DateTime.now().difference(t.createdAt);
                final timeAgo = diff.inMinutes < 1
                    ? 'Baru saja'
                    : diff.inMinutes < 60
                        ? '${diff.inMinutes}m lalu'
                        : diff.inHours < 24
                            ? '${diff.inHours}j lalu'
                            : DateFormat('dd/MM').format(t.createdAt);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt,
                            color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.items.length} item',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _getPaymentLabel(t.paymentMethod),
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(t.total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
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
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style:
                  TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
