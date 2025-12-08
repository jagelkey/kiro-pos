import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/transaction.dart';
import '../../data/models/expense.dart';
import '../../data/models/branch.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../expenses/expenses_provider.dart';
import '../auth/auth_provider.dart';

final reportsTransactionRepositoryProvider =
    Provider((ref) => TransactionRepository());

final reportsBranchRepositoryProvider = Provider((ref) => BranchRepository());

final cloudReportsRepositoryProvider = Provider((ref) => CloudRepository());

/// Reports data state with multi-branch support
class ReportsData {
  final List<Transaction> transactions;
  final List<Expense> expenses;
  final List<Branch> branches;
  final String? selectedBranchId; // null = all branches
  final DateTime startDate;
  final DateTime endDate;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  ReportsData({
    this.transactions = const [],
    this.expenses = const [],
    this.branches = const [],
    this.selectedBranchId,
    required this.startDate,
    required this.endDate,
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  double get totalSales =>
      transactions.fold<double>(0, (sum, t) => sum + t.total);
  double get totalExpenses =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);
  double get profit => totalSales - totalExpenses;
  int get transactionCount => transactions.length;

  /// Total harga pokok penjualan (COGS - Cost of Goods Sold)
  double get totalCostOfGoodsSold =>
      transactions.fold<double>(0, (sum, t) => sum + t.totalCostPrice);

  /// Laba kotor (Gross Profit) = Penjualan - HPP
  double get grossProfit => totalSales - totalCostOfGoodsSold;

  /// Laba bersih (Net Profit) = Laba Kotor - Pengeluaran
  double get netProfit => grossProfit - totalExpenses;

  /// Persentase margin laba kotor
  double get grossProfitMarginPercent =>
      totalSales > 0 ? (grossProfit / totalSales) * 100 : 0;

  /// Check if there's an error
  bool get hasError => error != null && error!.isNotEmpty;

  /// Check if data is empty
  bool get isEmpty => transactions.isEmpty && expenses.isEmpty;

  /// Get selected branch name
  String get selectedBranchName {
    if (selectedBranchId == null) return 'Semua Cabang';
    final branch = branches.firstWhere(
      (b) => b.id == selectedBranchId,
      orElse: () => Branch(
        id: '',
        ownerId: '',
        name: 'Unknown',
        code: '',
        createdAt: DateTime.now(),
      ),
    );
    return branch.name;
  }

  ReportsData copyWith({
    List<Transaction>? transactions,
    List<Expense>? expenses,
    List<Branch>? branches,
    String? selectedBranchId,
    bool clearBranchFilter = false,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isOffline,
  }) {
    return ReportsData(
      transactions: transactions ?? this.transactions,
      expenses: expenses ?? this.expenses,
      branches: branches ?? this.branches,
      selectedBranchId: clearBranchFilter
          ? null
          : (selectedBranchId ?? this.selectedBranchId),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsData> {
  final Ref ref;

  ReportsNotifier(this.ref)
      : super(ReportsData(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          endDate: DateTime.now(),
          isLoading: true,
          isOffline: !kIsWeb, // Mobile uses SQLite (offline-capable)
        )) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await loadBranches();
    await loadReportsData();
  }

  /// Load available branches for filtering (multi-branch support)
  Future<void> loadBranches() async {
    try {
      final authState = ref.read(authProvider);
      if (authState.user == null) return;

      final userId = authState.user!.id;
      if (userId.isEmpty) {
        debugPrint('User ID is empty, skipping branch load');
        return;
      }

      List<Branch> branches;

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudReportsRepositoryProvider);
          branches = await cloudRepo.getBranchesByOwner(userId);
          state = state.copyWith(branches: branches);
          return;
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
        }
      }

      final branchRepo = ref.read(reportsBranchRepositoryProvider);
      branches = await branchRepo.getBranchesByOwner(userId);

      state = state.copyWith(branches: branches);
    } catch (e) {
      // Branches are optional, don't fail if not available
      debugPrint('Error loading branches: $e');
      state = state.copyWith(branches: []);
    }
  }

