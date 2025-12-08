import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/branch.dart';
import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../auth/auth_provider.dart';

/// Data class for branch metrics
class BranchMetrics {
  final Branch branch;
  final double totalSales;
  final int transactionCount;
  final double averageTransaction;

  BranchMetrics({
    required this.branch,
    required this.totalSales,
    required this.transactionCount,
    required this.averageTransaction,
  });
}

/// Data class for owner dashboard
class OwnerDashboardData {
  final double totalSalesAllBranches;
  final int totalTransactions;
  final int activeBranchCount;
  final int totalBranchCount;
  final List<BranchMetrics> branchMetrics;
  final List<BranchMetrics> topBranches;
  final List<BranchMetrics> lowPerformingBranches;
  final bool isLoading;
  final String? error;

  OwnerDashboardData({
    this.totalSalesAllBranches = 0,
    this.totalTransactions = 0,
    this.activeBranchCount = 0,
    this.totalBranchCount = 0,
    this.branchMetrics = const [],
    this.topBranches = const [],
    this.lowPerformingBranches = const [],
    this.isLoading = false,
    this.error,
  });

  OwnerDashboardData copyWith({
    double? totalSalesAllBranches,
    int? totalTransactions,
    int? activeBranchCount,
    int? totalBranchCount,
    List<BranchMetrics>? branchMetrics,
    List<BranchMetrics>? topBranches,
    List<BranchMetrics>? lowPerformingBranches,
    bool? isLoading,
    String? error,
  }) {
    return OwnerDashboardData(
      totalSalesAllBranches:
          totalSalesAllBranches ?? this.totalSalesAllBranches,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      activeBranchCount: activeBranchCount ?? this.activeBranchCount,
      totalBranchCount: totalBranchCount ?? this.totalBranchCount,
      branchMetrics: branchMetrics ?? this.branchMetrics,
      topBranches: topBranches ?? this.topBranches,
      lowPerformingBranches:
          lowPerformingBranches ?? this.lowPerformingBranches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for owner dashboard
/// Requirements 12.1, 12.2: Aggregate sales across all branches
final ownerDashboardProvider =
    StateNotifierProvider<OwnerDashboardNotifier, OwnerDashboardData>((ref) {
  return OwnerDashboardNotifier(ref);
});

class OwnerDashboardNotifier extends StateNotifier<OwnerDashboardData> {
  final Ref ref;
  final BranchRepository _branchRepo = BranchRepository();
  final TransactionRepository _transactionRepo = TransactionRepository();
  final CloudRepository _cloudRepo = CloudRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  OwnerDashboardNotifier(this.ref) : super(OwnerDashboardData()) {
    loadDashboard();
  }

  /// Set date range filter
  /// Requirements 12.3: Apply filter to all branch data
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    loadDashboard();
  }

  /// Load dashboard data
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // Get all branches for owner - try cloud first
      List<Branch> branches;
      if (AppConfig.useSupabase) {
        try {
          branches = await _cloudRepo.getBranchesByOwner(user.id);
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
          branches = await _branchRepo.getBranchesByOwner(user.id);
        }
      } else {
        branches = await _branchRepo.getBranchesByOwner(user.id);
      }

      final activeBranches = branches.where((b) => b.isActive).toList();

      // Calculate metrics for each branch
      final metrics = <BranchMetrics>[];
      double totalSales = 0;
      int totalTx = 0;

      // Get tenant ID from auth state
      final tenantId = authState.tenant?.id ?? user.tenantId;

      for (final branch in branches) {
        // Get transactions for this tenant/branch
        List<dynamic> transactions;
        if (AppConfig.useSupabase) {
          try {
            transactions = await _cloudRepo.getTransactions(
              tenantId,
              startDate: _startDate,
              endDate: _endDate,
            );
          } catch (e) {
            debugPrint('Cloud transactions load failed: $e');
            transactions = await _transactionRepo.getTransactionsByDateRange(
              tenantId,
              _startDate,
              _endDate,
            );
          }
        } else {
          transactions = await _transactionRepo.getTransactionsByDateRange(
            tenantId,
            _startDate,
            _endDate,
          );
        }

        final branchSales = transactions.fold<double>(
          0,
          (sum, t) => sum + (t.total as num).toDouble(),
        );
        final branchTxCount = transactions.length;
        final avgTx = branchTxCount > 0 ? branchSales / branchTxCount : 0.0;

        metrics.add(BranchMetrics(
          branch: branch,
          totalSales: branchSales,
          transactionCount: branchTxCount,
          averageTransaction: avgTx,
        ));

        if (branch.isActive) {
          totalSales += branchSales;
          totalTx += branchTxCount;
        }
      }

      // Sort for top and low performing
      final sortedBySales = List<BranchMetrics>.from(metrics)
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

      final topBranches = sortedBySales.take(3).toList();
      final lowPerforming = sortedBySales.reversed.take(3).toList();

      state = OwnerDashboardData(
        totalSalesAllBranches: totalSales,
        totalTransactions: totalTx,
        activeBranchCount: activeBranches.length,
        totalBranchCount: branches.length,
        branchMetrics: metrics,
        topBranches: topBranches,
        lowPerformingBranches: lowPerforming,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading owner dashboard: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard: $e',
      );
    }
  }

  /// Refresh dashboard data
  void refresh() => loadDashboard();
}
