/// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
/// **Validates: Requirements 13.5**
///
/// Property: For any transaction created during an active shift, the transaction
/// SHALL have shift_id set to the active shift's ID.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/shift.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';
import 'package:uuid/uuid.dart';

/// Shift-Transaction Association Logic
/// Requirements 13.5: Associate all transactions with active shift record
class ShiftTransactionAssociator {
  /// Associate a transaction with an active shift
  /// Returns a new transaction with the shift_id set if shift is active
  static Transaction associateWithShift(
    Transaction transaction,
    Shift? activeShift,
  ) {
    if (activeShift == null || !activeShift.isActive) {
      // No active shift, transaction has no shift association
      return transaction;
    }

    // Associate transaction with the active shift
    return transaction.copyWith(shiftId: activeShift.id);
  }

  /// Check if a transaction is properly associated with a shift
  static bool isProperlyAssociated(
    Transaction transaction,
    Shift? activeShift,
  ) {
    if (activeShift == null || !activeShift.isActive) {
      // No active shift - transaction should have no shift_id
      return transaction.shiftId == null;
    }

    // Active shift exists - transaction should have matching shift_id
    return transaction.shiftId == activeShift.id;
  }

  /// Validate that all transactions in a shift have correct shift_id
  static bool validateShiftTransactions(
    List<Transaction> transactions,
    Shift shift,
  ) {
    return transactions.every((t) => t.shiftId == shift.id);
  }
}

/// Generator for valid tenant IDs
extension TenantIdGenerator on Any {
  Generator<String> get tenantId {
    return any.intInRange(1, 1000).map((i) => 'tenant-$i');
  }
}

/// Generator for valid user IDs
extension UserIdGenerator on Any {
  Generator<String> get userId {
    return any.intInRange(1, 1000).map((i) => 'user-$i');
  }
}

/// Generator for valid shift IDs
extension ShiftIdGenerator on Any {
  Generator<String> get shiftId {
    return any.intInRange(1, 10000).map((i) => 'shift-$i');
  }
}

/// Generator for valid transaction totals (positive amounts)
extension TransactionTotalGenerator on Any {
  Generator<double> get transactionTotal {
    return any.doubleInRange(1000.0, 1000000.0);
  }
}

