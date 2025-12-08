/// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
/// **Validates: Requirements 2.1, 2.3, 2.4, 2.5**
///
/// Property: For any dashboard data load with a given tenant ID, all returned
/// transactions, materials, products, and expenses SHALL belong to that tenant ID only.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;
import 'package:pos_kasir_multitenant/data/models/product.dart';
import 'package:pos_kasir_multitenant/data/models/expense.dart';

/// Generator for tenant IDs
extension TenantIdGenerator on Any {
  Generator<String> get tenantId {
    return any.intInRange(1, 1000).map((i) => 'tenant-$i');
  }
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(1000.0, 50000.0).bind((price) {
        return any.intInRange(1, 5).map((quantity) {
          final itemTotal = price * quantity;
          return TransactionItem(
            productId: 'prod-${name.hashCode.abs()}',
            productName: name.isEmpty ? 'Product' : name,
            quantity: quantity,
            price: price,
            total: itemTotal,
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

/// Create a transaction with specific tenant
Transaction createTransaction({
  required String tenantId,
  required List<TransactionItem> items,
  double? subtotal,
  double? tax,
  double? discount,
  double? total,
}) {
  final calcSubtotal =
      subtotal ?? items.fold<double>(0, (sum, item) => sum + item.total);
  final calcTax = tax ?? calcSubtotal * 0.11;
  final calcDiscount = discount ?? 0.0;
  final calcTotal = total ?? (calcSubtotal + calcTax - calcDiscount);

  return Transaction(
    id: 'trx-${DateTime.now().microsecondsSinceEpoch}-${tenantId.hashCode.abs()}',
    tenantId: tenantId,
    userId: 'user-1',
    items: items,
    subtotal: calcSubtotal,
    tax: calcTax,
    discount: calcDiscount,
    total: calcTotal,
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

/// Create an expense with specific tenant
Expense createExpense({
  required String tenantId,
  required String description,
  double amount = 10000,
}) {
  return Expense(
    id: 'exp-${description.hashCode.abs()}-${tenantId.hashCode.abs()}',
    tenantId: tenantId,
    description: description,
    amount: amount,
    category: 'operational',
    date: DateTime.now(),
    createdAt: DateTime.now(),
  );
}

/// Simulates tenant data filtering logic from DashboardProvider
/// This mirrors the actual implementation for testability
/// Requirements 2.1, 2.3, 2.4, 2.5
class TenantDataFilter {
  /// Filter transactions by tenant ID
  /// Requirements 2.1, 2.3: Filter all queries by tenant ID
  static List<Transaction> filterTransactionsByTenant(
    List<Transaction> transactions,
    String tenantId,
  ) {
    return transactions.where((t) => t.tenantId == tenantId).toList();
  }

  /// Filter materials by tenant ID
  /// Requirements 2.1, 2.4: Filter materials by tenant ID
  static List<mat.Material> filterMaterialsByTenant(
    List<mat.Material> materials,
    String tenantId,
  ) {
    return materials.where((m) => m.tenantId == tenantId).toList();
  }

  /// Filter products by tenant ID
  /// Requirements 2.1, 2.4: Filter products by tenant ID
  static List<Product> filterProductsByTenant(
    List<Product> products,
    String tenantId,
  ) {
    return products.where((p) => p.tenantId == tenantId).toList();
  }

  /// Filter expenses by tenant ID
  /// Requirements 2.1, 2.5: Filter expenses by tenant ID
  static List<Expense> filterExpensesByTenant(
    List<Expense> expenses,
    String tenantId,
  ) {
    return expenses.where((e) => e.tenantId == tenantId).toList();
  }

  /// Calculate sales total from filtered transactions
  /// Requirements 2.3: Only include transactions from current tenant
  static double calculateSalesTotal(
    List<Transaction> transactions,
    String tenantId,
  ) {
    final filtered = filterTransactionsByTenant(transactions, tenantId);
    return filtered.fold<double>(0, (sum, t) => sum + t.total);
  }

  /// Get low stock materials for tenant
  /// Requirements 2.5: Only display materials from current tenant
  static List<mat.Material> getLowStockMaterials(
    List<mat.Material> materials,
    String tenantId,
  ) {
    final filtered = filterMaterialsByTenant(materials, tenantId);
    return filtered
        .where((m) => m.minStock != null && m.stock <= m.minStock!)
        .toList();
  }
}

/// Verify that all items in a list belong to the specified tenant
bool allBelongToTenant<T>(
  List<T> items,
  String tenantId,
  String Function(T) getTenantId,
) {
  return items.every((item) => getTenantId(item) == tenantId);
}

/// Verify that no items from other tenants are included
bool noItemsFromOtherTenants<T>(
  List<T> filteredItems,
  List<T> allItems,
  String targetTenantId,
  String Function(T) getTenantId,
) {
  // All filtered items should belong to target tenant
  final allBelongToTarget =
      filteredItems.every((item) => getTenantId(item) == targetTenantId);

  // No items from other tenants should be in filtered list
  final otherTenantItems =
      allItems.where((item) => getTenantId(item) != targetTenantId);
  final noOtherTenantItemsIncluded =
      !filteredItems.any((item) => otherTenantItems.contains(item));

  return allBelongToTarget && noOtherTenantItemsIncluded;
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1**
  ///
  /// Property: Transactions are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Transactions are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return; // Skip if same tenant

      final items1 = [
        TransactionItem(
          productId: 'p1',
          productName: 'Product 1',
          quantity: 1,
          price: 10000,
          total: 10000,
        ),
      ];
      final items2 = [
        TransactionItem(
          productId: 'p2',
          productName: 'Product 2',
          quantity: 2,
          price: 20000,
          total: 40000,
        ),
      ];

      final trx1 = createTransaction(tenantId: tenant1, items: items1);
      final trx2 = createTransaction(tenantId: tenant2, items: items2);
      final allTransactions = [trx1, trx2];

      final tenant1Transactions =
          TenantDataFilter.filterTransactionsByTenant(allTransactions, tenant1);
      final tenant2Transactions =
          TenantDataFilter.filterTransactionsByTenant(allTransactions, tenant2);

      // Tenant 1 should only see their transactions
      if (tenant1Transactions.length != 1 ||
          tenant1Transactions.first.tenantId != tenant1) {
        throw Exception('Tenant 1 should only see their own transactions');
      }

      // Tenant 2 should only see their transactions
      if (tenant2Transactions.length != 1 ||
          tenant2Transactions.first.tenantId != tenant2) {
        throw Exception('Tenant 2 should only see their own transactions');
      }

      // No cross-contamination
      if (tenant1Transactions.any((t) => t.tenantId == tenant2)) {
        throw Exception('Tenant 1 should not see Tenant 2 transactions');
      }
      if (tenant2Transactions.any((t) => t.tenantId == tenant1)) {
        throw Exception('Tenant 2 should not see Tenant 1 transactions');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.3**
  ///
  /// Property: Sales totals only include transactions from current tenant
  Glados2(any.tenantId, any.tenantId).test(
    'Sales totals only include transactions from current tenant',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final items1 = [
        TransactionItem(
          productId: 'p1',
          productName: 'Product 1',
          quantity: 1,
          price: 10000,
          total: 10000,
        ),
      ];
      final items2 = [
        TransactionItem(
          productId: 'p2',
          productName: 'Product 2',
          quantity: 2,
          price: 25000,
          total: 50000,
        ),
      ];

      final trx1 = createTransaction(
        tenantId: tenant1,
        items: items1,
        subtotal: 10000,
        tax: 1100,
        total: 11100,
      );
      final trx2 = createTransaction(
        tenantId: tenant2,
        items: items2,
        subtotal: 50000,
        tax: 5500,
        total: 55500,
      );
      final allTransactions = [trx1, trx2];

      final tenant1Sales =
          TenantDataFilter.calculateSalesTotal(allTransactions, tenant1);
      final tenant2Sales =
          TenantDataFilter.calculateSalesTotal(allTransactions, tenant2);

      // Tenant 1 sales should only include their transaction total
      if ((tenant1Sales - 11100).abs() > 0.01) {
        throw Exception('Tenant 1 sales should be 11100, got $tenant1Sales');
      }

      // Tenant 2 sales should only include their transaction total
      if ((tenant2Sales - 55500).abs() > 0.01) {
        throw Exception('Tenant 2 sales should be 55500, got $tenant2Sales');
      }

      // Combined should not equal total of all transactions
      // (unless they happen to be the same tenant, which we skip)
      final totalAllSales = tenant1Sales + tenant2Sales;
      const expectedTotal = 11100 + 55500;
      if ((totalAllSales - expectedTotal).abs() > 0.01) {
        throw Exception(
            'Combined sales should be $expectedTotal, got $totalAllSales');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.4**
  ///
  /// Property: Materials are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Materials are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final mat1 = createMaterial(tenantId: tenant1, name: 'Material A');
      final mat2 = createMaterial(tenantId: tenant2, name: 'Material B');
      final allMaterials = [mat1, mat2];

      final tenant1Materials =
          TenantDataFilter.filterMaterialsByTenant(allMaterials, tenant1);
      final tenant2Materials =
          TenantDataFilter.filterMaterialsByTenant(allMaterials, tenant2);

      if (tenant1Materials.length != 1 ||
          tenant1Materials.first.tenantId != tenant1) {
        throw Exception('Tenant 1 should only see their own materials');
      }

      if (tenant2Materials.length != 1 ||
          tenant2Materials.first.tenantId != tenant2) {
        throw Exception('Tenant 2 should only see their own materials');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.4**
  ///
  /// Property: Products are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Products are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final prod1 = createProduct(tenantId: tenant1, name: 'Product A');
      final prod2 = createProduct(tenantId: tenant2, name: 'Product B');
      final allProducts = [prod1, prod2];

      final tenant1Products =
          TenantDataFilter.filterProductsByTenant(allProducts, tenant1);
      final tenant2Products =
          TenantDataFilter.filterProductsByTenant(allProducts, tenant2);

      if (tenant1Products.length != 1 ||
          tenant1Products.first.tenantId != tenant1) {
        throw Exception('Tenant 1 should only see their own products');
      }

      if (tenant2Products.length != 1 ||
          tenant2Products.first.tenantId != tenant2) {
        throw Exception('Tenant 2 should only see their own products');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.5**
  ///
  /// Property: Expenses are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Expenses are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final exp1 = createExpense(tenantId: tenant1, description: 'Expense A');
      final exp2 = createExpense(tenantId: tenant2, description: 'Expense B');
      final allExpenses = [exp1, exp2];

      final tenant1Expenses =
          TenantDataFilter.filterExpensesByTenant(allExpenses, tenant1);
      final tenant2Expenses =
          TenantDataFilter.filterExpensesByTenant(allExpenses, tenant2);

      if (tenant1Expenses.length != 1 ||
          tenant1Expenses.first.tenantId != tenant1) {
        throw Exception('Tenant 1 should only see their own expenses');
      }

      if (tenant2Expenses.length != 1 ||
          tenant2Expenses.first.tenantId != tenant2) {
        throw Exception('Tenant 2 should only see their own expenses');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.5**
  ///
  /// Property: Low stock warnings only show materials from current tenant
  Glados2(any.tenantId, any.tenantId).test(
    'Low stock warnings only show materials from current tenant',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      // Create low stock materials for both tenants
      final mat1LowStock = createMaterial(
        tenantId: tenant1,
        name: 'Low Stock Material A',
        stock: 5,
        minStock: 10,
      );
      final mat2LowStock = createMaterial(
        tenantId: tenant2,
        name: 'Low Stock Material B',
        stock: 3,
        minStock: 20,
      );
      // Create normal stock material
      final mat1Normal = createMaterial(
        tenantId: tenant1,
        name: 'Normal Material A',
        stock: 100,
        minStock: 10,
      );

      final allMaterials = [mat1LowStock, mat2LowStock, mat1Normal];

      final tenant1LowStock =
          TenantDataFilter.getLowStockMaterials(allMaterials, tenant1);
      final tenant2LowStock =
          TenantDataFilter.getLowStockMaterials(allMaterials, tenant2);

      // Tenant 1 should only see their low stock material
      if (tenant1LowStock.length != 1) {
        throw Exception(
            'Tenant 1 should see 1 low stock material, got ${tenant1LowStock.length}');
      }
      if (tenant1LowStock.first.tenantId != tenant1) {
        throw Exception(
            'Tenant 1 low stock material should belong to tenant 1');
      }

      // Tenant 2 should only see their low stock material
      if (tenant2LowStock.length != 1) {
        throw Exception(
            'Tenant 2 should see 1 low stock material, got ${tenant2LowStock.length}');
      }
      if (tenant2LowStock.first.tenantId != tenant2) {
        throw Exception(
            'Tenant 2 low stock material should belong to tenant 2');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1, 2.3, 2.4, 2.5**
  ///
  /// Property: Multiple items per tenant are all returned correctly
  Glados2(any.tenantId, any.intInRange(2, 10)).test(
    'Multiple items per tenant are all returned correctly',
    (targetTenant, itemCount) {
      // Create multiple transactions for target tenant
      final transactions = <Transaction>[];
      for (var i = 0; i < itemCount; i++) {
        transactions.add(createTransaction(
          tenantId: targetTenant,
          items: [
            TransactionItem(
              productId: 'p$i',
              productName: 'Product $i',
              quantity: 1,
              price: 10000.0 * (i + 1),
              total: 10000.0 * (i + 1),
            ),
          ],
        ));
      }

      // Add transactions from other tenant
      transactions.add(createTransaction(
        tenantId: 'other-tenant',
        items: [
          TransactionItem(
            productId: 'other',
            productName: 'Other Product',
            quantity: 1,
            price: 99999,
            total: 99999,
          ),
        ],
      ));

      final targetTransactions = TenantDataFilter.filterTransactionsByTenant(
          transactions, targetTenant);

      if (targetTransactions.length != itemCount) {
        throw Exception(
            'Should return $itemCount transactions for target tenant, '
            'got ${targetTransactions.length}');
      }

      if (targetTransactions.any((t) => t.tenantId != targetTenant)) {
        throw Exception('All transactions should belong to target tenant');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1**
  ///
  /// Property: Empty result for non-existent tenant
  Glados(any.tenantId).test(
    'Empty result for non-existent tenant',
    (tenantId) {
      final transactions = [
        createTransaction(
          tenantId: 'different-tenant-1',
          items: [
            TransactionItem(
              productId: 'p1',
              productName: 'Product 1',
              quantity: 1,
              price: 10000,
              total: 10000,
            ),
          ],
        ),
        createTransaction(
          tenantId: 'different-tenant-2',
          items: [
            TransactionItem(
              productId: 'p2',
              productName: 'Product 2',
              quantity: 1,
              price: 20000,
              total: 20000,
            ),
          ],
        ),
      ];

      final tenantTransactions =
          TenantDataFilter.filterTransactionsByTenant(transactions, tenantId);

      if (tenantTransactions.isNotEmpty) {
        throw Exception('Should return empty list for non-existent tenant');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1, 2.3, 2.4, 2.5**
  ///
  /// Property: Data isolation is maintained with large datasets
  Glados2(any.tenantId, any.intInRange(10, 50)).test(
    'Data isolation maintained with large datasets',
    (targetTenant, itemCount) {
      // Create products for multiple tenants
      final products = <Product>[];

      // Add products for target tenant
      for (var i = 0; i < itemCount; i++) {
        products.add(createProduct(
          tenantId: targetTenant,
          name: 'Target Product $i',
        ));
      }

      // Add products for other tenants
      for (var i = 0; i < itemCount * 2; i++) {
        products.add(createProduct(
          tenantId: 'other-tenant-$i',
          name: 'Other Product $i',
        ));
      }

      final targetProducts =
          TenantDataFilter.filterProductsByTenant(products, targetTenant);

      if (targetProducts.length != itemCount) {
        throw Exception(
            'Should return exactly $itemCount products for target tenant, '
            'got ${targetProducts.length}');
      }

      if (targetProducts.any((p) => p.tenantId != targetTenant)) {
        throw Exception('All products should belong to target tenant');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1, 2.3, 2.4, 2.5**
  ///
  /// Property: Filtering preserves all data fields
  Glados(any.tenantId).test(
    'Filtering preserves all data fields',
    (tenantId) {
      final product = createProduct(
        tenantId: tenantId,
        name: 'Test Product',
        price: 25000,
      );
      final products = [product];

      final filtered =
          TenantDataFilter.filterProductsByTenant(products, tenantId);

      if (filtered.isEmpty) {
        throw Exception('Should find the product');
      }

      final found = filtered.first;
      if (found.id != product.id ||
          found.name != product.name ||
          found.price != product.price ||
          found.tenantId != product.tenantId) {
        throw Exception('Filtering should preserve all data fields');
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 1: Tenant Data Isolation**
  /// **Validates: Requirements 2.1, 2.3, 2.4, 2.5**
  ///
  /// Property: Concurrent tenant queries return correct isolated data
  Glados2(any.tenantId, any.tenantId).test(
    'Concurrent tenant queries return correct isolated data',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final products = [
        createProduct(tenantId: tenant1, name: 'T1 Product 1', price: 10000),
        createProduct(tenantId: tenant1, name: 'T1 Product 2', price: 20000),
        createProduct(tenantId: tenant2, name: 'T2 Product 1', price: 30000),
        createProduct(tenantId: tenant2, name: 'T2 Product 2', price: 40000),
        createProduct(tenantId: tenant2, name: 'T2 Product 3', price: 50000),
      ];

      // Simulate concurrent queries
      final result1 =
          TenantDataFilter.filterProductsByTenant(products, tenant1);
      final result2 =
          TenantDataFilter.filterProductsByTenant(products, tenant2);

      if (result1.length != 2) {
        throw Exception('Tenant 1 should have 2 products');
      }
      if (result2.length != 3) {
        throw Exception('Tenant 2 should have 3 products');
      }

      // Verify totals are correct per tenant
      final total1 = result1.fold<double>(0, (sum, p) => sum + p.price);
      final total2 = result2.fold<double>(0, (sum, p) => sum + p.price);

      if ((total1 - 30000).abs() > 0.01) {
        throw Exception('Tenant 1 total should be 30000, got $total1');
      }
      if ((total2 - 120000).abs() > 0.01) {
        throw Exception('Tenant 2 total should be 120000, got $total2');
      }
    },
  );
}
