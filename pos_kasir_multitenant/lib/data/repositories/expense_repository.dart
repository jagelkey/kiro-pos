import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../mock/mock_data.dart';
import 'product_repository.dart';

/// Expense summary grouped by category
class ExpenseSummary {
  final String category;
  final double total;
  final int count;

  ExpenseSummary({
    required this.category,
    required this.total,
    required this.count,
  });
}

/// Expense summary grouped by branch (multi-branch support)
class ExpenseBranchSummary {
  final String? branchId;
  final String branchName;
  final double total;
  final int count;

  ExpenseBranchSummary({
    this.branchId,
    required this.branchName,
    required this.total,
    required this.count,
  });
}

class ExpenseRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - uses MockData directly for consistency
  static List<Expense> get _webExpenses => MockData.expenses;

  /// Get all expenses for a tenant, optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<List<Expense>> getExpenses(String tenantId, {String? branchId}) async {
    try {
      if (kIsWeb) {
        var expenses = _webExpenses.where((e) => e.tenantId == tenantId);
        // Apply branch filter if provided
        if (branchId != null && branchId.isNotEmpty) {
          expenses = expenses.where((e) => e.branchId == branchId);
        }
        final result = expenses.toList();
        result.sort((a, b) => b.date.compareTo(a.date));
        return result;
      }

      final db = await _db.database;
      // Build query with optional branch filter
      String whereClause = 'tenant_id = ?';
      List<dynamic> whereArgs = [tenantId];

      if (branchId != null && branchId.isNotEmpty) {
        whereClause += ' AND branch_id = ?';
        whereArgs.add(branchId);
      }

      final results = await db.query(
        'expenses',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
      );

      return results.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  /// Get a single expense by ID
  Future<Expense?> getExpense(String id) async {
    try {
      if (kIsWeb) {
        final index = _webExpenses.indexWhere((e) => e.id == id);
        return index != -1 ? _webExpenses[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return Expense.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting expense: $e');
      return null;
    }
  }

  /// Create a new expense
  /// Returns RepositoryResult with the created expense or error
  /// Multi-tenant support: Expense must have valid tenantId
  /// Multi-branch support: Optional branchId for branch-specific expenses
  Future<RepositoryResult<Expense>> createExpense(Expense expense) async {
    try {
      // Use model validation
      final validationError = expense.validate();
      if (validationError != null) {
        return RepositoryResult.failure(validationError);
      }

      if (kIsWeb) {
        // Check for duplicate ID
        final existingIndex =
            _webExpenses.indexWhere((e) => e.id == expense.id);
        if (existingIndex != -1) {
          return RepositoryResult.failure('Biaya dengan ID ini sudah ada');
        }
        _webExpenses.add(expense);
        return RepositoryResult.success(expense);
      }

      final db = await _db.database;
      await db.insert('expenses', expense.toMap());
      return RepositoryResult.success(expense);
    } catch (e) {
      debugPrint('Error creating expense: $e');
      return RepositoryResult.failure('Gagal membuat biaya: $e');
    }
  }

  /// Update an existing expense
  /// Returns RepositoryResult with the updated expense or error
  /// Multi-tenant validation: Only allows updating expenses belonging to the same tenant
  /// Multi-branch validation: Optional branchId validation
  Future<RepositoryResult<Expense>> updateExpense(Expense expense) async {
    try {
      // Use model validation
      final validationError = expense.validate();
      if (validationError != null) {
        return RepositoryResult.failure(validationError);
      }

      // Ensure updatedAt is set
      final expenseToUpdate = expense.copyWith(updatedAt: DateTime.now());

      if (kIsWeb) {
        final index = _webExpenses.indexWhere((e) => e.id == expense.id);
        if (index == -1) {
          return RepositoryResult.failure('Biaya tidak ditemukan');
        }
        // Multi-tenant validation: Ensure expense belongs to same tenant
        if (_webExpenses[index].tenantId != expense.tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat mengubah biaya tenant lain');
        }
        _webExpenses[index] = expenseToUpdate;
        return RepositoryResult.success(expenseToUpdate);
      }

      final db = await _db.database;
      // Multi-tenant validation: Only update if tenant matches
      final rowsAffected = await db.update(
        'expenses',
        expenseToUpdate.toMap(),
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [expense.id, expense.tenantId],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure(
            'Biaya tidak ditemukan atau tidak dapat diubah');
      }
      return RepositoryResult.success(expenseToUpdate);
    } catch (e) {
      debugPrint('Error updating expense: $e');
      return RepositoryResult.failure('Gagal mengubah biaya: $e');
    }
  }

  /// Delete an expense by ID
  /// Returns RepositoryResult with success status or error
  /// tenantId is required for multi-tenant validation
  Future<RepositoryResult<bool>> deleteExpense(String id,
      {String? tenantId}) async {
    try {
      if (kIsWeb) {
        final index = _webExpenses.indexWhere((e) => e.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Biaya tidak ditemukan');
        }
        // Validate tenant ownership if tenantId provided
        if (tenantId != null && _webExpenses[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat menghapus biaya tenant lain');
        }
        _webExpenses.removeAt(index);
        return RepositoryResult.success(true);
      }

      final db = await _db.database;

      // Build query with optional tenant validation
      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [id];
      if (tenantId != null) {
        whereClause += ' AND tenant_id = ?';
        whereArgs.add(tenantId);
      }

      final rowsAffected = await db.delete(
        'expenses',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Biaya tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return RepositoryResult.failure('Gagal menghapus biaya: $e');
    }
  }

  /// Get expenses by date range (inclusive), optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<List<Expense>> getExpensesByDateRange(
    String tenantId,
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    try {
      // Normalize dates to start and end of day for inclusive filtering
      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      if (kIsWeb) {
        var expenses = _webExpenses.where((e) {
          return e.tenantId == tenantId &&
              !e.date.isBefore(normalizedStart) &&
              !e.date.isAfter(normalizedEnd);
        });
        // Apply branch filter if provided
        if (branchId != null && branchId.isNotEmpty) {
          expenses = expenses.where((e) => e.branchId == branchId);
        }
        return expenses.toList()..sort((a, b) => b.date.compareTo(a.date));
      }

      final db = await _db.database;
      // Build query with optional branch filter
      String whereClause = 'tenant_id = ? AND date >= ? AND date <= ?';
      List<dynamic> whereArgs = [
        tenantId,
        normalizedStart.toIso8601String(),
        normalizedEnd.toIso8601String(),
      ];

      if (branchId != null && branchId.isNotEmpty) {
        whereClause += ' AND branch_id = ?';
        whereArgs.add(branchId);
      }

      final results = await db.query(
        'expenses',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
      );

      return results.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting expenses by date range: $e');
      return [];
    }
  }

  /// Get total expenses for a date range, optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<double> getTotalExpenses(
    String tenantId,
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    try {
      final expenses = await getExpensesByDateRange(
          tenantId, startDate, endDate,
          branchId: branchId);
      return expenses.fold<double>(0, (sum, e) => sum + e.amount);
    } catch (e) {
      debugPrint('Error getting total expenses: $e');
      return 0.0;
    }
  }

  /// Get expenses grouped by category for a date range
  Future<List<ExpenseSummary>> getExpensesByCategory(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final expenses =
          await getExpensesByDateRange(tenantId, startDate, endDate);

      // Group by category
      final Map<String, List<Expense>> grouped = {};
      for (final expense in expenses) {
        grouped.putIfAbsent(expense.category, () => []).add(expense);
      }

      // Create summaries
      final summaries = grouped.entries.map((entry) {
        final total = entry.value.fold<double>(0, (sum, e) => sum + e.amount);
        return ExpenseSummary(
          category: entry.key,
          total: total,
          count: entry.value.length,
        );
      }).toList();

      // Sort by total descending
      summaries.sort((a, b) => b.total.compareTo(a.total));
      return summaries;
    } catch (e) {
      debugPrint('Error getting expenses by category: $e');
      return [];
    }
  }

  /// Get expenses for today
  Future<List<Expense>> getTodayExpenses(String tenantId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getExpensesByDateRange(tenantId, startOfDay, endOfDay);
  }

  /// Get expenses for this month
  Future<List<Expense>> getThisMonthExpenses(String tenantId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return getExpensesByDateRange(tenantId, startOfMonth, endOfMonth);
  }

  /// Get expenses by category name
  Future<List<Expense>> getExpensesByCategoryName(
    String tenantId,
    String category,
  ) async {
    try {
      final expenses = await getExpenses(tenantId);
      return expenses.where((e) => e.category == category).toList();
    } catch (e) {
      debugPrint('Error getting expenses by category name: $e');
      return [];
    }
  }

  /// Get all unique categories for a tenant
  Future<List<String>> getCategories(String tenantId) async {
    try {
      final expenses = await getExpenses(tenantId);
      final categories = expenses.map((e) => e.category).toSet().toList();
      categories.sort();
      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// Get expense count for a date range
  Future<int> getExpenseCount(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final expenses =
          await getExpensesByDateRange(tenantId, startDate, endDate);
      return expenses.length;
    } catch (e) {
      debugPrint('Error getting expense count: $e');
      return 0;
    }
  }

  /// Get expenses filtered by branch (multi-branch support)
  /// If branchId is null, returns expenses without branch assignment
  Future<List<Expense>> getExpensesByBranch(
    String tenantId,
    String? branchId,
  ) async {
    try {
      final expenses = await getExpenses(tenantId);
      return expenses.where((e) => e.branchId == branchId).toList();
    } catch (e) {
      debugPrint('Error getting expenses by branch: $e');
      return [];
    }
  }

  /// Get expenses by branch and date range (multi-branch support)
  Future<List<Expense>> getExpensesByBranchAndDateRange(
    String tenantId,
    String? branchId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final expenses =
          await getExpensesByDateRange(tenantId, startDate, endDate);
      if (branchId == null) {
        return expenses; // Return all if no branch filter
      }
      return expenses.where((e) => e.branchId == branchId).toList();
    } catch (e) {
      debugPrint('Error getting expenses by branch and date range: $e');
      return [];
    }
  }

  /// Get expense summary grouped by branch
  Future<List<ExpenseBranchSummary>> getExpensesByBranchSummary(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final expenses =
          await getExpensesByDateRange(tenantId, startDate, endDate);

      // Group by branchId
      final Map<String?, List<Expense>> grouped = {};
      for (final expense in expenses) {
        grouped.putIfAbsent(expense.branchId, () => []).add(expense);
      }

      // Create summaries
      final summaries = grouped.entries.map((entry) {
        final total = entry.value.fold<double>(0, (sum, e) => sum + e.amount);
        return ExpenseBranchSummary(
          branchId: entry.key,
          branchName: entry.key ?? 'Tanpa Cabang',
          total: total,
          count: entry.value.length,
        );
      }).toList();

      // Sort by total descending
      summaries.sort((a, b) => b.total.compareTo(a.total));
      return summaries;
    } catch (e) {
      debugPrint('Error getting expenses by branch summary: $e');
      return [];
    }
  }

  /// Get total expenses for a specific branch
  Future<double> getTotalExpensesByBranch(
    String tenantId,
    String? branchId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final expenses = await getExpensesByBranchAndDateRange(
        tenantId,
        branchId,
        startDate,
        endDate,
      );
      return expenses.fold<double>(0, (sum, e) => sum + e.amount);
    } catch (e) {
      debugPrint('Error getting total expenses by branch: $e');
      return 0.0;
    }
  }
}
