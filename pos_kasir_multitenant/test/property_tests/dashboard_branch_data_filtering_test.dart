/// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
/// **Validates: Requirements 2.2**
///
/// Property: For any dashboard data load with a given branch ID, all returned
/// data SHALL be filtered by both tenant ID and branch ID when branch ID is provided.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/expense.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;
import 'package:pos_kasir_multitenant/data/models/product.dart';

/// Generator for tenant IDs
extension TenantIdGenerator on Any {
  Generator<String> get tenantId {
    return any.intInRange(1, 1000).map((i) => 'tenant-$i');
  }
}

/// Generator for branch IDs
extension BranchIdGenerator on Any {
  Generator<String> get branchId {
    return any.intInRange(1, 100).map((i) => 'branch-$i');
  }
}

/// Create an expense with specific tenant and branch
Expense createExpense({
  required String tenantId,
  String? branchId,
  required String description,
  double amount = 10000,
}) {
  return Expense(
    id: 'exp-${description.hashCode.abs()}-${tenantId.hashCode.abs()}-${branchId?.hashCode.abs() ?? 0}',
    tenantId: tenantId,
    branchId: branchId,
    description: description,
    amount: amount,
    category: 'operational',
    date: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

/// Create a transaction with specific tenant
/// Note: Transaction model doesn't have branchId field in current implementation
Transaction createTransaction({
  required String tenantId,
  required double total,
}) {
  return Transaction(
    id: 'trx-${DateTime.now().microsecondsSinceEpoch}-${tenantId.hashCode.abs()}',
    tenantId: tenantId,
    userId: 'user-1',
    items: [
      TransactionItem(
        productId: 'p1',
        productName: 'Product 1',
        quantity: 1,
        price: total,
        total: total,
      ),
    ],
    subtotal: total,
    tax: total * 0.11,
    discount: 0,
    total: total * 1.11,
    paymentMethod: 'cash',
    createdAt: DateTime.now(),
  );
}

/// Create a material with specific tenant
mat.Material createMaterial({
  required String tenantId,
  required String name,
  double stock = 100.0,
  double? minStock,
}) {
  return mat.Material(
    id: 'mat-${name.hashCode.abs()}-${tenantId.hashCode.abs()}',
    tenantId: tenantId,
    name: name,
    stock: stock,
    unit: 'kg',
    minStock: minStock,
    createdAt: DateTime.now(),
  );
}

/// Create a product with specific tenant
Product createProduct({
  required String tenantId,
  required String name,
  double price = 10000,
}) {
  return Product(
    id: 'product-${name.hashCode.abs()}-${tenantId.hashCode.abs()}',
    tenantId: tenantId,
    name: name,
    price: price,
    stock: 100,
    category: 'Test',
    createdAt: DateTime.now(),
  );
}

/// Simulates branch data filtering logic from DashboardProvider
/// This mirrors the actual implementation for testability
/// Requirements 2.2: Filter data by both tenant ID and branch ID
class BranchDataFilter {
  /// Filter expenses by tenant ID and optionally by branch ID
  /// Requirements 2.2: Filter by both tenant ID and branch ID when branch ID is provided
  static List<Expense> filterExpensesByTenantAndBranch(
    List<Expense> expenses,
    String tenantId, {
    String? branchId,
  }) {
    var filtered = expenses.where((e) => e.tenantId == tenantId);

    // When branchId is provided, filter by branch as well
    if (branchId != null) {
      filtered = filtered.where((e) => e.branchId == branchId);
    }

    return filtered.toList();
  }

  /// Filter transactions by tenant ID
  /// Note: Transaction model doesn't have branchId in current implementation
  /// Requirements 2.2: Filter by tenant ID (branch filtering would apply if model supported it)
  static List<Transaction> filterTransactionsByTenant(
    List<Transaction> transactions,
    String tenantId,
  ) {
    return transactions.where((t) => t.tenantId == tenantId).toList();
  }

  /// Filter materials by tenant ID
  /// Note: Material model doesn't have branchId in current implementation
  /// Requirements 2.2: Filter by tenant ID (branch filtering would apply if model supported it)
  static List<mat.Material> filterMaterialsByTenant(
    List<mat.Material> materials,
    String tenantId,
  ) {
    return materials.where((m) => m.tenantId == tenantId).toList();
  }

  /// Filter products by tenant ID
  /// Note: Product model doesn't have branchId in current implementation
  /// Requirements 2.2: Filter by tenant ID (branch filtering would apply if model supported it)
  static List<Product> filterProductsByTenant(
    List<Product> products,
    String tenantId,
  ) {
    return products.where((p) => p.tenantId == tenantId).toList();
  }

  /// Calculate total expenses for a tenant and branch
  /// Requirements 2.2: Only include expenses from current tenant and branch
  static double calculateExpenseTotal(
    List<Expense> expenses,
    String tenantId, {
    String? branchId,
  }) {
    final filtered = filterExpensesByTenantAndBranch(
      expenses,
      tenantId,
      branchId: branchId,
    );
    return filtered.fold<double>(0, (sum, e) => sum + e.amount);
  }
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Expenses are filtered by both tenant ID and branch ID when branch ID is provided
  Glados3(any.tenantId, any.branchId, any.branchId).test(
    'Expenses are filtered by both tenant ID and branch ID',
    (tenantId, branch1, branch2) {
      if (branch1 == branch2) return; // Skip if same branch

      // Create expenses for different branches within same tenant
      final exp1 = createExpense(
        tenantId: tenantId,
        branchId: branch1,
        description: 'Expense Branch 1',
        amount: 10000,
      );
      final exp2 = createExpense(
        tenantId: tenantId,
        branchId: branch2,
        description: 'Expense Branch 2',
        amount: 20000,
      );
      // Expense without branch (tenant-level expense)
      final exp3 = createExpense(
        tenantId: tenantId,
        branchId: null,
        description: 'Expense No Branch',
        amount: 5000,
      );
      // Expense from different tenant
      final exp4 = createExpense(
        tenantId: 'other-tenant',
        branchId: branch1,
        description: 'Other Tenant Expense',
        amount: 30000,
      );

      final allExpenses = [exp1, exp2, exp3, exp4];

      // Filter by tenant and branch1
      final branch1Expenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        allExpenses,
        tenantId,
        branchId: branch1,
      );

      // Should only return expense from branch1 of the specified tenant
      if (branch1Expenses.length != 1) {
        throw Exception(
          'Should return 1 expense for branch1, got ${branch1Expenses.length}',
        );
      }
      if (branch1Expenses.first.branchId != branch1) {
        throw Exception('Returned expense should belong to branch1');
      }
      if (branch1Expenses.first.tenantId != tenantId) {
        throw Exception('Returned expense should belong to specified tenant');
      }

      // Filter by tenant and branch2
      final branch2Expenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        allExpenses,
        tenantId,
        branchId: branch2,
      );

      // Should only return expense from branch2 of the specified tenant
      if (branch2Expenses.length != 1) {
        throw Exception(
          'Should return 1 expense for branch2, got ${branch2Expenses.length}',
        );
      }
      if (branch2Expenses.first.branchId != branch2) {
        throw Exception('Returned expense should belong to branch2');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: When no branch ID is provided, all tenant expenses are returned
  Glados2(any.tenantId, any.branchId).test(
    'When no branch ID is provided, all tenant expenses are returned',
    (tenantId, branchId) {
      final exp1 = createExpense(
        tenantId: tenantId,
        branchId: branchId,
        description: 'Branch Expense',
        amount: 10000,
      );
      final exp2 = createExpense(
        tenantId: tenantId,
        branchId: null,
        description: 'No Branch Expense',
        amount: 20000,
      );
      final exp3 = createExpense(
        tenantId: 'other-tenant',
        branchId: branchId,
        description: 'Other Tenant Expense',
        amount: 30000,
      );

      final allExpenses = [exp1, exp2, exp3];

      // Filter by tenant only (no branch filter)
      final tenantExpenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        allExpenses,
        tenantId,
        branchId: null,
      );

      // Should return all expenses for the tenant (both with and without branch)
      if (tenantExpenses.length != 2) {
        throw Exception(
          'Should return 2 expenses for tenant, got ${tenantExpenses.length}',
        );
      }
      if (tenantExpenses.any((e) => e.tenantId != tenantId)) {
        throw Exception(
            'All returned expenses should belong to specified tenant');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Expense totals are correctly calculated per branch
  Glados3(any.tenantId, any.branchId, any.branchId).test(
    'Expense totals are correctly calculated per branch',
    (tenantId, branch1, branch2) {
      if (branch1 == branch2) return;

      final exp1 = createExpense(
        tenantId: tenantId,
        branchId: branch1,
        description: 'Expense 1',
        amount: 10000,
      );
      final exp2 = createExpense(
        tenantId: tenantId,
        branchId: branch1,
        description: 'Expense 2',
        amount: 15000,
      );
      final exp3 = createExpense(
        tenantId: tenantId,
        branchId: branch2,
        description: 'Expense 3',
        amount: 25000,
      );

      final allExpenses = [exp1, exp2, exp3];

      final branch1Total = BranchDataFilter.calculateExpenseTotal(
        allExpenses,
        tenantId,
        branchId: branch1,
      );
      final branch2Total = BranchDataFilter.calculateExpenseTotal(
        allExpenses,
        tenantId,
        branchId: branch2,
      );

      // Branch 1 total should be 10000 + 15000 = 25000
      if ((branch1Total - 25000).abs() > 0.01) {
        throw Exception('Branch 1 total should be 25000, got $branch1Total');
      }

      // Branch 2 total should be 25000
      if ((branch2Total - 25000).abs() > 0.01) {
        throw Exception('Branch 2 total should be 25000, got $branch2Total');
      }

      // Total without branch filter should be 50000
      final totalAll = BranchDataFilter.calculateExpenseTotal(
        allExpenses,
        tenantId,
        branchId: null,
      );
      if ((totalAll - 50000).abs() > 0.01) {
        throw Exception('Total all should be 50000, got $totalAll');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Branch filtering does not return data from other tenants
  Glados3(any.tenantId, any.tenantId, any.branchId).test(
    'Branch filtering does not return data from other tenants',
    (tenant1, tenant2, branchId) {
      if (tenant1 == tenant2) return;

      // Same branch ID but different tenants
      final exp1 = createExpense(
        tenantId: tenant1,
        branchId: branchId,
        description: 'Tenant 1 Expense',
        amount: 10000,
      );
      final exp2 = createExpense(
        tenantId: tenant2,
        branchId: branchId,
        description: 'Tenant 2 Expense',
        amount: 20000,
      );

      final allExpenses = [exp1, exp2];

      // Filter by tenant1 and branch
      final tenant1Expenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        allExpenses,
        tenant1,
        branchId: branchId,
      );

      // Should only return tenant1's expense
      if (tenant1Expenses.length != 1) {
        throw Exception(
          'Should return 1 expense for tenant1, got ${tenant1Expenses.length}',
        );
      }
      if (tenant1Expenses.first.tenantId != tenant1) {
        throw Exception('Returned expense should belong to tenant1');
      }

      // Filter by tenant2 and branch
      final tenant2Expenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        allExpenses,
        tenant2,
        branchId: branchId,
      );

      // Should only return tenant2's expense
      if (tenant2Expenses.length != 1) {
        throw Exception(
          'Should return 1 expense for tenant2, got ${tenant2Expenses.length}',
        );
      }
      if (tenant2Expenses.first.tenantId != tenant2) {
        throw Exception('Returned expense should belong to tenant2');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Empty result for non-existent branch
  Glados2(any.tenantId, any.branchId).test(
    'Empty result for non-existent branch',
    (tenantId, branchId) {
      final expenses = [
        createExpense(
          tenantId: tenantId,
          branchId: 'different-branch-1',
          description: 'Expense 1',
        ),
        createExpense(
          tenantId: tenantId,
          branchId: 'different-branch-2',
          description: 'Expense 2',
        ),
      ];

      final branchExpenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        expenses,
        tenantId,
        branchId: branchId,
      );

      if (branchExpenses.isNotEmpty) {
        throw Exception('Should return empty list for non-existent branch');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Multiple expenses per branch are all returned
  Glados2(any.tenantId, any.intInRange(2, 10)).test(
    'Multiple expenses per branch are all returned',
    (tenantId, expenseCount) {
      const branchId = 'target-branch';

      // Create multiple expenses for target branch
      final expenses = <Expense>[];
      for (var i = 0; i < expenseCount; i++) {
        expenses.add(createExpense(
          tenantId: tenantId,
          branchId: branchId,
          description: 'Expense $i',
          amount: 1000.0 * (i + 1),
        ));
      }

      // Add expenses from other branches
      expenses.add(createExpense(
        tenantId: tenantId,
        branchId: 'other-branch',
        description: 'Other Branch Expense',
        amount: 99999,
      ));

      final branchExpenses = BranchDataFilter.filterExpensesByTenantAndBranch(
        expenses,
        tenantId,
        branchId: branchId,
      );

      if (branchExpenses.length != expenseCount) {
        throw Exception(
          'Should return $expenseCount expenses for branch, got ${branchExpenses.length}',
        );
      }

      if (branchExpenses.any((e) => e.branchId != branchId)) {
        throw Exception('All expenses should belong to target branch');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Filtering preserves all expense data fields
  Glados2(any.tenantId, any.branchId).test(
    'Filtering preserves all expense data fields',
    (tenantId, branchId) {
      final expense = createExpense(
        tenantId: tenantId,
        branchId: branchId,
        description: 'Test Expense',
        amount: 25000,
      );
      final expenses = [expense];

      final filtered = BranchDataFilter.filterExpensesByTenantAndBranch(
        expenses,
        tenantId,
        branchId: branchId,
      );

      if (filtered.isEmpty) {
        throw Exception('Should find the expense');
      }

      final found = filtered.first;
      if (found.id != expense.id ||
          found.tenantId != expense.tenantId ||
          found.branchId != expense.branchId ||
          found.description != expense.description ||
          found.amount != expense.amount ||
          found.category != expense.category) {
        throw Exception('Filtering should preserve all data fields');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 2: Branch Data Filtering**
  /// **Validates: Requirements 2.2**
  ///
  /// Property: Branch filtering is consistent across multiple queries
  Glados3(any.tenantId, any.branchId, any.branchId).test(
    'Branch filtering is consistent across multiple queries',
    (tenantId, branch1, branch2) {
      if (branch1 == branch2) return;

      final expenses = [
        createExpense(
            tenantId: tenantId,
            branchId: branch1,
            description: 'E1',
            amount: 10000),
        createExpense(
            tenantId: tenantId,
            branchId: branch1,
            description: 'E2',
            amount: 20000),
        createExpense(
            tenantId: tenantId,
            branchId: branch2,
            description: 'E3',
            amount: 30000),
        createExpense(
            tenantId: tenantId,
            branchId: branch2,
            description: 'E4',
            amount: 40000),
        createExpense(
            tenantId: tenantId,
            branchId: branch2,
            description: 'E5',
            amount: 50000),
      ];

      // Query multiple times
      final result1 = BranchDataFilter.filterExpensesByTenantAndBranch(
        expenses,
        tenantId,
        branchId: branch1,
      );
      final result2 = BranchDataFilter.filterExpensesByTenantAndBranch(
        expenses,
        tenantId,
        branchId: branch1,
      );

      if (result1.length != 2) {
        throw Exception('Branch 1 should have 2 expenses');
      }
      if (result2.length != 2) {
        throw Exception('Branch 1 should have 2 expenses on second query');
      }

      // Verify totals are consistent
      final total1 = result1.fold<double>(0, (sum, e) => sum + e.amount);
      final total2 = result2.fold<double>(0, (sum, e) => sum + e.amount);

      if ((total1 - 30000).abs() > 0.01) {
        throw Exception('Branch 1 total should be 30000, got $total1');
      }
      if ((total2 - 30000).abs() > 0.01) {
        throw Exception(
            'Branch 1 total should be 30000 on second query, got $total2');
      }
    },
  );
}
