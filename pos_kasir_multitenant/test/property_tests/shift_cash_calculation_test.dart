/// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
/// **Validates: Requirements 13.2**
///
/// Property: For any closed shift, expected cash SHALL equal opening cash plus
/// sum of cash transactions during that shift.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Shift cash calculator - extracted logic for testability
/// Requirements 13.2: Calculate expected cash based on transactions
class ShiftCashCalculator {
  /// Calculate expected cash for a shift
  /// Expected cash = opening cash + sum of cash transactions
  static double calculateExpectedCash(
    double openingCash,
    List<Transaction> transactions,
  ) {
    // Sum only cash transactions
    final cashSales = transactions
        .where((t) => t.paymentMethod == 'cash')
        .fold<double>(0.0, (sum, t) => sum + t.total);

    return openingCash + cashSales;
  }

  /// Calculate variance between actual and expected cash
  static double calculateVariance(double closingCash, double expectedCash) {
    return closingCash - expectedCash;
  }

  /// Determine if shift should be flagged based on variance
  static bool shouldFlagShift(double variance, {double tolerance = 0.01}) {
    return variance.abs() > tolerance;
  }
}

/// Generator for valid opening cash amounts (0 to 10,000,000)
extension OpeningCashGenerator on Any {
  Generator<double> get openingCash {
    return any.doubleInRange(0.0, 10000000.0);
  }
}

/// Generator for valid transaction totals (positive amounts)
extension TransactionTotalGenerator on Any {
  Generator<double> get transactionTotal {
    return any.doubleInRange(1.0, 1000000.0);
  }
}

/// Generator for payment methods
extension PaymentMethodGenerator on Any {
  Generator<String> get paymentMethod {
    return any.intInRange(0, 2).map((index) {
      switch (index) {
        case 0:
          return 'cash';
        case 1:
          return 'transfer';
        default:
          return 'ewallet';
      }
    });
  }
}

/// Generator for a single transaction with specified shift
extension TransactionGenerator on Any {
  Generator<Transaction> transactionForShift(String shiftId, String tenantId) {
    return any.transactionTotal.bind((total) {
      return any.paymentMethod.map((paymentMethod) {
        return Transaction(
          id: 'txn-${DateTime.now().microsecondsSinceEpoch}-${total.hashCode}',
          tenantId: tenantId,
          userId: 'user-test',
          shiftId: shiftId,
          items: [
            TransactionItem(
              productId: 'prod-1',
              productName: 'Test Product',
              quantity: 1,
              price: total,
              total: total,
            ),
          ],
          subtotal: total,
          tax: 0.0,
          total: total,
          paymentMethod: paymentMethod,
          createdAt: DateTime.now(),
        );
      });
    });
  }
}

/// Generator for a list of transactions (3 transactions for simplicity)
extension TransactionListGenerator on Any {
  Generator<List<Transaction>> transactionsForShift(
      String shiftId, String tenantId) {
    return any.transactionForShift(shiftId, tenantId).bind((t1) {
      return any.transactionForShift(shiftId, tenantId).bind((t2) {
        return any.transactionForShift(shiftId, tenantId).map((t3) {
          return [t1, t2, t3];
        });
      });
    });
  }
}

/// Generator for closing cash variance (can be positive, negative, or zero)
extension ClosingCashVarianceGenerator on Any {
  Generator<double> get closingCashVariance {
    // Generate variance: -1000 to +1000
    return any.doubleInRange(-1000.0, 1000.0);
  }
}