/// Generator for opening cash amounts
extension OpeningCashGenerator on Any {
  Generator<double> get openingCash {
    return any.doubleInRange(100000.0, 5000000.0);
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

/// Generator for an active shift
extension ActiveShiftGenerator on Any {
  Generator<Shift> activeShift(String tenantId, String userId) {
    return any.shiftId.bind((shiftId) {
      return any.openingCash.map((openingCash) {
        return Shift(
          id: shiftId,
          tenantId: tenantId,
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          openingCash: openingCash,
          status: ShiftStatus.active,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        );
      });
    });
  }
}

/// Generator for a closed shift
extension ClosedShiftGenerator on Any {
  Generator<Shift> closedShift(String tenantId, String userId) {
    return any.shiftId.bind((shiftId) {
      return any.openingCash.map((openingCash) {
        return Shift(
          id: shiftId,
          tenantId: tenantId,
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(hours: 8)),
          endTime: DateTime.now().subtract(const Duration(hours: 1)),
          openingCash: openingCash,
          closingCash: openingCash + 500000,
          expectedCash: openingCash + 500000,
          variance: 0,
          status: ShiftStatus.closed,
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        );
      });
    });
  }
}

/// Generator for a transaction without shift association
extension TransactionWithoutShiftGenerator on Any {
  Generator<Transaction> transactionWithoutShift(String tenantId) {
    return any.transactionTotal.bind((total) {
      return any.paymentMethod.map((paymentMethod) {
        return Transaction(
          id: const Uuid().v4(),
          tenantId: tenantId,
          userId: 'user-test',
          shiftId: null, // No shift association initially
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
          tax: total * 0.11,
          total: total * 1.11,
          paymentMethod: paymentMethod,
          createdAt: DateTime.now(),
        );
      });
    });
  }
}

void main() {
  const testTenantId = 'tenant-test';
  const testUserId = 'user-test';

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: Transaction created during active shift has shift_id set to active shift's ID
  Glados2(
    any.activeShift(testTenantId, testUserId),
    any.transactionWithoutShift(testTenantId),
  ).test(
    'Transaction during active shift has shift_id set to active shift ID',
    (activeShift, transaction) {
      // Associate transaction with active shift
      final associatedTransaction =
          ShiftTransactionAssociator.associateWithShift(
        transaction,
        activeShift,
      );

      // Verify shift_id is set to active shift's ID
      if (associatedTransaction.shiftId != activeShift.id) {
        throw Exception(
          'Transaction should have shift_id set to active shift ID: '
          'expected ${activeShift.id}, got ${associatedTransaction.shiftId}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: Transaction created without active shift has null shift_id
  Glados(any.transactionWithoutShift(testTenantId)).test(
    'Transaction without active shift has null shift_id',
    (transaction) {
      // Associate transaction with no shift (null)
      final associatedTransaction =
          ShiftTransactionAssociator.associateWithShift(
        transaction,
        null,
      );

      // Verify shift_id remains null
      if (associatedTransaction.shiftId != null) {
        throw Exception(
          'Transaction without active shift should have null shift_id: '
          'got ${associatedTransaction.shiftId}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: Transaction created during closed shift has null shift_id
  Glados2(
    any.closedShift(testTenantId, testUserId),
    any.transactionWithoutShift(testTenantId),
  ).test(
    'Transaction during closed shift has null shift_id',
    (closedShift, transaction) {
      // Associate transaction with closed shift (should not associate)
      final associatedTransaction =
          ShiftTransactionAssociator.associateWithShift(
        transaction,
        closedShift,
      );

      // Verify shift_id is null (closed shift should not be associated)
      if (associatedTransaction.shiftId != null) {
        throw Exception(
          'Transaction during closed shift should have null shift_id: '
          'got ${associatedTransaction.shiftId}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: isProperlyAssociated returns true for correctly associated transactions
  Glados2(
    any.activeShift(testTenantId, testUserId),
    any.transactionWithoutShift(testTenantId),
  ).test(
    'isProperlyAssociated returns true for correctly associated transactions',
    (activeShift, transaction) {
      // Associate transaction with active shift
      final associatedTransaction =
          ShiftTransactionAssociator.associateWithShift(
        transaction,
        activeShift,
      );

      // Verify isProperlyAssociated returns true
      final isProper = ShiftTransactionAssociator.isProperlyAssociated(
        associatedTransaction,
        activeShift,
      );

      if (!isProper) {
        throw Exception(
          'isProperlyAssociated should return true for correctly associated transaction',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: isProperlyAssociated returns false for incorrectly associated transactions
  Glados2(
    any.activeShift(testTenantId, testUserId),
    any.transactionWithoutShift(testTenantId),
  ).test(
    'isProperlyAssociated returns false for incorrectly associated transactions',
    (activeShift, transaction) {
      // Transaction without shift association when there's an active shift
      final isProper = ShiftTransactionAssociator.isProperlyAssociated(
        transaction, // Has null shiftId
        activeShift, // Active shift exists
      );

      if (isProper) {
        throw Exception(
          'isProperlyAssociated should return false when transaction has null shift_id '
          'but active shift exists',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: All transactions in a shift have the same shift_id
  Glados(any.activeShift(testTenantId, testUserId)).test(
    'All transactions in a shift have the same shift_id',
    (activeShift) {
      // Create multiple transactions and associate them with the shift
      final transactions = List.generate(5, (index) {
        final baseTxn = Transaction(
          id: 'txn-$index',
          tenantId: testTenantId,
          userId: testUserId,
          shiftId: null,
          items: [
            TransactionItem(
              productId: 'prod-$index',
              productName: 'Product $index',
              quantity: 1,
              price: 10000.0 * (index + 1),
              total: 10000.0 * (index + 1),
            ),
          ],
          subtotal: 10000.0 * (index + 1),
          total: 10000.0 * (index + 1),
          paymentMethod: 'cash',
          createdAt: DateTime.now(),
        );
        return ShiftTransactionAssociator.associateWithShift(
            baseTxn, activeShift);
      });

      // Validate all transactions have the same shift_id
      final isValid = ShiftTransactionAssociator.validateShiftTransactions(
        transactions,
        activeShift,
      );

      if (!isValid) {
        throw Exception(
          'All transactions in a shift should have the same shift_id',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 14: Shift Transaction Association**
  /// **Validates: Requirements 13.5**
  ///
  /// Property: Transaction preserves all other fields when associating with shift
  Glados2(
    any.activeShift(testTenantId, testUserId),
    any.transactionWithoutShift(testTenantId),
  ).test(
    'Transaction preserves all other fields when associating with shift',
    (activeShift, transaction) {
      // Associate transaction with active shift
      final associatedTransaction =
          ShiftTransactionAssociator.associateWithShift(
        transaction,
        activeShift,
      );

      // Verify all other fields are preserved
      if (associatedTransaction.id != transaction.id) {
        throw Exception('Transaction id should be preserved');
      }
      if (associatedTransaction.tenantId != transaction.tenantId) {
        throw Exception('Transaction tenantId should be preserved');
      }
      if (associatedTransaction.userId != transaction.userId) {
        throw Exception('Transaction userId should be preserved');
      }
      if (associatedTransaction.subtotal != transaction.subtotal) {
        throw Exception('Transaction subtotal should be preserved');
      }
      if (associatedTransaction.total != transaction.total) {
        throw Exception('Transaction total should be preserved');
      }
      if (associatedTransaction.paymentMethod != transaction.paymentMethod) {
        throw Exception('Transaction paymentMethod should be preserved');
      }
      if (associatedTransaction.items.length != transaction.items.length) {
        throw Exception('Transaction items should be preserved');
      }
    },
  );
}
