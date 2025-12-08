import 'package:flutter_test/flutter_test.dart';
import 'package:pos_kasir_multitenant/core/utils/auth_guard.dart';
import 'package:pos_kasir_multitenant/core/utils/money.dart';
import 'package:pos_kasir_multitenant/features/auth/auth_provider.dart';
import 'package:pos_kasir_multitenant/data/models/user.dart';

void main() {
  group('Critical Fixes Validation', () {
    group('Auth Guard Tests', () {
      test('requireUser throws when user is null', () {
        final authState = AuthState(user: null);
        expect(
          () => AuthGuard.requireUser(authState),
          throwsA(isA<AuthException>()),
        );
      });

      test('requireUser returns user when not null', () {
        final authState = AuthState(
          user: User(
            id: 'test-id',
            tenantId: 'tenant-id',
            email: 'test@example.com',
            name: 'Test User',
            role: UserRole.cashier,
            isActive: true,
            passwordHash: 'hash',
            createdAt: DateTime.now(),
          ),
        );

        final user = AuthGuard.requireUser(authState);
        expect(user.id, equals('test-id'));
        expect(user.email, equals('test@example.com'));
      });

      test('requireTenant throws when tenant is null', () {
        final authState = AuthState(tenant: null);
        expect(
          () => AuthGuard.requireTenant(authState),
          throwsA(isA<AuthException>()),
        );
      });

      test('requireRole throws when user has wrong role', () {
        final user = User(
          id: 'test-id',
          tenantId: 'tenant-id',
          email: 'test@example.com',
          name: 'Test User',
          role: UserRole.cashier,
          isActive: true,
          passwordHash: 'hash',
          createdAt: DateTime.now(),
        );

        expect(
          () => AuthGuard.requireRole(user, [UserRole.owner]),
          throwsA(isA<AuthException>()),
        );
      });

      test('requireRole succeeds when user has correct role', () {
        final user = User(
          id: 'test-id',
          tenantId: 'tenant-id',
          email: 'test@example.com',
          name: 'Test User',
          role: UserRole.owner,
          isActive: true,
          passwordHash: 'hash',
          createdAt: DateTime.now(),
        );

        expect(
          () => AuthGuard.requireRole(user, [UserRole.owner]),
          returnsNormally,
        );
      });
    });

    group('Money Precision Tests', () {
      test('Money calculations are precise', () {
        final price = Money(10.10);
        const quantity = 3;
        final total = price * quantity;

        expect(total.amount, equals(30.30));
        expect(total.cents, equals(3030));
      });

      test('Money avoids floating point errors', () {
        final a = Money(0.1);
        final b = Money(0.2);
        final sum = a + b;

        // This would be 0.30000000000000004 with double
        expect(sum.amount, equals(0.3));
        expect(sum.cents, equals(30));
      });

      test('Money percentage calculation is accurate', () {
        final amount = Money(100);
        final discount = amount.percentage(10);

        expect(discount.amount, equals(10.0));
        expect(discount.cents, equals(1000));
      });

      test('Money comparison works correctly', () {
        final a = Money(10.50);
        final b = Money(10.51);
        final c = Money(10.50);

        expect(a < b, true);
        expect(b > a, true);
        expect(a == c, true);
        expect(a >= c, true);
        expect(a <= c, true);
      });

      test('Money format displays correctly', () {
        final amount = Money(1000000);
        final formatted = amount.format();

        expect(formatted, contains('Rp'));
        expect(formatted, contains('1.000.000'));
      });

      test('Money arithmetic operations', () {
        final a = Money(100);
        final b = Money(50);

        expect((a + b).amount, equals(150));
        expect((a - b).amount, equals(50));
        expect((a * 2).amount, equals(200));
        expect((a / 2).amount, equals(50));
      });

      test('Money zero value', () {
        final zero = Money.zero();
        expect(zero.amount, equals(0));
        expect(zero.cents, equals(0));
      });

      test('Money from cents constructor', () {
        final money = Money.fromCents(12345);
        expect(money.amount, equals(123.45));
        expect(money.cents, equals(12345));
      });

      test('Money handles negative values', () {
        final negative = Money(-50);
        expect(negative.amount, equals(-50));
        expect(negative.cents, equals(-5000));
      });

      test('Money JSON serialization', () {
        final money = Money(123.45);
        final json = money.toJson();

        expect(json['cents'], equals(12345));

        final restored = Money.fromJson(json);
        expect(restored.amount, equals(123.45));
        expect(restored == money, true);
      });
    });
  });

  group('Integration Tests', () {
    test('Complete checkout flow with Money', () {
      // Simulate cart items
      final item1Price = Money(15000);
      const item1Qty = 2;
      final item1Total = item1Price * item1Qty;

      final item2Price = Money(25000);
      const item2Qty = 1;
      final item2Total = item2Price * item2Qty;

      // Calculate subtotal
      final subtotal = item1Total + item2Total;
      expect(subtotal.amount, equals(55000));

      // Apply discount
      final discount = subtotal.percentage(10);
      expect(discount.amount, equals(5500));

      // Calculate total
      final total = subtotal - discount;
      expect(total.amount, equals(49500));

      // No floating point errors
      expect(total.cents, equals(4950000));
    });

    test('Complex money calculations', () {
      // Test realistic POS scenario
      final prices = [
        Money(12500), // Item 1
        Money(8750), // Item 2
        Money(15000), // Item 3
      ];

      var total = Money.zero();
      for (final price in prices) {
        total = total + price;
      }

      expect(total.amount, equals(36250));

      // Apply 15% discount
      final discount = total.percentage(15);
      expect(discount.amount, equals(5437.5));

      final finalTotal = total - discount;
      expect(finalTotal.amount, equals(30812.5));
    });

    test('Money calculations with tax', () {
      final subtotal = Money(100000);
      final tax = subtotal.percentage(10); // 10% tax
      final total = subtotal + tax;

      expect(tax.amount, equals(10000));
      expect(total.amount, equals(110000));
    });

    test('Multiple discounts scenario', () {
      final price = Money(100000);

      // First discount: 10%
      final discount1 = price.percentage(10);
      final afterDiscount1 = price - discount1;
      expect(afterDiscount1.amount, equals(90000));

      // Second discount: 5% of discounted price
      final discount2 = afterDiscount1.percentage(5);
      final finalPrice = afterDiscount1 - discount2;
      expect(finalPrice.amount, equals(85500));
    });
  });
}
