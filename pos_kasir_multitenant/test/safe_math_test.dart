import 'package:flutter_test/flutter_test.dart';
import 'package:pos_kasir_multitenant/core/utils/safe_math.dart';

void main() {
  group('SafeMath Tests', () {
    group('safeDivide', () {
      test('normal division works', () {
        expect(SafeMath.safeDivide(10, 2), equals(5.0));
        expect(SafeMath.safeDivide(100, 4), equals(25.0));
      });

      test('division by zero returns default', () {
        expect(SafeMath.safeDivide(10, 0), equals(0.0));
        expect(SafeMath.safeDivide(10, 0, defaultValue: -1), equals(-1.0));
      });

      test('handles NaN and Infinity', () {
        expect(SafeMath.safeDivide(10, double.nan), equals(0.0));
        expect(SafeMath.safeDivide(10, double.infinity), equals(0.0));
      });
    });

    group('safePercentage', () {
      test('calculates percentage correctly', () {
        expect(SafeMath.safePercentage(50, 100), equals(50.0));
        expect(SafeMath.safePercentage(25, 100), equals(25.0));
        expect(SafeMath.safePercentage(1, 4), equals(25.0));
      });

      test('handles zero total', () {
        expect(SafeMath.safePercentage(50, 0), equals(0.0));
        expect(SafeMath.safePercentage(100, 0, defaultValue: -1), equals(-1.0));
      });

      test('handles edge cases', () {
        expect(SafeMath.safePercentage(0, 100), equals(0.0));
        expect(SafeMath.safePercentage(100, 100), equals(100.0));
      });
    });

    group('safeAverage', () {
      test('calculates average correctly', () {
        expect(SafeMath.safeAverage(100, 4), equals(25.0));
        expect(SafeMath.safeAverage(150, 3), equals(50.0));
      });

      test('handles zero count', () {
        expect(SafeMath.safeAverage(100, 0), equals(0.0));
        expect(SafeMath.safeAverage(100, 0, defaultValue: -1), equals(-1.0));
      });
    });

    group('safeGrowthRate', () {
      test('calculates growth rate correctly', () {
        expect(SafeMath.safeGrowthRate(110, 100), equals(10.0));
        expect(SafeMath.safeGrowthRate(90, 100), equals(-10.0));
        expect(SafeMath.safeGrowthRate(200, 100), equals(100.0));
      });

      test('handles zero previous value', () {
        expect(SafeMath.safeGrowthRate(100, 0), equals(0.0));
        expect(SafeMath.safeGrowthRate(100, 0, defaultValue: -1), equals(-1.0));
      });

      test('handles same values', () {
        expect(SafeMath.safeGrowthRate(100, 100), equals(0.0));
      });
    });

    group('clamp', () {
      test('clamps values correctly', () {
        expect(SafeMath.clamp(5, 0, 10), equals(5.0));
        expect(SafeMath.clamp(-5, 0, 10), equals(0.0));
        expect(SafeMath.clamp(15, 0, 10), equals(10.0));
      });

      test('handles edge values', () {
        expect(SafeMath.clamp(0, 0, 10), equals(0.0));
        expect(SafeMath.clamp(10, 0, 10), equals(10.0));
      });
    });

    group('isValid', () {
      test('identifies valid numbers', () {
        expect(SafeMath.isValid(0), true);
        expect(SafeMath.isValid(100), true);
        expect(SafeMath.isValid(-50), true);
        expect(SafeMath.isValid(3.14), true);
      });

      test('identifies invalid numbers', () {
        expect(SafeMath.isValid(double.nan), false);
        expect(SafeMath.isValid(double.infinity), false);
        expect(SafeMath.isValid(double.negativeInfinity), false);
      });
    });

    group('getValidOrDefault', () {
      test('returns valid values', () {
        expect(SafeMath.getValidOrDefault(100), equals(100.0));
        expect(SafeMath.getValidOrDefault(-50), equals(-50.0));
      });

      test('returns default for invalid values', () {
        expect(SafeMath.getValidOrDefault(double.nan), equals(0.0));
        expect(SafeMath.getValidOrDefault(double.infinity), equals(0.0));
        expect(
          SafeMath.getValidOrDefault(double.nan, defaultValue: -1),
          equals(-1.0),
        );
      });
    });
  });

  group('Real-world Scenarios', () {
    test('profit margin calculation', () {
      // Scenario: Calculate profit margin
      const sales = 1000000.0;
      const cost = 700000.0;
      const profit = sales - cost;
      final margin = SafeMath.safePercentage(profit, sales);

      expect(margin, equals(30.0));
    });

    test('profit margin with zero sales', () {
      const sales = 0.0;
      const cost = 0.0;
      const profit = sales - cost;
      final margin = SafeMath.safePercentage(profit, sales);

      expect(margin, equals(0.0)); // No crash
    });

    test('average transaction value', () {
      const totalSales = 5000000.0;
      const transactionCount = 50;
      final average = SafeMath.safeAverage(totalSales, transactionCount);

      expect(average, equals(100000.0));
    });

    test('average with no transactions', () {
      const totalSales = 0.0;
      const transactionCount = 0;
      final average = SafeMath.safeAverage(totalSales, transactionCount);

      expect(average, equals(0.0)); // No crash
    });

    test('month-over-month growth', () {
      const currentMonth = 10000000.0;
      const previousMonth = 8000000.0;
      final growth = SafeMath.safeGrowthRate(currentMonth, previousMonth);

      expect(growth, equals(25.0)); // 25% growth
    });

    test('growth from zero baseline', () {
      const currentMonth = 10000000.0;
      const previousMonth = 0.0;
      final growth = SafeMath.safeGrowthRate(currentMonth, previousMonth);

      expect(growth, equals(0.0)); // No crash, returns default
    });
  });
}
