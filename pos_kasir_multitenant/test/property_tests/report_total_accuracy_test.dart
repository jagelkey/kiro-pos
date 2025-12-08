/// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
/// **Validates: Requirements 5.1, 5.2**
///
/// Property: For any date range, the report total sales SHALL equal the sum of
/// all transaction totals within that date range.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Report calculation logic (extracted from ReportsProvider for testability)
class ReportCalculator {
  /// Calculate total sales from a list of transactions
  static double calculateTotalSales(List<Transaction> transactions) {
    return transactions.fold<double>(0, (sum, t) => sum + t.total);
  }

  /// Filter transactions by date range (inclusive)
  static List<Transaction> filterByDateRange(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    return transactions.where((t) {
      return !t.createdAt.isBefore(normalizedStart) &&
          !t.createdAt.isAfter(normalizedEnd);
    }).toList();
  }

  /// Calculate report totals for a date range
  static ReportResult calculateReport(
    List<Transaction> allTransactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final filteredTransactions =
        filterByDateRange(allTransactions, startDate, endDate);
    final totalSales = calculateTotalSales(filteredTransactions);
    final transactionCount = filteredTransactions.length;

    return ReportResult(
      transactions: filteredTransactions,
      totalSales: totalSales,
      transactionCount: transactionCount,
    );
  }
}

class ReportResult {
  final List<Transaction> transactions;
  final double totalSales;
  final int transactionCount;

  ReportResult({
    required this.transactions,
    required this.totalSales,
    required this.transactionCount,
  });
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((name) {
      return any.intInRange(1, 10).bind((quantity) {
        return any.doubleInRange(1000.0, 50000.0).map((price) {
          return TransactionItem(
            productId: 'prod-${name.hashCode.abs()}',
            productName: name.isEmpty ? 'Product' : name,
            quantity: quantity,
            price: price,
            total: price * quantity,
          );
        });
      });
    });
  }
}

/// Generator for a list of transaction items (1-3 items)
extension TransactionItemsGenerator on Any {
  Generator<List<TransactionItem>> get transactionItems {
    return any.transactionItem.bind((item1) {
      return any.transactionItem.bind((item2) {
        return any.transactionItem.map((item3) {
          return [item1, item2, item3];
        });
      });
    });
  }
}

/// Generator for valid Transaction instances
extension TransactionGenerator on Any {
  Generator<Transaction> get transaction {
    return any.transactionItems.bind((items) {
      return any.doubleInRange(0.0, 0.15).bind((taxRate) {
        return any.doubleInRange(0.0, 10000.0).bind((discount) {
          return any.intInRange(0, 2).bind((paymentIndex) {
            return any.intInRange(0, 30).map((daysAgo) {
              final subtotal =
                  items.fold<double>(0, (sum, item) => sum + item.total);
              final tax = subtotal * taxRate;
              final effectiveDiscount =
                  discount > subtotal + tax ? subtotal + tax : discount;
              final total = subtotal + tax - effectiveDiscount;

              final paymentMethods = ['cash', 'transfer', 'ewallet'];
              final createdAt =
                  DateTime.now().subtract(Duration(days: daysAgo));

              return Transaction(
                id: 'txn-${DateTime.now().microsecondsSinceEpoch}-${items.hashCode.abs()}',
                tenantId: 'tenant-test',
                userId: 'user-test',
                items: items,
                subtotal: subtotal,
                discount: effectiveDiscount,
                tax: tax,
                total: total,
                paymentMethod: paymentMethods[paymentIndex],
                createdAt: createdAt,
              );
            });
          });
        });
      });
    });
  }
}

/// Generator for a list of transactions (3-5 transactions)
extension TransactionsListGenerator on Any {
  Generator<List<Transaction>> get transactionsList {
    return any.transaction.bind((t1) {
      return any.transaction.bind((t2) {
        return any.transaction.bind((t3) {
          return any.transaction.bind((t4) {
            return any.transaction.map((t5) {
              return [t1, t2, t3, t4, t5];
            });
          });
        });
      });
    });
  }
}

