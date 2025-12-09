import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../auth/auth_provider.dart';

// Re-export ExpenseSummary for use in screens
export '../../data/repositories/expense_repository.dart'
    show ExpenseSummary, ExpenseBranchSummary;

/// Helper function to check connectivity results
bool _checkConnectivityResults(dynamic results) {
  if (results is List<ConnectivityResult>) {
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  } else if (results is ConnectivityResult) {
    return results != ConnectivityResult.none;
  }
  return true;
}

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

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Queue expense operation for sync when back online (Android only)
  Future<void> _queueForSync(String operation, Expense expense) async {
    if (kIsWeb) return; // Web doesn't support offline sync

    try {
      final syncOp = SyncOperation(
        id: '${expense.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'expenses',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: expense.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue expense sync operation: $e');
    }
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

      final tenantId = authState.tenant!.id;
      if (tenantId.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
          final expenses =
              await cloudRepo.getExpenses(tenantId, branchId: branchId);
          state = AsyncValue.data(expenses);
          return;
        } catch (e) {
          debugPrint('Cloud expenses load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local (offline mode or cloud failed)
      final repository = ref.read(expenseRepositoryProvider);
      List<Expense> expenses;

      if (branchId != null) {
        // Filter by specific branch
        expenses = await repository.getExpensesByBranch(tenantId, branchId);
      } else {
        // Get all expenses for tenant
        expenses = await repository.getExpenses(tenantId);
      }

      state = AsyncValue.data(expenses);
    } catch (e, stack) {
      debugPrint('Error loading expenses: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Load expenses filtered by branch
  Future<void> loadExpensesByBranch(String? branchId) async {
    await loadExpenses(branchId: branchId);
  }

  Future<void> addExpense(Expense expense) async {
    // Validate tenant
    final tenantId = _validateTenant();

    // Ensure expense has correct tenantId
    final expenseWithTenant = expense.copyWith(tenantId: tenantId);

    // Validate before sending to repository
    final validationError = expenseWithTenant.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.createExpense(expenseWithTenant);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        // Offline fallback: save locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud expense create failed, saving locally: $e');
          final repository = ref.read(expenseRepositoryProvider);
          final result = await repository.createExpense(expenseWithTenant);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal membuat biaya');
          }
          // Queue for sync when online
          await _queueForSync('insert', expenseWithTenant);
          await loadExpenses(branchId: _currentBranchFilter);
          return;
        } else {
          rethrow;
        }
      }
    }

    // Local mode
    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.createExpense(expenseWithTenant);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal membuat biaya');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('insert', expenseWithTenant);
    }
    await loadExpenses(branchId: _currentBranchFilter);
  }

  Future<void> updateExpense(Expense expense) async {
    // Validate tenant
    final tenantId = _validateTenant();

    // Ensure expense has correct tenantId
    final expenseWithTenant = expense.copyWith(
      tenantId: tenantId,
      updatedAt: DateTime.now(),
    );

    // Validate before sending to repository
    final validationError = expenseWithTenant.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.updateExpense(expenseWithTenant);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        // Offline fallback: save locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud expense update failed, saving locally: $e');
          final repository = ref.read(expenseRepositoryProvider);
          final result = await repository.updateExpense(expenseWithTenant);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal mengubah biaya');
          }
          // Queue for sync when online
          await _queueForSync('update', expenseWithTenant);
          await loadExpenses(branchId: _currentBranchFilter);
          return;
        } else {
          rethrow;
        }
      }
    }

    // Local mode
    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.updateExpense(expenseWithTenant);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal mengubah biaya');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      await _queueForSync('update', expenseWithTenant);
    }
    await loadExpenses(branchId: _currentBranchFilter);
  }

  Future<void> deleteExpense(String id) async {
    // Validate tenant
    final tenantId = _validateTenant();

    if (id.isEmpty) {
      throw Exception('ID biaya tidak valid');
    }

    final isOnline = await _checkConnectivity();

    // Try cloud first if enabled and online
    if (AppConfig.useSupabase && isOnline) {
      try {
        final cloudRepo = ref.read(cloudExpenseRepositoryProvider);
        await cloudRepo.deleteExpense(id);
        await loadExpenses(branchId: _currentBranchFilter);
        return;
      } catch (e) {
        // Offline fallback: delete locally and queue for sync
        if (!kIsWeb) {
          debugPrint('Cloud expense delete failed, deleting locally: $e');
          final repository = ref.read(expenseRepositoryProvider);
          final result = await repository.deleteExpense(id, tenantId: tenantId);
          if (!result.success) {
            throw Exception(result.error ?? 'Gagal menghapus biaya');
          }
          // Queue for sync when online - create dummy expense for sync data
          final dummyExpense = Expense(
            id: id,
            tenantId: tenantId,
            category: '',
            amount: 0,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          );
          await _queueForSync('delete', dummyExpense);
          await loadExpenses(branchId: _currentBranchFilter);
          return;
        } else {
          rethrow;
        }
      }
    }

    // Local mode
    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.deleteExpense(id, tenantId: tenantId);
    if (!result.success) {
      throw Exception(result.error ?? 'Gagal menghapus biaya');
    }
    // Queue for sync when online (Android only)
    if (!kIsWeb && AppConfig.useSupabase) {
      final dummyExpense = Expense(
        id: id,
        tenantId: tenantId,
        category: '',
        amount: 0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _queueForSync('delete', dummyExpense);
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
