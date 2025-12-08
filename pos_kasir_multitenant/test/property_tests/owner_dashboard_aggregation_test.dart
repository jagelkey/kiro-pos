/// **Feature: pos-comprehensive-fix, Property 12: Owner Dashboard Aggregation**
/// **Validates: Requirements 12.1, 12.2**
///
/// Property: The owner dashboard SHALL correctly aggregate sales data across
/// all branches, with total sales equaling the sum of individual branch sales.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/branch.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Data class for branch metrics (simplified for testing)
class TestBranchMetrics {
  final Branch branch;
  final double totalSales;
  final int transactionCount;
  final double averageTransaction;

  TestBranchMetrics({
    required this.branch,
    required this.totalSales,
    required this.transactionCount,
    required this.averageTransaction,
  });
}

/// Generator for sales amounts
extension SalesAmountGenerator on Any {
  Generator<double> get salesAmount {
    return any.doubleInRange(10000.0, 10000000.0);
  }
}

/// Generator for transaction counts
extension TransactionCountGenerator on Any {
  Generator<int> get transactionCount {
    return any.intInRange(1, 100);
  }
}

/// Generator for branch count
extension BranchCountGenerator on Any {
  Generator<int> get branchCount {
    return any.intInRange(2, 10);
  }
}

/// Create a branch
Branch createBranch({
  required String id,
  required String ownerId,
  required String code,
}) {
  return Branch(
    id: id,
    ownerId: ownerId,
    name: 'Branch $code',
    code: code,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

/// Create a transaction
Transaction createTransaction({
  required String tenantId,
  required double total,
}) {
  return Transaction(
    id: 'trx-${DateTime.now().millisecondsSinceEpoch}-${total.hashCode}',
    tenantId: tenantId,
    userId: 'user-1',
    items: [],
    subtotal: total / 1.11,
    tax: total - (total / 1.11),
    discount: 0,
    total: total,
    paymentMethod: 'cash',
    createdAt: DateTime.now(),
  );
}

/// Calculate branch metrics from transactions
TestBranchMetrics calculateBranchMetrics(
    Branch branch, List<Transaction> transactions) {
  final branchTransactions =
      transactions.where((t) => t.tenantId == branch.id).toList();
  final totalSales =
      branchTransactions.fold<double>(0, (sum, t) => sum + t.total);
  final txCount = branchTransactions.length;
  final avgTx = txCount > 0 ? totalSales / txCount : 0.0;

  return TestBranchMetrics(
    branch: branch,
    totalSales: totalSales,
    transactionCount: txCount,
    averageTransaction: avgTx,
  );
}

/// Aggregate dashboard data from branch metrics
Map<String, dynamic> aggregateDashboard(List<TestBranchMetrics> metrics) {
  final totalSales = metrics.fold<double>(0, (sum, m) => sum + m.totalSales);
  final totalTx = metrics.fold<int>(0, (sum, m) => sum + m.transactionCount);
  final activeBranches = metrics.where((m) => m.branch.isActive).length;

  // Sort for top performers
  final sortedBySales = List<TestBranchMetrics>.from(metrics)
    ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

  return {
    'totalSales': totalSales,
    'totalTransactions': totalTx,
    'activeBranchCount': activeBranches,
    'topBranches': sortedBySales.take(3).toList(),
    'branchMetrics': metrics,
  };
}

void main() {
  /// **Property 12: Owner Dashboard Aggregation**
  /// **Validates: Requirements 12.1, 12.2**
  ///
  /// Property: Total sales equals sum of all branch sales
  Glados2(any.branchCount, any.salesAmount).test(
    'Total sales equals sum of all branch sales',
    (branchCount, baseSales) {
      final branches = List.generate(
        branchCount,
        (i) => createBranch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          code: 'BR-${i.toString().padLeft(3, '0')}',
        ),
      );

      // Create transactions for each branch
      final transactions = <Transaction>[];
      final expectedBranchSales = <String, double>{};

      for (var i = 0; i < branchCount; i++) {
        final branchSales = baseSales * (i + 1); // Different sales per branch
        expectedBranchSales[branches[i].id] = branchSales;
        transactions.add(createTransaction(
          tenantId: branches[i].id,
          total: branchSales,
        ));
      }

      // Calculate metrics
      final metrics =
          branches.map((b) => calculateBranchMetrics(b, transactions)).toList();
      final dashboard = aggregateDashboard(metrics);

      final expectedTotal =
          expectedBranchSales.values.fold<double>(0, (sum, s) => sum + s);
      final actualTotal = dashboard['totalSales'] as double;

      if ((actualTotal - expectedTotal).abs() > 0.01) {
        throw Exception(
            'Total sales mismatch: expected $expectedTotal, got $actualTotal');
      }
    },
  );

  /// Property: Total transactions equals sum of all branch transactions
  Glados2(any.branchCount, any.transactionCount).test(
    'Total transactions equals sum of all branch transactions',
    (branchCount, baseTxCount) {
      final branches = List.generate(
        branchCount,
        (i) => createBranch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          code: 'BR-${i.toString().padLeft(3, '0')}',
        ),
      );

      // Create transactions for each branch
      final transactions = <Transaction>[];
      var expectedTotalTx = 0;

      for (var i = 0; i < branchCount; i++) {
        final txCount = baseTxCount + i; // Different count per branch
        expectedTotalTx += txCount;
        for (var j = 0; j < txCount; j++) {
          transactions.add(createTransaction(
            tenantId: branches[i].id,
            total: 10000.0 * (j + 1),
          ));
        }
      }

      // Calculate metrics
      final metrics =
          branches.map((b) => calculateBranchMetrics(b, transactions)).toList();
      final dashboard = aggregateDashboard(metrics);

      final actualTotalTx = dashboard['totalTransactions'] as int;

      if (actualTotalTx != expectedTotalTx) {
        throw Exception(
            'Total transactions mismatch: expected $expectedTotalTx, got $actualTotalTx');
      }
    },
  );

  /// Property: Average transaction is correctly calculated per branch
  Glados2(any.salesAmount, any.transactionCount).test(
    'Average transaction is correctly calculated per branch',
    (totalSales, txCount) {
      if (txCount == 0) return;

      final branch = createBranch(
        id: 'branch-1',
        ownerId: 'owner-1',
        code: 'BR-001',
      );

      // Create transactions that sum to totalSales
      final transactions = <Transaction>[];
      final perTxAmount = totalSales / txCount;
      for (var i = 0; i < txCount; i++) {
        transactions.add(createTransaction(
          tenantId: branch.id,
          total: perTxAmount,
        ));
      }

      final metrics = calculateBranchMetrics(branch, transactions);
      final expectedAvg = totalSales / txCount;

      if ((metrics.averageTransaction - expectedAvg).abs() > 0.01) {
        throw Exception(
            'Average transaction mismatch: expected $expectedAvg, got ${metrics.averageTransaction}');
      }
    },
  );

  /// Property: Top branches are sorted by sales descending
  Glados(any.branchCount).test(
    'Top branches are sorted by sales descending',
    (branchCount) {
      if (branchCount < 2) return;

      final branches = List.generate(
        branchCount,
        (i) => createBranch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          code: 'BR-${i.toString().padLeft(3, '0')}',
        ),
      );

      // Create transactions with different sales per branch
      final transactions = <Transaction>[];
      for (var i = 0; i < branchCount; i++) {
        transactions.add(createTransaction(
          tenantId: branches[i].id,
          total: 10000.0 * (i + 1), // Increasing sales
        ));
      }

      final metrics =
          branches.map((b) => calculateBranchMetrics(b, transactions)).toList();
      final dashboard = aggregateDashboard(metrics);
      final topBranches = dashboard['topBranches'] as List<TestBranchMetrics>;

      // Verify sorted descending
      for (var i = 0; i < topBranches.length - 1; i++) {
        if (topBranches[i].totalSales < topBranches[i + 1].totalSales) {
          throw Exception('Top branches should be sorted by sales descending');
        }
      }
    },
  );

  /// Property: Branch with zero transactions has zero sales
  Glados(any.branchCount).test(
    'Branch with zero transactions has zero sales',
    (branchCount) {
      final branches = List.generate(
        branchCount,
        (i) => createBranch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          code: 'BR-${i.toString().padLeft(3, '0')}',
        ),
      );

      // No transactions
      final transactions = <Transaction>[];

      final metrics =
          branches.map((b) => calculateBranchMetrics(b, transactions)).toList();

      for (final m in metrics) {
        if (m.totalSales != 0) {
          throw Exception('Branch with no transactions should have 0 sales');
        }
        if (m.transactionCount != 0) {
          throw Exception(
              'Branch with no transactions should have 0 transaction count');
        }
        if (m.averageTransaction != 0) {
          throw Exception('Branch with no transactions should have 0 average');
        }
      }
    },
  );

  /// Property: Active branch count is correct
  Glados(any.branchCount).test(
    'Active branch count is correct',
    (branchCount) {
      // Create mix of active and inactive branches
      final branches = List.generate(
        branchCount,
        (i) => Branch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          name: 'Branch $i',
          code: 'BR-${i.toString().padLeft(3, '0')}',
          isActive: i.isEven, // Even indices are active
          createdAt: DateTime.now(),
        ),
      );

      final expectedActive = branches.where((b) => b.isActive).length;

      final metrics = branches
          .map((b) => TestBranchMetrics(
                branch: b,
                totalSales: 0,
                transactionCount: 0,
                averageTransaction: 0,
              ))
          .toList();
      final dashboard = aggregateDashboard(metrics);

      final actualActive = dashboard['activeBranchCount'] as int;

      if (actualActive != expectedActive) {
        throw Exception(
            'Active branch count mismatch: expected $expectedActive, got $actualActive');
      }
    },
  );

  /// Property: Aggregation is commutative (order doesn't matter)
  Glados2(any.salesAmount, any.salesAmount).test(
    'Aggregation is commutative - order does not affect total',
    (sales1, sales2) {
      final branch1 = createBranch(id: 'b1', ownerId: 'o1', code: 'BR-001');
      final branch2 = createBranch(id: 'b2', ownerId: 'o1', code: 'BR-002');

      final tx1 = createTransaction(tenantId: 'b1', total: sales1);
      final tx2 = createTransaction(tenantId: 'b2', total: sales2);

      // Order 1: branch1 first
      final metrics1 = [
        calculateBranchMetrics(branch1, [tx1, tx2]),
        calculateBranchMetrics(branch2, [tx1, tx2]),
      ];
      final dashboard1 = aggregateDashboard(metrics1);

      // Order 2: branch2 first
      final metrics2 = [
        calculateBranchMetrics(branch2, [tx1, tx2]),
        calculateBranchMetrics(branch1, [tx1, tx2]),
      ];
      final dashboard2 = aggregateDashboard(metrics2);

      final total1 = dashboard1['totalSales'] as double;
      final total2 = dashboard2['totalSales'] as double;

      if ((total1 - total2).abs() > 0.01) {
        throw Exception('Aggregation should be commutative');
      }
    },
  );

  /// Property: Single branch dashboard equals branch metrics
  Glados2(any.salesAmount, any.transactionCount).test(
    'Single branch dashboard equals branch metrics',
    (totalSales, txCount) {
      if (txCount == 0) return;

      final branch = createBranch(id: 'b1', ownerId: 'o1', code: 'BR-001');

      final transactions = List.generate(
        txCount,
        (i) => createTransaction(
          tenantId: 'b1',
          total: totalSales / txCount,
        ),
      );

      final metrics = [calculateBranchMetrics(branch, transactions)];
      final dashboard = aggregateDashboard(metrics);

      final dashboardTotal = dashboard['totalSales'] as double;
      final dashboardTx = dashboard['totalTransactions'] as int;

      if ((dashboardTotal - metrics[0].totalSales).abs() > 0.01) {
        throw Exception('Single branch total should match dashboard total');
      }
      if (dashboardTx != metrics[0].transactionCount) {
        throw Exception(
            'Single branch tx count should match dashboard tx count');
      }
    },
  );

  /// Property: Empty branches list results in zero totals
  Glados(any.intInRange(0, 1)).test(
    'Empty branches list results in zero totals',
    (_) {
      final metrics = <TestBranchMetrics>[];
      final dashboard = aggregateDashboard(metrics);

      if (dashboard['totalSales'] != 0.0) {
        throw Exception('Empty branches should have 0 total sales');
      }
      if (dashboard['totalTransactions'] != 0) {
        throw Exception('Empty branches should have 0 transactions');
      }
      if (dashboard['activeBranchCount'] != 0) {
        throw Exception('Empty branches should have 0 active count');
      }
    },
  );

  /// Property: Large numbers aggregate correctly
  Glados(any.branchCount).test(
    'Large numbers aggregate correctly',
    (branchCount) {
      final branches = List.generate(
        branchCount,
        (i) => createBranch(
          id: 'branch-$i',
          ownerId: 'owner-1',
          code: 'BR-${i.toString().padLeft(3, '0')}',
        ),
      );

      // Large sales amounts
      final transactions = <Transaction>[];
      double expectedTotal = 0;
      for (var i = 0; i < branchCount; i++) {
        const sales = 999999999.99; // Large amount
        expectedTotal += sales;
        transactions.add(createTransaction(
          tenantId: branches[i].id,
          total: sales,
        ));
      }

      final metrics =
          branches.map((b) => calculateBranchMetrics(b, transactions)).toList();
      final dashboard = aggregateDashboard(metrics);

      final actualTotal = dashboard['totalSales'] as double;

      // Allow small floating point tolerance
      if ((actualTotal - expectedTotal).abs() > 1.0) {
        throw Exception(
            'Large number aggregation failed: expected $expectedTotal, got $actualTotal');
      }
    },
  );
}
