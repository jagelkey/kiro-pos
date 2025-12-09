/// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
/// **Validates: Requirements 8.1**
///
/// Property: For any dashboard data, recentTransactions SHALL contain at most 5
/// transactions, ordered by createdAt descending.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Recent transactions handler (mirrors DashboardProvider logic)
class RecentTransactionsHandler {
  static const int maxRecentTransactions = 5;

  /// Get recent transactions limited to 5, ordered by createdAt descending
  /// Requirements 8.1: At most 5 transactions, ordered by createdAt descending
  static List<Transaction> getRecentTransactions(
      List<Transaction> allTransactions) {
    final sorted = List<Transaction>.from(allTransactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(maxRecentTransactions).toList();
  }

  /// Check if transactions are ordered by createdAt descending
  static bool isOrderedDescending(List<Transaction> transactions) {
    for (int i = 0; i < transactions.length - 1; i++) {
      if (transactions[i].createdAt.isBefore(transactions[i + 1].createdAt)) {
        return false;
      }
    }
    return true;
  }
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(5000.0, 50000.0).bind((price) {
        return any.intInRange(1, 5).map((quantity) {
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

/// Generator for valid Transaction instances with random timestamps
extension TransactionGenerator on Any {
  Generator<Transaction> get transactionWithRandomTime {
    return any.transactionItems.bind((items) {
      return any.intInRange(0, 10000).bind((minutesAgo) {
        return any.intInRange(0, 2).map((paymentIndex) {
          final subtotal =
              items.fold<double>(0, (sum, item) => sum + item.total);
          final tax = subtotal * 0.1;
          final total = subtotal + tax;

          final paymentMethods = ['cash', 'qris', 'transfer'];
          final createdAt =
              DateTime.now().subtract(Duration(minutes: minutesAgo));

          return Transaction(
            id: 'txn-${createdAt.microsecondsSinceEpoch}-${items.hashCode.abs()}',
            tenantId: 'tenant-test',
            userId: 'user-test',
            items: items,
            subtotal: subtotal,
            discount: 0,
            tax: tax,
            total: total,
            paymentMethod: paymentMethods[paymentIndex],
            createdAt: createdAt,
          );
        });
      });
    });
  }
}

/// Generator for list of transactions (more than 5)
extension TransactionsListGenerator on Any {
  /// Generate exactly 8 transactions (more than limit of 5)
  Generator<List<Transaction>> get manyTransactions {
    return any.transactionWithRandomTime.bind((t1) {
      return any.transactionWithRandomTime.bind((t2) {
        return any.transactionWithRandomTime.bind((t3) {
          return any.transactionWithRandomTime.bind((t4) {
            return any.transactionWithRandomTime.bind((t5) {
              return any.transactionWithRandomTime.bind((t6) {
                return any.transactionWithRandomTime.bind((t7) {
                  return any.transactionWithRandomTime.map((t8) {
                    return [t1, t2, t3, t4, t5, t6, t7, t8];
                  });
                });
              });
            });
          });
        });
      });
    });
  }

  /// Generate exactly 3 transactions (less than limit of 5)
  Generator<List<Transaction>> get fewTransactions {
    return any.transactionWithRandomTime.bind((t1) {
      return any.transactionWithRandomTime.bind((t2) {
        return any.transactionWithRandomTime.map((t3) {
          return [t1, t2, t3];
        });
      });
    });
  }
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Recent transactions contains at most 5 transactions
  Glados(any.manyTransactions).test(
    'Recent transactions contains at most 5 transactions',
    (allTransactions) {
      final recent =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      if (recent.length > RecentTransactionsHandler.maxRecentTransactions) {
        throw Exception(
          'Recent transactions should have at most 5: got ${recent.length}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Recent transactions are ordered by createdAt descending
  Glados(any.manyTransactions).test(
    'Recent transactions are ordered by createdAt descending',
    (allTransactions) {
      final recent =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      if (!RecentTransactionsHandler.isOrderedDescending(recent)) {
        final times = recent.map((t) => t.createdAt.toString()).join(', ');
        throw Exception(
          'Recent transactions should be ordered descending: $times',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: When less than 5 transactions, all are returned
  Glados(any.fewTransactions).test(
    'When less than 5 transactions, all are returned',
    (allTransactions) {
      final recent =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      if (recent.length != allTransactions.length) {
        throw Exception(
          'Should return all ${allTransactions.length} transactions: got ${recent.length}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Recent transactions contains the 5 most recent ones
  Glados(any.manyTransactions).test(
    'Recent transactions contains the 5 most recent ones',
    (allTransactions) {
      final recent =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      // Sort all transactions by createdAt descending
      final sortedAll = List<Transaction>.from(allTransactions)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // The recent list should contain the first 5 from sorted list
      final expected = sortedAll.take(5).toList();

      for (int i = 0; i < recent.length; i++) {
        if (recent[i].id != expected[i].id) {
          throw Exception(
            'Recent transaction at index $i should be ${expected[i].id}, got ${recent[i].id}',
          );
        }
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Empty transaction list returns empty recent list
  Glados(any.intInRange(0, 100)).test(
    'Empty transaction list returns empty recent list',
    (_) {
      final recent = RecentTransactionsHandler.getRecentTransactions([]);

      if (recent.isNotEmpty) {
        throw Exception(
            'Empty input should return empty list: ${recent.length}');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Adding a newer transaction makes it appear first
  Glados(any.fewTransactions).test(
    'Adding a newer transaction makes it appear first',
    (existingTransactions) {
      // Create a transaction that is definitely newer
      final newestTransaction = Transaction(
        id: 'txn-newest',
        tenantId: 'tenant-test',
        userId: 'user-test',
        items: [
          TransactionItem(
            productId: 'prod-1',
            productName: 'Test Product',
            quantity: 1,
            price: 10000,
            total: 10000,
          ),
        ],
        subtotal: 10000,
        discount: 0,
        tax: 1000,
        total: 11000,
        paymentMethod: 'cash',
        createdAt: DateTime.now().add(const Duration(hours: 1)), // Future time
      );

      final allTransactions = [...existingTransactions, newestTransaction];
      final recent =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      if (recent.first.id != newestTransaction.id) {
        throw Exception(
          'Newest transaction should be first: expected ${newestTransaction.id}, got ${recent.first.id}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 11: Recent Transactions Limit and Order**
  /// **Validates: Requirements 8.1**
  ///
  /// Property: Order is stable (same input produces same output)
  Glados(any.manyTransactions).test(
    'Order is stable - same input produces same output',
    (allTransactions) {
      final recent1 =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);
      final recent2 =
          RecentTransactionsHandler.getRecentTransactions(allTransactions);

      if (recent1.length != recent2.length) {
        throw Exception('Results should have same length');
      }

      for (int i = 0; i < recent1.length; i++) {
        if (recent1[i].id != recent2[i].id) {
          throw Exception(
            'Results should be identical at index $i: ${recent1[i].id} vs ${recent2[i].id}',
          );
        }
      }
    },
  );
}
