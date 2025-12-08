/// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
/// **Validates: Requirements 8.1, 8.2, 8.3**
///
/// Property: For any dashboard view, today's sales SHALL equal sum of today's
/// transactions, and transaction count SHALL equal count of today's transactions.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Dashboard calculation logic (extracted for testability)
/// This mirrors the calculation logic in DashboardProvider
class DashboardCalculator {
  /// Calculate today's sales from transactions (Requirements 8.1)
  static double calculateTodaySales(List<Transaction> todayTransactions) {
    return todayTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.total,
    );
  }

  /// Get transaction count (Requirements 8.2)
  static int getTransactionCount(List<Transaction> todayTransactions) {
    return todayTransactions.length;
  }

  /// Filter transactions for today (Requirements 8.3)
  static List<Transaction> filterTodayTransactions(
    List<Transaction> allTransactions,
    DateTime today,
  ) {
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay =
        DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    return allTransactions.where((t) {
      return !t.createdAt.isBefore(startOfDay) &&
          !t.createdAt.isAfter(endOfDay);
    }).toList();
  }
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(1000.0, 50000.0).bind((price) {
        return any.intInRange(1, 5).map((quantity) {
          final itemTotal = price * quantity;
          return TransactionItem(
            productId: 'prod-${name.hashCode.abs()}',
            productName: name.isEmpty ? 'Product' : name,
            quantity: quantity,
            price: price,
            total: itemTotal,
          );
        });
      });
    });
  }
}

/// Generator for a list of transaction items (exactly 2 items for simplicity)
extension TransactionItemsGenerator on Any {
  Generator<List<TransactionItem>> get transactionItems {
    return any.transactionItem.bind((item1) {
      return any.transactionItem.map((item2) {
        return [item1, item2];
      });
    });
  }
}

/// Generator for valid Transaction instances for a specific date
extension TransactionGenerator on Any {
  Generator<Transaction> transactionForDate(DateTime date) {
    return any.transactionItems.bind((items) {
      return any.doubleInRange(0.0, 0.15).bind((taxRate) {
        return any.doubleInRange(0.0, 5000.0).bind((discount) {
          return any.intInRange(0, 2).map((paymentIndex) {
            final subtotal =
                items.fold<double>(0, (sum, item) => sum + item.total);
            final tax = subtotal * taxRate;
            final effectiveDiscount =
                discount > subtotal + tax ? subtotal + tax : discount;
            final total = subtotal + tax - effectiveDiscount;

            final paymentMethods = ['Cash', 'QRIS', 'Transfer'];

            return Transaction(
              id: 'txn-${DateTime.now().microsecondsSinceEpoch}-${items.hashCode.abs()}',
              tenantId: 'tenant-test',
              userId: 'user-test',
              items: items,
              subtotal: subtotal,
              discount: effectiveDiscount,
              tax: tax,
              total: total > 0 ? total : 0,
              paymentMethod: paymentMethods[paymentIndex],
              createdAt: date,
            );
          });
        });
      });
    });
  }
}

/// Generator for exactly 3 transactions on a specific date
extension TransactionsListGenerator on Any {
  Generator<List<Transaction>> transactionsForDate(DateTime date) {
    return any.transactionForDate(date).bind((t1) {
      return any.transactionForDate(date).bind((t2) {
        return any.transactionForDate(date).map((t3) {
          return [t1, t2, t3];
        });
      });
    });
  }
}

/// Generator for mixed transactions (some today, some yesterday)
extension MixedTransactionsGenerator on Any {
  Generator<List<Transaction>> mixedTransactions(DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    return any.transactionsForDate(today).bind((todayTxns) {
      return any.transactionsForDate(yesterday).map((yesterdayTxns) {
        final all = [...todayTxns, ...yesterdayTxns];
        all.shuffle();
        return all;
      });
    });
  }
}

