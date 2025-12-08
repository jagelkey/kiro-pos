import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../auth/auth_provider.dart';

// Re-export ExpenseSummary for use in screens
export '../../data/repositories/expense_repository.dart'
    show ExpenseSummary, ExpenseBranchSummary;

final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepository();
});

final cloudExpenseRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider for branch filter in expenses
final expenseBranchFilterProvider = StateProvider<String?>((ref) => null);

final expensesProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>((ref) {
  return ExpenseNotifier(ref);
});

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final Ref ref;
  String? _currentBranchFilter;

  ExpenseNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses({String? branchId}) async {
    state = const AsyncValue.loading();
    _currentBranchFilter = branchId;

    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
          final expenses = await cloudRepo.getExpenses(authState.tenant!.id);
          state = AsyncValue.data(expenses);
          return;
        } catch (e) {
          debugPrint('Cloud expenses load failed, falling back to local: $e');
        }
      }

      final repository = ref.read(expenseRepositoryProvider);
      List<Expense> expenses;

      if (branchId != null) {
        // Filter by specific branch
        expenses = await repository.getExpensesByBranch(
            authState.tenant!.id, branchId);
      } else {
        // Get all expenses for tenant
        expenses = await repository.getExpenses(authState.tenant!.id);
      }

      state = AsyncValue.data(expenses);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Load expenses filtered by branch
  Future<void> loadExpensesByBranch(String? branchId) async {
    await loadExpenses(branchId: branchId);
  }

  Future<void> addExpense(Expense expense) async {
    // Validate before sending to repository
    final validationError = expense.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.createExpense(expense);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        debugPrint('Cloud expense create failed, falling back to local: $e');
      }
    }

    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.createExpense(expense);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal membuat biaya');
    }
    await loadExpenses(branchId: _currentBranchFilter);
  }

  Future<void> updateExpense(Expense expense) async {
    // Validate before sending to repository
    final validationError = expense.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.updateExpense(expense);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        debugPrint('Cloud expense update failed, falling back to local: $e');
      }
    }

    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.updateExpense(expense);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah biaya');
    }
    await loadExpenses(branchId: _currentBranchFilter);
  }

  Future<void> deleteExpense(String id) async {
    final authState = ref.read(authProvider);

    // Try cloud first if enabled
    if (AppConfig.useSupabase) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.deleteExpense(id);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        debugPrint('Cloud expense delete failed, falling back to local: $e');
      }
    }

    final repository = ref.read(expenseRepositoryProvider);
    // Pass tenantId for multi-tenant validation
    final result = await repository.deleteExpense(
      id,
      tenantId: authState.tenant?.id,
    );
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus biaya');
    }
    await loadExpenses(branchId: _currentBranchFilter);
  }

  Future<double> getTotalExpenses(DateTime startDate, DateTime endDate) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return 0.0;

    final repository = ref.read(expenseRepositoryProvider);
    return repository.getTotalExpenses(
        authState.tenant!.id, startDate, endDate);
  }

  /// Get total expenses for a specific branch
  Future<double> getTotalExpensesByBranch(
    String? branchId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return 0.0;

    final repository = ref.read(expenseRepositoryProvider);
    return repository.getTotalExpensesByBranch(
      authState.tenant!.id,
      branchId,
      startDate,
      endDate,
    );
  }

  Future<List<ExpenseSummary>> getExpensesByCategory(
      DateTime startDate, DateTime endDate) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return [];

    final repository = ref.read(expenseRepositoryProvider);
    return repository.getExpensesByCategory(
        authState.tenant!.id, startDate, endDate);
  }

  /// Get expenses grouped by branch
  Future<List<ExpenseBranchSummary>> getExpensesByBranchSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return [];

    final repository = ref.read(expenseRepositoryProvider);
    return repository.getExpensesByBranchSummary(
      authState.tenant!.id,
      startDate,
      endDate,
    );
  }

  /// Refresh expenses with current filter
  Future<void> refresh() async {
    await loadExpenses(branchId: _currentBranchFilter);
  }
}
