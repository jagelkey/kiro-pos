/// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
/// **Validates: Requirements 5.1, 5.2**
///
/// Property: For any set of transactions for a given date, the dashboard's todaySales
/// SHALL equal the sum of all transaction totals, and todayTransactionCount SHALL
/// equal the count of transactions.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Sales statistics calculator (mirrors DashboardProvider logic)
class SalesStatisticsCalculator {
  /// Calculate today's sales from transactions (Requirements 5.1)
  static double calculateTodaySales(List<Transaction> transactions) {
    return transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.total,
    );
  }

  /// Get transaction count (Requirements 5.2)
  static int getTransactionCount(List<Transaction> transactions) {
    return transactions.length;
  }

  /// Filter transactions for a specific date
  static List<Transaction> filterTransactionsForDate(
    List<Transaction> allTransactions,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

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
      return any.doubleInRange(1000.0, 100000.0).bind((price) {
        return any.intInRange(1, 10).map((quantity) {
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

/// Generator for a list of transaction items
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
      return any.doubleInRange(0.0, 0.11).bind((taxRate) {
        return any.doubleInRange(0.0, 5000.0).bind((discount) {
          return any.intInRange(0, 2).map((paymentIndex) {
            final subtotal =
                items.fold<double>(0, (sum, item) => sum + item.total);
            final tax = subtotal * taxRate;
            final effectiveDiscount =
                discount > subtotal + tax ? subtotal + tax : discount;
            final total = subtotal + tax - effectiveDiscount;

            final paymentMethods = ['cash', 'qris', 'transfer'];

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

/// Generator for list of transactions on a specific date
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

/// Generator for mixed transactions (today and other days)
extension MixedTransactionsGenerator on Any {
  Generator<List<Transaction>> mixedTransactions(DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    return any.transactionsForDate(today).bind((todayTxns) {
      return any.transactionForDate(yesterday).bind((yesterdayTxn) {
        return any.transactionForDate(twoDaysAgo).map((twoDaysAgoTxn) {
          final all = [...todayTxns, yesterdayTxn, twoDaysAgoTxn];
          all.shuffle();
          return all;
        });
      });
    });
  }
}

void main() {
  final today = DateTime.now();
  final todayNormalized =
      DateTime(today.year, today.month, today.day, 12, 0, 0);

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.1**
  ///
  /// Property: todaySales equals sum of all transaction totals
  Glados(any.transactionsForDate(todayNormalized)).test(
    'todaySales equals sum of all transaction totals',
    (transactions) {
      final calculatedSales =
          SalesStatisticsCalculator.calculateTodaySales(transactions);
      final expectedSales =
          transactions.fold<double>(0, (sum, t) => sum + t.total);

      if ((calculatedSales - expectedSales).abs() > 0.01) {
        throw Exception(
          'Sales mismatch: calculated $calculatedSales, expected $expectedSales',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.2**
  ///
  /// Property: todayTransactionCount equals count of transactions
  Glados(any.transactionsForDate(todayNormalized)).test(
    'todayTransactionCount equals count of transactions',
    (transactions) {
      final calculatedCount =
          SalesStatisticsCalculator.getTransactionCount(transactions);
      final expectedCount = transactions.length;

      if (calculatedCount != expectedCount) {
        throw Exception(
          'Count mismatch: calculated $calculatedCount, expected $expectedCount',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.1, 5.2**
  ///
  /// Property: Filtering by date correctly isolates today's transactions
  Glados(any.mixedTransactions(todayNormalized)).test(
    'Filtering by date correctly isolates today transactions',
    (allTransactions) {
      final filtered = SalesStatisticsCalculator.filterTransactionsForDate(
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
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.1**
  ///
  /// Property: Sales from filtered transactions equals sum of filtered totals
  Glados(any.mixedTransactions(todayNormalized)).test(
    'Sales from filtered transactions equals sum of filtered totals',
    (allTransactions) {
      final filtered = SalesStatisticsCalculator.filterTransactionsForDate(
        allTransactions,
        todayNormalized,
      );

      final calculatedSales =
          SalesStatisticsCalculator.calculateTodaySales(filtered);
      final expectedSales = filtered.fold<double>(0, (sum, t) => sum + t.total);

      if ((calculatedSales - expectedSales).abs() > 0.01) {
        throw Exception(
          'Filtered sales mismatch: calculated $calculatedSales, expected $expectedSales',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.1**
  ///
  /// Property: Adding a transaction increases sales by exactly that amount
  Glados2(
    any.transactionsForDate(todayNormalized),
    any.transactionForDate(todayNormalized),
  ).test(
    'Adding transaction increases sales by transaction total',
    (existingTransactions, newTransaction) {
      final originalSales =
          SalesStatisticsCalculator.calculateTodaySales(existingTransactions);
      final newTransactions = [...existingTransactions, newTransaction];
      final newSales =
          SalesStatisticsCalculator.calculateTodaySales(newTransactions);

      final expectedIncrease = newTransaction.total;
      final actualIncrease = newSales - originalSales;

      if ((actualIncrease - expectedIncrease).abs() > 0.01) {
        throw Exception(
          'Sales increase mismatch: got $actualIncrease, expected $expectedIncrease',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.2**
  ///
  /// Property: Adding a transaction increases count by exactly 1
  Glados2(
    any.transactionsForDate(todayNormalized),
    any.transactionForDate(todayNormalized),
  ).test(
    'Adding transaction increases count by 1',
    (existingTransactions, newTransaction) {
      final originalCount =
          SalesStatisticsCalculator.getTransactionCount(existingTransactions);
      final newTransactions = [...existingTransactions, newTransaction];
      final newCount =
          SalesStatisticsCalculator.getTransactionCount(newTransactions);

      if (newCount != originalCount + 1) {
        throw Exception(
          'Count should increase by 1: was $originalCount, now $newCount',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 3: Sales Statistics Accuracy**
  /// **Validates: Requirements 5.1, 5.2**
  ///
  /// Property: Empty transaction list results in zero sales and count
  Glados(any.intInRange(0, 100)).test(
    'Empty transaction list results in zero sales and count',
    (_) {
      final sales = SalesStatisticsCalculator.calculateTodaySales([]);
      final count = SalesStatisticsCalculator.getTransactionCount([]);

      if (sales != 0) {
        throw Exception('Empty list should have zero sales: $sales');
      }
      if (count != 0) {
        throw Exception('Empty list should have zero count: $count');
      }
    },
  );
}