  Future<void> loadReportsData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = state.copyWith(
          transactions: [],
          expenses: [],
          isLoading: false,
          error: 'Tenant tidak ditemukan. Silakan login ulang.',
        );
        return;
      }

      // Role validation - only owner and admin can access full reports
      // Cashier can only see their own transactions
      final user = authState.user;
      if (user == null) {
        state = state.copyWith(
          transactions: [],
          expenses: [],
          isLoading: false,
          error: 'User tidak ditemukan. Silakan login ulang.',
        );
        return;
      }

      final tenantId = authState.tenant!.id;

      // Validate tenantId
      if (tenantId.isEmpty) {
        state = state.copyWith(
          transactions: [],
          expenses: [],
          isLoading: false,
          error: 'ID Tenant tidak valid',
        );
        return;
      }

      final transactionRepo = ref.read(reportsTransactionRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);

      // Use repository methods with proper date range filtering
      List<Transaction> transactions = [];
      List<Expense> filteredExpenses = [];
      bool loadedFromCloud = false;

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudReportsRepositoryProvider);
          final results = await Future.wait([
            cloudRepo.getTransactions(
              tenantId,
              startDate: state.startDate,
              endDate: state.endDate,
            ),
            cloudRepo.getExpenses(
              tenantId,
              startDate: state.startDate,
              endDate: state.endDate,
            ),
          ]);

          transactions = results[0] as List<Transaction>;
          filteredExpenses = results[1] as List<Expense>;
          loadedFromCloud = true;
        } catch (e) {
          debugPrint('Cloud reports fetch failed, falling back to local: $e');
        }
      }

      if (!loadedFromCloud) {
        try {
          final results = await Future.wait([
            transactionRepo.getTransactionsByDateRange(
              tenantId,
              state.startDate,
              state.endDate,
            ),
            expenseRepo.getExpensesByDateRange(
              tenantId,
              state.startDate,
              state.endDate,
            ),
          ]);

          transactions = results[0] as List<Transaction>;
          filteredExpenses = results[1] as List<Expense>;
        } catch (e) {
          debugPrint('Error fetching reports data: $e');
          // Continue with empty data if fetch fails
          transactions = [];
          filteredExpenses = [];
        }
      }

      // Filter by branch if selected (multi-branch support)
      // Note: This requires branchId field in Transaction model
      // For now, we filter based on available data
      if (state.selectedBranchId != null) {
        // Future enhancement: filter transactions by branchId
        // transactions = transactions.where((t) => t.branchId == state.selectedBranchId).toList();
      }

      // Role-based filtering: Cashier only sees their own transactions
      if (user.role.toString().contains('cashier')) {
        transactions = transactions.where((t) => t.userId == user.id).toList();
        // Cashiers shouldn't see expenses
        filteredExpenses = [];
      }

      state = state.copyWith(
        transactions: transactions,
        expenses: filteredExpenses,
        isLoading: false,
        isOffline: !kIsWeb,
      );
    } catch (e) {
      debugPrint('Error in loadReportsData: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data laporan: ${e.toString()}',
      );
    }
  }

  /// Set branch filter for multi-branch reports
  void setBranchFilter(String? branchId) {
    if (branchId == null) {
      state = state.copyWith(clearBranchFilter: true);
    } else {
      state = state.copyWith(selectedBranchId: branchId);
    }
    loadReportsData();
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setDateRange(DateTime startDate, DateTime endDate) {
    // Validate date range
    if (startDate.isAfter(endDate)) {
      state = state.copyWith(
          error: 'Tanggal mulai tidak boleh setelah tanggal akhir');
      return;
    }
    state = state.copyWith(startDate: startDate, endDate: endDate);
    loadReportsData();
  }

  void setToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setDateRange(today, today);
  }

  void setYesterday() {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    setDateRange(yesterday, yesterday);
  }

  void setLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    setDateRange(sevenDaysAgo, today);
  }

  void setLast30Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = today.subtract(const Duration(days: 29));
    setDateRange(thirtyDaysAgo, today);
  }

  void setThisMonth() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    setDateRange(firstDayOfMonth, today);
  }

  void setLastMonth() {
    final now = DateTime.now();
    final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayLastMonth = DateTime(now.year, now.month, 0);
    setDateRange(firstDayLastMonth, lastDayLastMonth);
  }

  void refresh() => loadReportsData();

  /// Retry loading data after error
  void retry() {
    clearError();
    loadReportsData();
  }
}

final reportsProvider =
    StateNotifierProvider<ReportsNotifier, ReportsData>((ref) {
  return ReportsNotifier(ref);
});
