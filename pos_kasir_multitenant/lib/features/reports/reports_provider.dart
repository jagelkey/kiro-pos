import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return true; // Assume online if check fails
    }
  }

  /// Helper function to check connectivity results
  bool _checkConnectivityResults(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return true; // Assume online if unknown type
  }

  /// Validates tenant and returns tenantId or throws exception
  String _validateTenant() {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      throw Exception('Tenant tidak ditemukan. Silakan login ulang.');
    }
    final tenantId = authState.tenant!.id;
    if (tenantId.isEmpty) {
      throw Exception('ID Tenant tidak valid');
    }
    return tenantId;
  }

  /// Format error message for user-friendly display
  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network') ||
        errorStr.contains('timeout') ||
        errorStr.contains('host lookup')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }

    // Tenant errors
    if (errorStr.contains('tenant')) {
      return 'Tenant tidak ditemukan. Silakan login ulang.';
    }

    // Auth errors
    if (errorStr.contains('unauthorized') || errorStr.contains('auth')) {
      return 'Sesi telah berakhir. Silakan login ulang.';
    }

    // Database errors
    if (errorStr.contains('database') || errorStr.contains('sqlite')) {
      return 'Gagal mengakses data lokal. Coba restart aplikasi.';
    }

    return 'Gagal memuat data laporan. Silakan coba lagi.';
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

      List<Branch> branches = [];
      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudReportsRepositoryProvider);
          branches = await cloudRepo.getBranchesByOwner(userId);
          state = state.copyWith(branches: branches);
          return;
        } catch (e) {
          debugPrint('Cloud branches load failed, falling back to local: $e');
        }
      }

      // Fallback to local database
      if (!kIsWeb) {
        try {
          final branchRepo = ref.read(reportsBranchRepositoryProvider);
          branches = await branchRepo.getBranchesByOwner(userId);
        } catch (e) {
          debugPrint('Local branches load failed: $e');
          branches = [];
        }
      }

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
      // Validate tenant first
      final String tenantId;
      try {
        tenantId = _validateTenant();
      } catch (e) {
        state = state.copyWith(
          transactions: [],
          expenses: [],
          isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''),
        );
        return;
      }

      final authState = ref.read(authProvider);

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

      final transactionRepo = ref.read(reportsTransactionRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);

      // Check connectivity for offline-first approach
      final isOnline = await _checkConnectivity();

      // Use repository methods with proper date range filtering
      List<Transaction> transactions = [];
      List<Expense> filteredExpenses = [];
      bool loadedFromCloud = false;

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
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

          // Update offline status
          state = state.copyWith(isOffline: false);
        } catch (e) {
          debugPrint('Cloud reports fetch failed, falling back to local: $e');
          // Will fallback to local below
        }
      }

      // Fallback to local database (offline mode or cloud failed)
      if (!loadedFromCloud) {
        if (!kIsWeb) {
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

            // Mark as offline mode
            state = state.copyWith(isOffline: true);
          } catch (e) {
            debugPrint('Error fetching local reports data: $e');
            state = state.copyWith(
              transactions: [],
              expenses: [],
              isLoading: false,
              isOffline: true,
              error: _formatErrorMessage(e),
            );
            return;
          }
        } else {
          // Web without cloud - show error
          state = state.copyWith(
            transactions: [],
            expenses: [],
            isLoading: false,
            error: 'Tidak dapat memuat data. Periksa koneksi internet.',
          );
          return;
        }
      }

      // Filter by branch if selected (multi-branch support)
      if (state.selectedBranchId != null &&
          state.selectedBranchId!.isNotEmpty) {
        // Filter transactions by branchId if available
        transactions = transactions.where((t) {
          // Check if transaction has branchId field
          return t.branchId == null ||
              t.branchId!.isEmpty ||
              t.branchId == state.selectedBranchId;
        }).toList();

        // Filter expenses by branchId if available
        filteredExpenses = filteredExpenses.where((e) {
          return e.branchId == null ||
              e.branchId!.isEmpty ||
              e.branchId == state.selectedBranchId;
        }).toList();
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
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error in loadReportsData: $e');
      state = state.copyWith(
        isLoading: false,
        error: _formatErrorMessage(e),
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
