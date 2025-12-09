import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/offline_indicator.dart';
import '../../shared/widgets/app_card.dart';
import 'dashboard_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Offline indicator for Android
          if (!kIsWeb) const OfflineIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(dashboardProvider.notifier).refresh();
              },
              child: dashboardData.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dashboardData.error != null
                      ? _buildErrorWidget(context, ref, dashboardData.error!)
                      : _buildContent(context, ref, dashboardData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, String error) {
    // Determine if this is a network error for better UX
    final isNetworkError = error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection') ||
        error.toLowerCase().contains('timeout');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: isNetworkError ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? 'Tidak ada koneksi' : 'Terjadi kesalahan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError ? 'Periksa koneksi internet Anda' : error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width <= 400;

        // Mobile: 2 columns, Tablet: 4 columns
        final crossAxisCount = isMobile ? 2 : 4;
        // Mobile: taller cards, Tablet: wider cards
        final aspectRatio = isMobile ? 1.4 : 2.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isMobile ? 8 : 12,
                mainAxisSpacing: isMobile ? 8 : 12,
                childAspectRatio: aspectRatio,
                children: [
                  _StatCard(
                    title: 'Penjualan Hari Ini',
                    value: _formatCurrency(data.todaySales),
                    icon: Icons.trending_up,
                    color: AppTheme.successColor,
                  ),
                  _StatCard(
                    title: 'Transaksi',
                    value: data.todayTransactionCount.toString(),
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor,
                  ),
                  _StatCard(
                    title: 'Biaya Hari Ini',
                    value: _formatCurrency(data.monthExpenses),
                    icon: Icons.money_off,
                    color: AppTheme.warningColor,
                  ),
                  _StatCard(
                    title: 'Laba',
                    value: _formatCurrency(data.profit),
                    icon: Icons.account_balance_wallet,
                    color: data.profit >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLowStockAlert(context, ref, data),
              _buildCapacity(context, ref),
              _buildTransactions(context, data),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  /// Build low stock materials alert section
  /// Requirements 3.4: Display visual warning indicator when stock <= minStock
  Widget _buildLowStockAlert(
      BuildContext context, WidgetRef ref, DashboardData data) {
    if (data.lowStockMaterialCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Peringatan Stok Rendah',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.lowStockMaterialCount} bahan baku perlu diisi ulang',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to materials screen via main layout index
                  // Route '/materials' may not be registered, use safer navigation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Buka menu Bahan Baku untuk melihat detail'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Lihat'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCapacity(BuildContext context, WidgetRef ref) {
    // Use dashboard provider's pre-calculated production capacity data
    // Requirements 8.4: Display production capacity based on current material stock
    final dashboardData = ref.watch(dashboardProvider);

    final canProduce = dashboardData.canProduceCount;
    final cantProduce = dashboardData.outOfStockCount;

    // Only show if there are products with recipes
    if (canProduce == 0 && cantProduce == 0) {
      return const SizedBox.shrink();
    }

    return _buildCapacityContent(canProduce, cantProduce);
  }

  Widget _buildCapacityContent(int canProduce, int cantProduce) {
    if (canProduce == 0 && cantProduce == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kapasitas Produksi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          canProduce.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
                          cantProduce.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildTransactions(BuildContext context, DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaksi Terbaru',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (data.recentTransactions.isEmpty)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada transaksi',
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
              children: data.recentTransactions.map((t) {
                // Safe time calculation with null check
                String timeAgo;
                try {
                  final diff = DateTime.now().difference(t.createdAt);
                  timeAgo = diff.inMinutes < 1
                      ? 'Baru saja'
                      : diff.inMinutes < 60
                          ? '${diff.inMinutes}m lalu'
                          : diff.inHours < 24
                              ? '${diff.inHours}j lalu'
                              : DateFormat('dd/MM').format(t.createdAt);
                } catch (e) {
                  timeAgo = '-';
                }

                // Safe item count
                final itemCount = t.items.length;

                // Safe total with null check
                final total = t.total;

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
                        child: Icon(
                          Icons.receipt,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$itemCount item',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _getPaymentLabel(t.paymentMethod),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
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
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 150;
        final padding = isCompact ? 8.0 : 12.0;
        final titleSize = isCompact ? 10.0 : 12.0;
        final valueSize = isCompact ? 14.0 : 16.0;
        final iconSize = isCompact ? 16.0 : 18.0;

        return AppCard(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: titleSize,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(icon, color: color, size: iconSize),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: valueSize,
                      ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
