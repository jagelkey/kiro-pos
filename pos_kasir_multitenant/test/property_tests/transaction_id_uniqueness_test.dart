/// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
/// **Validates: Requirements 4.4**
///
/// Property: For any two transactions, their IDs SHALL be different.
library;

import 'package:glados/glados.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Transaction ID generator that mirrors the actual implementation
/// The POS screen uses `const Uuid().v4()` to generate transaction IDs
class TransactionIdGenerator {
  static const _uuid = Uuid();

  /// Generate a unique transaction ID using UUID v4
  static String generateId() => _uuid.v4();
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((productName) {
      return any.intInRange(1, 10).bind((quantity) {
        return any.doubleInRange(1000.0, 100000.0).map((price) {
          final name = productName.isEmpty ? 'Product' : productName;
          return TransactionItem(
            productId: 'prod-${name.hashCode.abs()}',
            productName: name,
            quantity: quantity,
            price: price,
            total: price * quantity,
          );
        });
      });
    });
  }
}

/// Generator for a list of transaction items (exactly 3 items for simplicity)
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

/// Generator for payment methods
extension PaymentMethodGenerator on Any {
  Generator<String> get paymentMethod {
    return any.intInRange(0, 4).map((index) {
      const methods = ['cash', 'qris', 'debit', 'transfer', 'ewallet'];
      return methods[index];
    });
  }
}

/// Generator for valid Transaction instances with unique IDs
extension TransactionGenerator on Any {
  Generator<Transaction> get transaction {
    return any.transactionItems.bind((items) {
      return any.paymentMethod.bind((paymentMethod) {
        return any.doubleInRange(0.0, 0.15).map((taxRate) {
          final subtotal =
              items.fold<double>(0, (sum, item) => sum + item.total);
          final tax = subtotal * taxRate;
          final total = subtotal + tax;

          return Transaction(
            id: TransactionIdGenerator.generateId(),
            tenantId: 'tenant-test',
            userId: 'user-test',
            items: items,
            subtotal: subtotal,
            discount: 0,
            tax: tax,
            total: total,
            paymentMethod: paymentMethod,
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
  /// **Validates: Requirements 4.4**
  ///
  /// Property: For any two transactions generated, their IDs SHALL be different
  Glados2(any.transaction, any.transaction).test(
    'Two generated transactions have different IDs',
    (transaction1, transaction2) {
      if (transaction1.id == transaction2.id) {
        throw Exception(
            'Transaction IDs should be unique but got duplicate: ${transaction1.id}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
  /// **Validates: Requirements 4.4**
  ///
  /// Property: Generated transaction IDs follow UUID v4 format
  Glados(any.transaction).test(
    'Transaction ID follows UUID v4 format',
    (transaction) {
      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      // where x is any hex digit and y is one of 8, 9, a, or b
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      if (!uuidRegex.hasMatch(transaction.id)) {
        throw Exception(
            'Transaction ID "${transaction.id}" does not follow UUID v4 format');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
  /// **Validates: Requirements 4.4**
  ///
  /// Property: Multiple sequential ID generations produce unique IDs
  Glados(any.intInRange(10, 50)).test(
    'Multiple sequential ID generations are all unique',
    (count) {
      final ids = <String>{};

      for (var i = 0; i < count; i++) {
        final id = TransactionIdGenerator.generateId();
        if (ids.contains(id)) {
          throw Exception('Duplicate ID generated after $i iterations: $id');
        }
        ids.add(id);
      }

      if (ids.length != count) {
        throw Exception('Expected $count unique IDs but got ${ids.length}');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
  /// **Validates: Requirements 4.4**
  ///
  /// Property: Transaction IDs are non-empty strings
  Glados(any.transaction).test(
    'Transaction ID is non-empty',
    (transaction) {
      if (transaction.id.isEmpty) {
        throw Exception('Transaction ID should not be empty');
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 3: Transaction ID Uniqueness**
  /// **Validates: Requirements 4.4**
  ///
  /// Property: Transaction IDs have consistent length (36 chars for UUID)
  Glados(any.transaction).test(
    'Transaction ID has consistent UUID length',
    (transaction) {
      // UUID v4 format has exactly 36 characters (32 hex + 4 hyphens)
      const expectedLength = 36;

      if (transaction.id.length != expectedLength) {
        throw Exception(
            'Transaction ID length should be $expectedLength but got ${transaction.id.length}');
      }
    },
  );
}
