/// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
/// **Validates: Requirements 5.3, 6.5**
///
/// Property: For any period, profit SHALL equal total sales minus total expenses
/// for that period.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';
import 'package:pos_kasir_multitenant/data/models/expense.dart';

/// Profit calculation logic (extracted from ReportsProvider for testability)
class ProfitCalculator {
  /// Calculate total sales from a list of transactions
  static double calculateTotalSales(List<Transaction> transactions) {
    return transactions.fold<double>(0, (sum, t) => sum + t.total);
  }

  /// Calculate total expenses from a list of expenses
  static double calculateTotalExpenses(List<Expense> expenses) {
    return expenses.fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Calculate profit: total sales - total expenses
  static double calculateProfit(
    List<Transaction> transactions,
    List<Expense> expenses,
  ) {
    final totalSales = calculateTotalSales(transactions);
    final totalExpenses = calculateTotalExpenses(expenses);
    return totalSales - totalExpenses;
  }

  /// Filter transactions by date range (inclusive)
  static List<Transaction> filterTransactionsByDateRange(
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

  /// Filter expenses by date range (inclusive)
  static List<Expense> filterExpensesByDateRange(
    List<Expense> expenses,
    DateTime startDate,
    DateTime endDate,
  ) {
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    return expenses.where((e) {
      return !e.date.isBefore(normalizedStart) &&
          !e.date.isAfter(normalizedEnd);
    }).toList();
  }

  /// Calculate profit for a specific date range
  static ProfitResult calculateProfitForPeriod(
    List<Transaction> allTransactions,
    List<Expense> allExpenses,
    DateTime startDate,
    DateTime endDate,
  ) {
    final filteredTransactions =
        filterTransactionsByDateRange(allTransactions, startDate, endDate);
    final filteredExpenses =
        filterExpensesByDateRange(allExpenses, startDate, endDate);

    final totalSales = calculateTotalSales(filteredTransactions);
    final totalExpenses = calculateTotalExpenses(filteredExpenses);
    final profit = totalSales - totalExpenses;

    return ProfitResult(
      transactions: filteredTransactions,
      expenses: filteredExpenses,
      totalSales: totalSales,
      totalExpenses: totalExpenses,
      profit: profit,
    );
  }
}

class ProfitResult {
  final List<Transaction> transactions;
  final List<Expense> expenses;
  final double totalSales;
  final double totalExpenses;
  final double profit;

  ProfitResult({
    required this.transactions,
    required this.expenses,
    required this.totalSales,
    required this.totalExpenses,
    required this.profit,
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

/// Generator for valid Expense instances
extension ExpenseGenerator on Any {
  Generator<Expense> get expense {
    return any.lowercaseLetters.bind((category) {
      return any.doubleInRange(10000.0, 500000.0).bind((amount) {
        return any.intInRange(0, 30).map((daysAgo) {
          final categories = [
            'Bahan Baku',
            'Listrik',
            'Gaji',
            'Sewa',
            'Lainnya'
          ];
          final categoryName =
              categories[category.hashCode.abs() % categories.length];
          final date = DateTime.now().subtract(Duration(days: daysAgo));

          return Expense(
            id: 'exp-${DateTime.now().microsecondsSinceEpoch}-${category.hashCode.abs()}',
            tenantId: 'tenant-test',
            category: categoryName,
            amount: amount,
            description: 'Test expense',
            date: date,
            createdAt: date,
          );
        });
      });
    });
  }
}

/// Generator for a list of expenses (3-5 expenses)
extension ExpensesListGenerator on Any {
  Generator<List<Expense>> get expensesList {
    return any.expense.bind((e1) {
      return any.expense.bind((e2) {
        return any.expense.bind((e3) {
          return any.expense.bind((e4) {
            return any.expense.map((e5) {
              return [e1, e2, e3, e4, e5];
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
    return any.intInRange(0, 30).bind((days1) {
      return any.intInRange(0, 30).map((days2) {
        final now = DateTime.now();
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
  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3, 6.5**
  ///
  /// Property: Profit equals total sales minus total expenses
  Glados2(any.transactionsList, any.expensesList).test(
    'Profit equals total sales minus total expenses',
    (transactions, expenses) {
      final totalSales = ProfitCalculator.calculateTotalSales(transactions);
      final totalExpenses = ProfitCalculator.calculateTotalExpenses(expenses);
      final profit = ProfitCalculator.calculateProfit(transactions, expenses);

      final expectedProfit = totalSales - totalExpenses;

      if ((profit - expectedProfit).abs() > 0.001) {
        throw Exception(
            'Profit mismatch: got $profit, expected $expectedProfit (sales: $totalSales, expenses: $totalExpenses)');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3**
  ///
  /// Property: Profit with no expenses equals total sales
  Glados(any.transactionsList).test(
    'Profit with no expenses equals total sales',
    (transactions) {
      final totalSales = ProfitCalculator.calculateTotalSales(transactions);
      final profit = ProfitCalculator.calculateProfit(transactions, []);

      if ((profit - totalSales).abs() > 0.001) {
        throw Exception(
            'Profit with no expenses should equal total sales: got $profit, expected $totalSales');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 6.5**
  ///
  /// Property: Profit with no sales equals negative total expenses
  Glados(any.expensesList).test(
    'Profit with no sales equals negative total expenses',
    (expenses) {
      final totalExpenses = ProfitCalculator.calculateTotalExpenses(expenses);
      final profit = ProfitCalculator.calculateProfit([], expenses);

      final expectedProfit = -totalExpenses;

      if ((profit - expectedProfit).abs() > 0.001) {
        throw Exception(
            'Profit with no sales should equal negative expenses: got $profit, expected $expectedProfit');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3, 6.5**
  ///
  /// Property: Empty transactions and expenses result in zero profit
  Glados(any.dateRange).test(
    'Empty transactions and expenses result in zero profit',
    (dateRange) {
      final (startDate, endDate) = dateRange;
      final result = ProfitCalculator.calculateProfitForPeriod(
        [],
        [],
        startDate,
        endDate,
      );

      if (result.profit != 0) {
        throw Exception('Empty data should have zero profit: ${result.profit}');
      }
      if (result.totalSales != 0) {
        throw Exception(
            'Empty data should have zero sales: ${result.totalSales}');
      }
      if (result.totalExpenses != 0) {
        throw Exception(
            'Empty data should have zero expenses: ${result.totalExpenses}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3, 6.5**
  ///
  /// Property: Profit for period equals filtered sales minus filtered expenses
  Glados3(any.transactionsList, any.expensesList, any.dateRange).test(
    'Profit for period equals filtered sales minus filtered expenses',
    (transactions, expenses, dateRange) {
      final (startDate, endDate) = dateRange;
      final result = ProfitCalculator.calculateProfitForPeriod(
        transactions,
        expenses,
        startDate,
        endDate,
      );

      final expectedProfit = result.totalSales - result.totalExpenses;

      if ((result.profit - expectedProfit).abs() > 0.001) {
        throw Exception(
            'Period profit mismatch: got ${result.profit}, expected $expectedProfit');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3**
  ///
  /// Property: Total sales is sum of all transaction totals
  Glados(any.transactionsList).test(
    'Total sales is sum of all transaction totals',
    (transactions) {
      final totalSales = ProfitCalculator.calculateTotalSales(transactions);
      final expectedTotal =
          transactions.fold<double>(0, (sum, t) => sum + t.total);

      if ((totalSales - expectedTotal).abs() > 0.001) {
        throw Exception(
            'Total sales mismatch: got $totalSales, expected $expectedTotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 6.5**
  ///
  /// Property: Total expenses is sum of all expense amounts
  Glados(any.expensesList).test(
    'Total expenses is sum of all expense amounts',
    (expenses) {
      final totalExpenses = ProfitCalculator.calculateTotalExpenses(expenses);
      final expectedTotal =
          expenses.fold<double>(0, (sum, e) => sum + e.amount);

      if ((totalExpenses - expectedTotal).abs() > 0.001) {
        throw Exception(
            'Total expenses mismatch: got $totalExpenses, expected $expectedTotal');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3, 6.5**
  ///
  /// Property: Adding an expense decreases profit by that amount
  Glados2(any.transactionsList, any.expense).test(
    'Adding an expense decreases profit by that amount',
    (transactions, newExpense) {
      final profitBefore = ProfitCalculator.calculateProfit(transactions, []);
      final profitAfter =
          ProfitCalculator.calculateProfit(transactions, [newExpense]);

      final expectedDecrease = newExpense.amount;
      final actualDecrease = profitBefore - profitAfter;

      if ((actualDecrease - expectedDecrease).abs() > 0.001) {
        throw Exception(
            'Adding expense should decrease profit by ${newExpense.amount}: got decrease of $actualDecrease');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 5: Profit Calculation Correctness**
  /// **Validates: Requirements 5.3, 6.5**
  ///
  /// Property: Adding a transaction increases profit by that amount
  Glados2(any.expensesList, any.transaction).test(
    'Adding a transaction increases profit by that amount',
    (expenses, newTransaction) {
      final profitBefore = ProfitCalculator.calculateProfit([], expenses);
      final profitAfter =
          ProfitCalculator.calculateProfit([newTransaction], expenses);

      final expectedIncrease = newTransaction.total;
      final actualIncrease = profitAfter - profitBefore;

      if ((actualIncrease - expectedIncrease).abs() > 0.001) {
        throw Exception(
            'Adding transaction should increase profit by ${newTransaction.total}: got increase of $actualIncrease');
      }
    },
  );
}