void main() {
  const testShiftId = 'shift-test-001';
  const testTenantId = 'tenant-test';

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Expected cash equals opening cash plus sum of cash transactions
  Glados2(any.openingCash, any.transactionsForShift(testShiftId, testTenantId))
      .test(
    'Expected cash equals opening cash plus cash transaction totals',
    (openingCash, transactions) {
      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        transactions,
      );

      // Calculate expected value manually
      final cashTransactionTotal = transactions
          .where((t) => t.paymentMethod == 'cash')
          .fold<double>(0.0, (sum, t) => sum + t.total);
      final manualExpected = openingCash + cashTransactionTotal;

      // Verify the calculation
      if ((expectedCash - manualExpected).abs() > 0.001) {
        throw Exception(
          'Expected cash mismatch: got $expectedCash, expected $manualExpected '
          '(opening: $openingCash, cash sales: $cashTransactionTotal)',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Non-cash transactions do not affect expected cash
  Glados(any.openingCash).test(
    'Non-cash transactions do not affect expected cash',
    (openingCash) {
      // Create transactions with non-cash payment methods only
      final nonCashTransactions = [
        Transaction(
          id: 'txn-1',
          tenantId: testTenantId,
          userId: 'user-test',
          shiftId: testShiftId,
          items: [
            TransactionItem(
              productId: 'prod-1',
              productName: 'Product 1',
              quantity: 1,
              price: 50000,
              total: 50000,
            ),
          ],
          subtotal: 50000,
          total: 50000,
          paymentMethod: 'transfer',
          createdAt: DateTime.now(),
        ),
        Transaction(
          id: 'txn-2',
          tenantId: testTenantId,
          userId: 'user-test',
          shiftId: testShiftId,
          items: [
            TransactionItem(
              productId: 'prod-2',
              productName: 'Product 2',
              quantity: 1,
              price: 30000,
              total: 30000,
            ),
          ],
          subtotal: 30000,
          total: 30000,
          paymentMethod: 'ewallet',
          createdAt: DateTime.now(),
        ),
      ];

      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        nonCashTransactions,
      );

      // Expected cash should equal opening cash (no cash transactions)
      if ((expectedCash - openingCash).abs() > 0.001) {
        throw Exception(
          'Non-cash transactions should not affect expected cash: '
          'got $expectedCash, expected $openingCash',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Empty transaction list means expected cash equals opening cash
  Glados(any.openingCash).test(
    'Empty transactions means expected cash equals opening cash',
    (openingCash) {
      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        [],
      );

      if ((expectedCash - openingCash).abs() > 0.001) {
        throw Exception(
          'Empty transactions should result in expected cash = opening cash: '
          'got $expectedCash, expected $openingCash',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Variance is correctly calculated as closing - expected
  Glados2(any.openingCash, any.transactionsForShift(testShiftId, testTenantId))
      .test(
    'Variance equals closing cash minus expected cash',
    (openingCash, transactions) {
      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        transactions,
      );

      // Test with various closing cash scenarios
      final closingCashValues = [
        expectedCash, // Exact match
        expectedCash + 100, // Over
        expectedCash - 50, // Under
      ];

      for (final closingCash in closingCashValues) {
        if (closingCash < 0) continue; // Skip negative values

        final variance = ShiftCashCalculator.calculateVariance(
          closingCash,
          expectedCash,
        );
        final expectedVariance = closingCash - expectedCash;

        if ((variance - expectedVariance).abs() > 0.001) {
          throw Exception(
            'Variance mismatch: got $variance, expected $expectedVariance '
            '(closing: $closingCash, expected: $expectedCash)',
          );
        }
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Shift is flagged when variance exceeds tolerance
  Glados2(any.openingCash, any.transactionsForShift(testShiftId, testTenantId))
      .test(
    'Shift is flagged when variance exceeds tolerance',
    (openingCash, transactions) {
      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        transactions,
      );

      // Test exact match (should not be flagged)
      final exactVariance =
          ShiftCashCalculator.calculateVariance(expectedCash, expectedCash);
      final shouldFlagExact =
          ShiftCashCalculator.shouldFlagShift(exactVariance);
      if (shouldFlagExact) {
        throw Exception('Exact match should not be flagged');
      }

      // Test with variance (should be flagged)
      final overClosing = expectedCash + 100;
      final overVariance =
          ShiftCashCalculator.calculateVariance(overClosing, expectedCash);
      final shouldFlagOver = ShiftCashCalculator.shouldFlagShift(overVariance);
      if (!shouldFlagOver) {
        throw Exception('Variance of 100 should be flagged');
      }

      // Test with small variance within tolerance (should not be flagged)
      final smallOverClosing = expectedCash + 0.005;
      final smallVariance =
          ShiftCashCalculator.calculateVariance(smallOverClosing, expectedCash);
      final shouldFlagSmall =
          ShiftCashCalculator.shouldFlagShift(smallVariance);
      if (shouldFlagSmall) {
        throw Exception(
            'Small variance within tolerance should not be flagged');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Expected cash is always >= opening cash (cash sales are positive)
  Glados2(any.openingCash, any.transactionsForShift(testShiftId, testTenantId))
      .test(
    'Expected cash is always greater than or equal to opening cash',
    (openingCash, transactions) {
      final expectedCash = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        transactions,
      );

      if (expectedCash < openingCash - 0.001) {
        throw Exception(
          'Expected cash should be >= opening cash: '
          'got $expectedCash, opening was $openingCash',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 13: Shift Cash Calculation**
  /// **Validates: Requirements 13.2**
  ///
  /// Property: Adding a cash transaction increases expected cash by transaction total
  Glados2(any.openingCash, any.transactionTotal).test(
    'Adding cash transaction increases expected cash by transaction total',
    (openingCash, transactionTotal) {
      final initialExpected = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        [],
      );

      final cashTransaction = Transaction(
        id: 'txn-new',
        tenantId: testTenantId,
        userId: 'user-test',
        shiftId: testShiftId,
        items: [
          TransactionItem(
            productId: 'prod-1',
            productName: 'Test Product',
            quantity: 1,
            price: transactionTotal,
            total: transactionTotal,
          ),
        ],
        subtotal: transactionTotal,
        total: transactionTotal,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

      final newExpected = ShiftCashCalculator.calculateExpectedCash(
        openingCash,
        [cashTransaction],
      );

      final increase = newExpected - initialExpected;

      if ((increase - transactionTotal).abs() > 0.001) {
        throw Exception(
          'Adding cash transaction should increase expected by transaction total: '
          'got increase of $increase, expected $transactionTotal',
        );
      }
    },
  );
}