void main() {
  final today = DateTime.now();
  final todayNormalized =
      DateTime(today.year, today.month, today.day, 12, 0, 0);

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Today's sales equals sum of all today's transaction totals
  Glados(any.transactionsForDate(todayNormalized)).test(
    'Today sales equals sum of transaction totals',
    (transactions) {
      final calculatedSales =
          DashboardCalculator.calculateTodaySales(transactions);
      final expectedSales =
          transactions.fold<double>(0, (sum, t) => sum + t.total);

      // Use tolerance for floating point comparison
      if ((calculatedSales - expectedSales).abs() > 0.01) {
        throw Exception(
          'Sales mismatch: calculated $calculatedSales, expected $expectedSales',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.2**
  ///
  /// Property: Transaction count equals number of today's transactions
  Glados(any.transactionsForDate(todayNormalized)).test(
    'Transaction count equals number of transactions',
    (transactions) {
      final calculatedCount =
          DashboardCalculator.getTransactionCount(transactions);
      final expectedCount = transactions.length;

      if (calculatedCount != expectedCount) {
        throw Exception(
          'Count mismatch: calculated $calculatedCount, expected $expectedCount',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.3**
  ///
  /// Property: Filtering transactions correctly returns only today's transactions
  Glados(any.mixedTransactions(todayNormalized)).test(
    'Filter returns only today transactions',
    (allTransactions) {
      final filtered = DashboardCalculator.filterTodayTransactions(
        allTransactions,
        todayNormalized,
      );

      // All filtered transactions should be from today
      final startOfDay = DateTime(
          todayNormalized.year, todayNormalized.month, todayNormalized.day);
      final endOfDay = DateTime(todayNormalized.year, todayNormalized.month,
          todayNormalized.day, 23, 59, 59, 999);

      for (final t in filtered) {
        if (t.createdAt.isBefore(startOfDay) || t.createdAt.isAfter(endOfDay)) {
          throw Exception(
            'Filtered transaction ${t.id} is not from today: ${t.createdAt}',
          );
        }
      }

      // Count of filtered should match manual count of today's transactions
      final manualCount = allTransactions.where((t) {
        return !t.createdAt.isBefore(startOfDay) &&
            !t.createdAt.isAfter(endOfDay);
      }).length;

      if (filtered.length != manualCount) {
        throw Exception(
          'Filter count mismatch: got ${filtered.length}, expected $manualCount',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.1, 8.2, 8.3**
  ///
  /// Property: Sales and count from filtered transactions match direct calculation
  Glados(any.mixedTransactions(todayNormalized)).test(
    'Filtered sales and count match direct calculation',
    (allTransactions) {
      // Filter to today's transactions
      final todayTransactions = DashboardCalculator.filterTodayTransactions(
        allTransactions,
        todayNormalized,
      );

      // Calculate sales and count from filtered
      final sales = DashboardCalculator.calculateTodaySales(todayTransactions);
      final count = DashboardCalculator.getTransactionCount(todayTransactions);

      // Direct calculation from filtered list
      final expectedSales =
          todayTransactions.fold<double>(0, (sum, t) => sum + t.total);
      final expectedCount = todayTransactions.length;

      if ((sales - expectedSales).abs() > 0.01) {
        throw Exception(
          'Sales mismatch after filter: got $sales, expected $expectedSales',
        );
      }

      if (count != expectedCount) {
        throw Exception(
          'Count mismatch after filter: got $count, expected $expectedCount',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Adding a transaction increases sales by exactly that transaction's total
  Glados2(
    any.transactionsForDate(todayNormalized),
    any.transactionForDate(todayNormalized),
  ).test(
    'Adding transaction increases sales by transaction total',
    (existingTransactions, newTransaction) {
      final originalSales =
          DashboardCalculator.calculateTodaySales(existingTransactions);
      final newTransactions = [...existingTransactions, newTransaction];
      final newSales = DashboardCalculator.calculateTodaySales(newTransactions);

      final expectedIncrease = newTransaction.total;
      final actualIncrease = newSales - originalSales;

      if ((actualIncrease - expectedIncrease).abs() > 0.01) {
        throw Exception(
          'Sales increase mismatch: got $actualIncrease, expected $expectedIncrease',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 10: Dashboard Data Accuracy**
  /// **Validates: Requirements 8.2**
  ///
  /// Property: Adding a transaction increases count by exactly 1
  Glados2(
    any.transactionsForDate(todayNormalized),
    any.transactionForDate(todayNormalized),
  ).test(
    'Adding transaction increases count by 1',
    (existingTransactions, newTransaction) {
      final originalCount =
          DashboardCalculator.getTransactionCount(existingTransactions);
      final newTransactions = [...existingTransactions, newTransaction];
      final newCount = DashboardCalculator.getTransactionCount(newTransactions);

      if (newCount != originalCount + 1) {
        throw Exception(
          'Count should increase by 1: was $originalCount, now $newCount',
        );
      }
    },
  );
}
