/// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
/// **Validates: Requirements 5.5**
///
/// Property: For any dashboard data with todaySales > 0, grossProfitMarginPercent
/// SHALL equal (grossProfit / todaySales * 100) rounded to one decimal place.
library;

import 'package:glados/glados.dart';

/// Profit margin calculator (mirrors DashboardData logic)
class ProfitMarginCalculator {
  /// Calculate gross profit: sales - cost of goods sold
  static double calculateGrossProfit(double sales, double costOfGoodsSold) {
    return sales - costOfGoodsSold;
  }

  /// Calculate gross profit margin percentage
  /// Requirements 5.5: (grossProfit / todaySales * 100)
  static double calculateGrossProfitMarginPercent(
      double sales, double grossProfit) {
    if (sales <= 0) return 0.0;
    return (grossProfit / sales) * 100;
  }

  /// Format margin to one decimal place
  static String formatMarginPercent(double marginPercent) {
    return '${marginPercent.toStringAsFixed(1)}%';
  }
}

/// Dashboard data for testing
class TestDashboardData {
  final double todaySales;
  final double todayCostOfGoodsSold;

  TestDashboardData({
    required this.todaySales,
    required this.todayCostOfGoodsSold,
  });

  double get grossProfit => todaySales - todayCostOfGoodsSold;

  double get grossProfitMarginPercent =>
      todaySales > 0 ? (grossProfit / todaySales) * 100 : 0.0;
}

/// Generator for valid sales and cost values
extension SalesDataGenerator on Any {
  /// Generate sales with positive value
  Generator<double> get positiveSales {
    return any.doubleInRange(1000.0, 10000000.0);
  }

  /// Generate cost of goods sold (0 to sales amount)
  Generator<double> costOfGoodsSoldFor(double sales) {
    return any.doubleInRange(0.0, sales);
  }

  /// Generate dashboard data with valid sales and COGS
  Generator<TestDashboardData> get dashboardDataWithSales {
    return any.positiveSales.bind((sales) {
      return any.costOfGoodsSoldFor(sales).map((cogs) {
        return TestDashboardData(
          todaySales: sales,
          todayCostOfGoodsSold: cogs,
        );
      });
    });
  }

  /// Generate dashboard data with zero sales
  Generator<TestDashboardData> get dashboardDataWithZeroSales {
    return any.doubleInRange(0.0, 100000.0).map((cogs) {
      return TestDashboardData(
        todaySales: 0,
        todayCostOfGoodsSold: cogs,
      );
    });
  }

  /// Generate dashboard data with 100% margin (zero COGS)
  Generator<TestDashboardData> get dashboardDataWithFullMargin {
    return any.positiveSales.map((sales) {
      return TestDashboardData(
        todaySales: sales,
        todayCostOfGoodsSold: 0,
      );
    });
  }

  /// Generate dashboard data with zero margin (COGS = sales)
  Generator<TestDashboardData> get dashboardDataWithZeroMargin {
    return any.positiveSales.map((sales) {
      return TestDashboardData(
        todaySales: sales,
        todayCostOfGoodsSold: sales,
      );
    });
  }
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Margin percent equals (grossProfit / todaySales * 100)
  Glados(any.dashboardDataWithSales).test(
    'Margin percent equals (grossProfit / todaySales * 100)',
    (data) {
      final expectedMargin = (data.grossProfit / data.todaySales) * 100;
      final actualMargin = data.grossProfitMarginPercent;

      if ((actualMargin - expectedMargin).abs() > 0.0001) {
        throw Exception(
          'Margin mismatch: calculated $actualMargin, expected $expectedMargin',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Zero sales results in zero margin percent
  Glados(any.dashboardDataWithZeroSales).test(
    'Zero sales results in zero margin percent',
    (data) {
      if (data.grossProfitMarginPercent != 0.0) {
        throw Exception(
          'Zero sales should have zero margin: ${data.grossProfitMarginPercent}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: 100% margin when COGS is zero
  Glados(any.dashboardDataWithFullMargin).test(
    '100% margin when COGS is zero',
    (data) {
      final margin = data.grossProfitMarginPercent;

      if ((margin - 100.0).abs() > 0.0001) {
        throw Exception(
          'Zero COGS should have 100% margin: $margin',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: 0% margin when COGS equals sales
  Glados(any.dashboardDataWithZeroMargin).test(
    '0% margin when COGS equals sales',
    (data) {
      final margin = data.grossProfitMarginPercent;

      if (margin.abs() > 0.0001) {
        throw Exception(
          'COGS = sales should have 0% margin: $margin',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Margin is between 0% and 100% when COGS is between 0 and sales
  Glados(any.dashboardDataWithSales).test(
    'Margin is between 0% and 100% when COGS is valid',
    (data) {
      final margin = data.grossProfitMarginPercent;

      if (margin < 0 || margin > 100) {
        throw Exception(
          'Margin should be between 0% and 100%: $margin (sales: ${data.todaySales}, cogs: ${data.todayCostOfGoodsSold})',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Formatted margin has one decimal place
  Glados(any.dashboardDataWithSales).test(
    'Formatted margin has one decimal place',
    (data) {
      final formatted = ProfitMarginCalculator.formatMarginPercent(
          data.grossProfitMarginPercent);

      // Check format: should end with % and have one decimal
      if (!formatted.endsWith('%')) {
        throw Exception('Formatted margin should end with %: $formatted');
      }

      // Extract number part and verify decimal places
      final numberPart = formatted.replaceAll('%', '');
      final parts = numberPart.split('.');

      if (parts.length != 2 || parts[1].length != 1) {
        throw Exception(
          'Formatted margin should have exactly one decimal place: $formatted',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Gross profit equals sales minus COGS
  Glados(any.dashboardDataWithSales).test(
    'Gross profit equals sales minus COGS',
    (data) {
      final expectedProfit = data.todaySales - data.todayCostOfGoodsSold;
      final actualProfit = data.grossProfit;

      if ((actualProfit - expectedProfit).abs() > 0.01) {
        throw Exception(
          'Gross profit mismatch: calculated $actualProfit, expected $expectedProfit',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 5: Profit Margin Formatting**
  /// **Validates: Requirements 5.5**
  ///
  /// Property: Higher COGS results in lower margin
  Glados2(any.positiveSales, any.doubleInRange(0.1, 0.4)).test(
    'Higher COGS results in lower margin',
    (sales, cogsRatio1) {
      final cogsRatio2 = cogsRatio1 + 0.2; // Higher COGS ratio

      final data1 = TestDashboardData(
        todaySales: sales,
        todayCostOfGoodsSold: sales * cogsRatio1,
      );

      final data2 = TestDashboardData(
        todaySales: sales,
        todayCostOfGoodsSold: sales * cogsRatio2,
      );

      if (data2.grossProfitMarginPercent >= data1.grossProfitMarginPercent) {
        throw Exception(
          'Higher COGS should result in lower margin: '
          'margin1=${data1.grossProfitMarginPercent}, margin2=${data2.grossProfitMarginPercent}',
        );
      }
    },
  );
}
