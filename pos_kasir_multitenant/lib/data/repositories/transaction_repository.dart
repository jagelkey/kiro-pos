import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import '../../core/config/app_config.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../mock/mock_data.dart';
import 'product_repository.dart';
import 'cloud_repository.dart';

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final CloudRepository _cloudRepository = CloudRepository();

  // In-memory storage for web - uses MockData
  static List<Transaction> get _webTransactions => MockData.transactions;

  /// Get all transactions for a tenant, optionally filtered by branch
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Transaction>> getTransactions(String tenantId,
      {String? branchId}) async {
    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          return await _cloudRepository.getTransactions(tenantId,
              branchId: branchId);
        } catch (e) {
          debugPrint(
              'Cloud transactions load failed, falling back to local: $e');
        }
      }

      if (kIsWeb) {
        var transactions =
            _webTransactions.where((t) => t.tenantId == tenantId);
        // Note: Web mock data doesn't have branchId, so we skip branch filtering for web
        return transactions.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return results.map((map) => _mapToTransaction(map)).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  /// Get a single transaction by ID
  Future<Transaction?> getTransaction(String id) async {
    try {
      if (kIsWeb) {
        final index = _webTransactions.indexWhere((t) => t.id == id);
        return index != -1 ? _webTransactions[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return _mapToTransaction(results.first);
    } catch (e) {
      debugPrint('Error getting transaction: $e');
      return null;
    }
  }

  /// Get transactions by date range (inclusive), optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.3: Multi-tenant data isolation with branch filtering
  Future<List<Transaction>> getTransactionsByDateRange(
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

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          return await _cloudRepository.getTransactions(
            tenantId,
            branchId: branchId,
            startDate: normalizedStart,
            endDate: normalizedEnd,
          );
        } catch (e) {
          debugPrint(
              'Cloud transactions by date failed, falling back to local: $e');
        }
      }

      if (kIsWeb) {
        return _webTransactions.where((t) {
          return t.tenantId == tenantId &&
              !t.createdAt.isBefore(normalizedStart) &&
              !t.createdAt.isAfter(normalizedEnd);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final db = await _db.database;
      // Build query with optional branch filter
      String whereClause =
          'tenant_id = ? AND created_at >= ? AND created_at <= ?';
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
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return results.map((map) => _mapToTransaction(map)).toList();
    } catch (e) {
      debugPrint('Error getting transactions by date range: $e');
      return [];
    }
  }

  /// Create a new transaction
  /// Returns RepositoryResult with the created transaction or error
  Future<RepositoryResult<Transaction>> createTransaction(
      Transaction transaction) async {
    try {
      // Validate required fields
      if (transaction.items.isEmpty) {
        return RepositoryResult.failure(
            'Transaction must have at least one item');
      }
      if (transaction.total <= 0) {
        return RepositoryResult.failure('Transaction total must be positive');
      }
      if (transaction.paymentMethod.trim().isEmpty) {
        return RepositoryResult.failure('Payment method is required');
      }

      // Try cloud first if enabled - sync transaction to Supabase
      if (AppConfig.useSupabase) {
        try {
          final created = await _cloudRepository.createTransaction(transaction);
          // Also save locally for offline access
          if (!kIsWeb) {
            final db = await _db.database;
            await db.insert('transactions', _transactionToMap(transaction));
          }
          return RepositoryResult.success(created);
        } catch (e) {
          debugPrint('Cloud transaction create failed, saving locally: $e');
          // Continue to save locally even if cloud fails
        }
      }

      // Validate transaction ID uniqueness (only for local)
      final existingTransaction = await getTransaction(transaction.id);
      if (existingTransaction != null) {
        return RepositoryResult.failure(
            'Transaction with this ID already exists');
      }

      if (kIsWeb) {
        _webTransactions.add(transaction);
        return RepositoryResult.success(transaction);
      }

      final db = await _db.database;
      await db.insert('transactions', _transactionToMap(transaction));
      return RepositoryResult.success(transaction);
    } catch (e) {
      debugPrint('Error creating transaction: $e');
      return RepositoryResult.failure('Failed to create transaction: $e');
    }
  }

  /// Get total sales for a date range
  Future<double> getTotalSales(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions =
          await getTransactionsByDateRange(tenantId, startDate, endDate);
      return transactions.fold<double>(0, (sum, t) => sum + t.total);
    } catch (e) {
      debugPrint('Error getting total sales: $e');
      return 0.0;
    }
  }

  /// Get transaction count for a date range
  Future<int> getTransactionCount(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions =
          await getTransactionsByDateRange(tenantId, startDate, endDate);
      return transactions.length;
    } catch (e) {
      debugPrint('Error getting transaction count: $e');
      return 0;
    }
  }

  /// Get today's transactions
  Future<List<Transaction>> getTodayTransactions(String tenantId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getTransactionsByDateRange(tenantId, startOfDay, endOfDay);
  }

  /// Get today's total sales
  Future<double> getTodaySales(String tenantId) async {
    final transactions = await getTodayTransactions(tenantId);
    return transactions.fold<double>(0, (sum, t) => sum + t.total);
  }

  /// Get today's transaction count
  Future<int> getTodayTransactionCount(String tenantId) async {
    final transactions = await getTodayTransactions(tenantId);
    return transactions.length;
  }

  /// Get transactions for this month
  Future<List<Transaction>> getThisMonthTransactions(String tenantId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return getTransactionsByDateRange(tenantId, startOfMonth, endOfMonth);
  }

  /// Get transactions by payment method
  Future<List<Transaction>> getTransactionsByPaymentMethod(
    String tenantId,
    String paymentMethod,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions =
          await getTransactionsByDateRange(tenantId, startDate, endDate);
      return transactions
          .where((t) => t.paymentMethod == paymentMethod)
          .toList();
    } catch (e) {
      debugPrint('Error getting transactions by payment method: $e');
      return [];
    }
  }

  /// Get sales summary by payment method
  Future<Map<String, double>> getSalesByPaymentMethod(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions =
          await getTransactionsByDateRange(tenantId, startDate, endDate);
      final Map<String, double> summary = {};

      for (final transaction in transactions) {
        summary.update(
          transaction.paymentMethod,
          (value) => value + transaction.total,
          ifAbsent: () => transaction.total,
        );
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting sales by payment method: $e');
      return {};
    }
  }

  /// Get product sales summary
  Future<Map<String, int>> getProductSalesSummary(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactions =
          await getTransactionsByDateRange(tenantId, startDate, endDate);
      final Map<String, int> summary = {};

      for (final transaction in transactions) {
        for (final item in transaction.items) {
          summary.update(
            item.productName,
            (value) => value + item.quantity,
            ifAbsent: () => item.quantity,
          );
        }
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting product sales summary: $e');
      return {};
    }
  }

  /// Get recent transactions (limited)
  Future<List<Transaction>> getRecentTransactions(String tenantId,
      {int limit = 10}) async {
    try {
      final transactions = await getTransactions(tenantId);
      return transactions.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting recent transactions: $e');
      return [];
    }
  }

  /// Get transactions by shift ID
  /// Requirements 13.5: Associate transactions with shift
  Future<List<Transaction>> getTransactionsByShift(
    String tenantId,
    String shiftId,
  ) async {
    try {
      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          return await _cloudRepository.getTransactionsByShift(shiftId);
        } catch (e) {
          debugPrint(
              'Cloud transactions by shift failed, falling back to local: $e');
        }
      }

      if (kIsWeb) {
        return _webTransactions
            .where((t) => t.tenantId == tenantId && t.shiftId == shiftId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final db = await _db.database;
      final results = await db.query(
        'transactions',
        where: 'tenant_id = ? AND shift_id = ?',
        whereArgs: [tenantId, shiftId],
        orderBy: 'created_at DESC',
      );

      return results.map((map) => _mapToTransaction(map)).toList();
    } catch (e) {
      debugPrint('Error getting transactions by shift: $e');
      return [];
    }
  }

  /// Get cash sales total for a shift
  /// Requirements 13.2: Calculate expected cash based on transactions
  Future<double> getCashSalesForShift(String tenantId, String shiftId) async {
    try {
      final transactions = await getTransactionsByShift(tenantId, shiftId);
      return transactions
          .where((t) => t.paymentMethod == 'cash')
          .fold<double>(0.0, (sum, t) => sum + t.total);
    } catch (e) {
      debugPrint('Error getting cash sales for shift: $e');
      return 0.0;
    }
  }

  // Private helper methods for serialization/deserialization

  /// Convert database map to Transaction object
  Transaction _mapToTransaction(Map<String, dynamic> map) {
    // Handle items serialization - can be stored as JSON string or List
    List<TransactionItem> items = [];
    final itemsData = map['items'];

    if (itemsData != null) {
      if (itemsData is String) {
        // Items stored as JSON string in SQLite
        try {
          final itemsJson = jsonDecode(itemsData) as List;
          items = itemsJson
              .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing items JSON: $e');
        }
      } else if (itemsData is List) {
        // Items already as List (from mock data)
        items = itemsData
            .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return Transaction(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      userId: map['user_id'] as String,
      shiftId: map['shift_id'] as String?,
      discountId: map['discount_id'] as String?,
      items: items,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Transaction object to database map
  Map<String, dynamic> _transactionToMap(Transaction transaction) {
    return {
      'id': transaction.id,
      'tenant_id': transaction.tenantId,
      'user_id': transaction.userId,
      'shift_id': transaction.shiftId,
      'discount_id': transaction.discountId,
      'items': jsonEncode(transaction.items.map((e) => e.toJson()).toList()),
      'subtotal': transaction.subtotal,
      'discount': transaction.discount,
      'tax': transaction.tax,
      'total': transaction.total,
      'payment_method': transaction.paymentMethod,
      'created_at': transaction.createdAt.toIso8601String(),
    };
  }
}