/// Generator for date ranges (start and end dates)
extension DateRangeGenerator on Any {
  Generator<(DateTime, DateTime)> get dateRange {
    // Generate two independent day offsets and sort them to ensure valid range
    return any.intInRange(0, 30).bind((days1) {
      return any.intInRange(0, 30).map((days2) {
        final now = DateTime.now();
        // Ensure startDaysAgo >= endDaysAgo (start is earlier or same as end)
        final startDaysAgo = days1 > days2 ? days1 : days2;
        final endDaysAgo = days1 > days2 ? days2 : days1;

        final startDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: startDaysAgo));
        final endDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: endDaysAgo));
        return (startDate, endDate);
      });
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.1, 5.2**
  ///
  /// Property: Total sales equals sum of all transaction totals
  Glados(any.transactionsList).test(
    'Total sales equals sum of transaction totals',
    (transactions) {
      final totalSales = ReportCalculator.calculateTotalSales(transactions);
      final expectedTotal =
          transactions.fold<double>(0, (sum, t) => sum + t.total);

      if ((totalSales - expectedTotal).abs() > 0.001) {
        throw Exception(
            'Total sales mismatch: got $totalSales, expected $expectedTotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.1**
  ///
  /// Property: Empty transaction list has zero total sales
  Glados(any.dateRange).test(
    'Empty transaction list has zero total sales',
    (dateRange) {
      final (startDate, endDate) = dateRange;
      final result = ReportCalculator.calculateReport([], startDate, endDate);

      if (result.totalSales != 0) {
        throw Exception(
            'Empty transactions should have zero total: ${result.totalSales}');
      }
      if (result.transactionCount != 0) {
        throw Exception(
            'Empty transactions should have zero count: ${result.transactionCount}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.2**
  ///
  /// Property: Date filtering only includes transactions within range
  Glados2(any.transactionsList, any.dateRange).test(
    'Date filtering only includes transactions within range',
    (transactions, dateRange) {
      final (startDate, endDate) = dateRange;
      final filtered =
          ReportCalculator.filterByDateRange(transactions, startDate, endDate);

      final normalizedStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      for (final t in filtered) {
        if (t.createdAt.isBefore(normalizedStart)) {
          throw Exception(
              'Transaction ${t.id} is before start date: ${t.createdAt} < $normalizedStart');
        }
        if (t.createdAt.isAfter(normalizedEnd)) {
          throw Exception(
              'Transaction ${t.id} is after end date: ${t.createdAt} > $normalizedEnd');
        }
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.1, 5.2**
  ///
  /// Property: Report total equals sum of filtered transaction totals
  Glados2(any.transactionsList, any.dateRange).test(
    'Report total equals sum of filtered transaction totals',
    (transactions, dateRange) {
      final (startDate, endDate) = dateRange;
      final result =
          ReportCalculator.calculateReport(transactions, startDate, endDate);

      final expectedTotal =
          result.transactions.fold<double>(0, (sum, t) => sum + t.total);

      if ((result.totalSales - expectedTotal).abs() > 0.001) {
        throw Exception(
            'Report total mismatch: got ${result.totalSales}, expected $expectedTotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.1, 5.2**
  ///
  /// Property: Transaction count equals number of filtered transactions
  Glados2(any.transactionsList, any.dateRange).test(
    'Transaction count equals number of filtered transactions',
    (transactions, dateRange) {
      final (startDate, endDate) = dateRange;
      final result =
          ReportCalculator.calculateReport(transactions, startDate, endDate);

      if (result.transactionCount != result.transactions.length) {
        throw Exception(
            'Transaction count mismatch: got ${result.transactionCount}, expected ${result.transactions.length}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.1**
  ///
  /// Property: Total sales is never negative
  Glados2(any.transactionsList, any.dateRange).test(
    'Total sales is never negative',
    (transactions, dateRange) {
      final (startDate, endDate) = dateRange;
      final result =
          ReportCalculator.calculateReport(transactions, startDate, endDate);

      if (result.totalSales < 0) {
        throw Exception(
            'Total sales should never be negative: ${result.totalSales}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 4: Report Total Accuracy**
  /// **Validates: Requirements 5.2**
  ///
  /// Property: Wider date range includes all transactions from narrower range
  Glados(any.transactionsList).test(
    'Wider date range includes all transactions from narrower range',
    (transactions) {
      if (transactions.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Narrow range: last 7 days
      final narrowStart = today.subtract(const Duration(days: 7));
      final narrowResult =
          ReportCalculator.calculateReport(transactions, narrowStart, today);

      // Wide range: last 30 days
      final wideStart = today.subtract(const Duration(days: 30));
      final wideResult =
          ReportCalculator.calculateReport(transactions, wideStart, today);

      // All transactions in narrow range should be in wide range
      for (final t in narrowResult.transactions) {
        final inWide = wideResult.transactions.any((wt) => wt.id == t.id);
        if (!inWide) {
          throw Exception(
              'Transaction ${t.id} in narrow range but not in wide range');
        }
      }

      // Wide range total should be >= narrow range total
      if (wideResult.totalSales < narrowResult.totalSales - 0.001) {
        throw Exception(
            'Wide range total ${wideResult.totalSales} should be >= narrow range total ${narrowResult.totalSales}');
      }
    },
  );
}
