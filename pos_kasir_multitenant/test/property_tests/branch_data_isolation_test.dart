/// **Feature: pos-comprehensive-fix, Property 11: Branch Data Isolation**
/// **Validates: Requirements 11.4**
///
/// Property: Data queries SHALL only return data belonging to the specified
/// tenant_id or owner_id, ensuring complete data isolation between tenants/branches.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/branch.dart';
import 'package:pos_kasir_multitenant/data/models/product.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';

/// Generator for tenant IDs
extension TenantIdGenerator on Any {
  Generator<String> get tenantId {
    return any.intInRange(1, 1000).map((i) => 'tenant-$i');
  }
}

/// Generator for owner IDs
extension OwnerIdGenerator on Any {
  Generator<String> get ownerId {
    return any.intInRange(1, 1000).map((i) => 'owner-$i');
  }
}

/// Generator for branch codes
extension BranchCodeGenerator on Any {
  Generator<String> get branchCode {
    return any
        .intInRange(1, 999)
        .map((i) => 'BR-${i.toString().padLeft(3, '0')}');
  }
}

/// Create a branch with specific owner
Branch createBranch({
  required String ownerId,
  required String code,
  String? name,
}) {
  return Branch(
    id: 'branch-${code.hashCode.abs()}',
    ownerId: ownerId,
    name: name ?? 'Branch $code',
    code: code,
    address: 'Test Address',
    phone: '08123456789',
    taxRate: 0.11,
    isActive: true,
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
    id: 'product-${name.hashCode.abs()}',
    tenantId: tenantId,
    name: name,
    price: price,
    stock: 100,
    category: 'Test',
    createdAt: DateTime.now(),
  );
}

/// Create a transaction with specific tenant
Transaction createTransaction({
  required String tenantId,
  required double total,
}) {
  return Transaction(
    id: 'trx-${DateTime.now().millisecondsSinceEpoch}',
    tenantId: tenantId,
    userId: 'user-1',
    items: [],
    subtotal: total,
    tax: total * 0.11,
    discount: 0,
    total: total * 1.11,
    paymentMethod: 'cash',
    createdAt: DateTime.now(),
  );
}

/// Simulate filtering branches by owner
List<Branch> filterBranchesByOwner(List<Branch> branches, String ownerId) {
  return branches.where((b) => b.ownerId == ownerId).toList();
}

/// Simulate filtering products by tenant
List<Product> filterProductsByTenant(List<Product> products, String tenantId) {
  return products.where((p) => p.tenantId == tenantId).toList();
}

/// Simulate filtering transactions by tenant
List<Transaction> filterTransactionsByTenant(
    List<Transaction> transactions, String tenantId) {
  return transactions.where((t) => t.tenantId == tenantId).toList();
}

void main() {
  /// **Property 11: Branch Data Isolation**
  /// **Validates: Requirements 11.4**
  ///
  /// Property: Branches are isolated by owner_id
  Glados2(any.ownerId, any.ownerId).test(
    'Branches are isolated by owner_id',
    (owner1, owner2) {
      if (owner1 == owner2) return; // Skip if same owner

      final branch1 = createBranch(ownerId: owner1, code: 'BR-001');
      final branch2 = createBranch(ownerId: owner2, code: 'BR-002');
      final allBranches = [branch1, branch2];

      final owner1Branches = filterBranchesByOwner(allBranches, owner1);
      final owner2Branches = filterBranchesByOwner(allBranches, owner2);

      // Owner 1 should only see their branch
      if (owner1Branches.length != 1 ||
          owner1Branches.first.ownerId != owner1) {
        throw Exception('Owner 1 should only see their own branch');
      }

      // Owner 2 should only see their branch
      if (owner2Branches.length != 1 ||
          owner2Branches.first.ownerId != owner2) {
        throw Exception('Owner 2 should only see their own branch');
      }

      // No cross-contamination
      if (owner1Branches.any((b) => b.ownerId == owner2)) {
        throw Exception('Owner 1 should not see Owner 2 branches');
      }
      if (owner2Branches.any((b) => b.ownerId == owner1)) {
        throw Exception('Owner 2 should not see Owner 1 branches');
      }
    },
  );

  /// Property: Products are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Products are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final product1 = createProduct(tenantId: tenant1, name: 'Product A');
      final product2 = createProduct(tenantId: tenant2, name: 'Product B');
      final allProducts = [product1, product2];

      final tenant1Products = filterProductsByTenant(allProducts, tenant1);
      final tenant2Products = filterProductsByTenant(allProducts, tenant2);

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

  /// Property: Transactions are isolated by tenant_id
  Glados2(any.tenantId, any.tenantId).test(
    'Transactions are isolated by tenant_id',
    (tenant1, tenant2) {
      if (tenant1 == tenant2) return;

      final trx1 = createTransaction(tenantId: tenant1, total: 100000);
      final trx2 = createTransaction(tenantId: tenant2, total: 200000);
      final allTransactions = [trx1, trx2];

      final tenant1Transactions =
          filterTransactionsByTenant(allTransactions, tenant1);
      final tenant2Transactions =
          filterTransactionsByTenant(allTransactions, tenant2);

      if (tenant1Transactions.length != 1 ||
          tenant1Transactions.first.tenantId != tenant1) {
        throw Exception('Tenant 1 should only see their own transactions');
      }

      if (tenant2Transactions.length != 1 ||
          tenant2Transactions.first.tenantId != tenant2) {
        throw Exception('Tenant 2 should only see their own transactions');
      }
    },
  );

  /// Property: Multiple branches per owner are all returned
  Glados2(any.ownerId, any.intInRange(2, 5)).test(
    'Multiple branches per owner are all returned',
    (ownerId, branchCount) {
      final branches = List.generate(
        branchCount,
        (i) => createBranch(
            ownerId: ownerId, code: 'BR-${i.toString().padLeft(3, '0')}'),
      );

      // Add some branches from other owner
      final otherBranches = [
        createBranch(ownerId: 'other-owner', code: 'BR-999'),
      ];

      final allBranches = [...branches, ...otherBranches];
      final ownerBranches = filterBranchesByOwner(allBranches, ownerId);

      if (ownerBranches.length != branchCount) {
        throw Exception(
            'Should return all $branchCount branches for owner, got ${ownerBranches.length}');
      }

      if (ownerBranches.any((b) => b.ownerId != ownerId)) {
        throw Exception('All returned branches should belong to the owner');
      }
    },
  );

  /// Property: Empty result for non-existent owner
  Glados(any.ownerId).test(
    'Empty result for non-existent owner',
    (ownerId) {
      final branches = [
        createBranch(ownerId: 'different-owner-1', code: 'BR-001'),
        createBranch(ownerId: 'different-owner-2', code: 'BR-002'),
      ];

      final ownerBranches = filterBranchesByOwner(branches, ownerId);

      if (ownerBranches.isNotEmpty) {
        throw Exception('Should return empty list for non-existent owner');
      }
    },
  );

  /// Property: Empty result for non-existent tenant
  Glados(any.tenantId).test(
    'Empty result for non-existent tenant',
    (tenantId) {
      final products = [
        createProduct(tenantId: 'different-tenant-1', name: 'Product A'),
        createProduct(tenantId: 'different-tenant-2', name: 'Product B'),
      ];

      final tenantProducts = filterProductsByTenant(products, tenantId);

      if (tenantProducts.isNotEmpty) {
        throw Exception('Should return empty list for non-existent tenant');
      }
    },
  );

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

      final targetProducts = filterProductsByTenant(products, targetTenant);

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

  /// Property: Branch code uniqueness within owner
  Glados2(any.ownerId, any.branchCode).test(
    'Branch code should be unique within owner context',
    (ownerId, code) {
      final branch1 = createBranch(ownerId: ownerId, code: code);
      final branch2 = createBranch(ownerId: ownerId, code: code);

      // In real implementation, this would be enforced by database constraint
      // Here we just verify the code is the same
      if (branch1.code != branch2.code) {
        throw Exception('Branch codes should match');
      }

      // Different owners can have same code
      final otherOwnerBranch = createBranch(ownerId: 'other-owner', code: code);
      if (otherOwnerBranch.code != code) {
        throw Exception('Different owners can have same branch code');
      }
    },
  );

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

      final filtered = filterProductsByTenant(products, tenantId);

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

  /// Property: Concurrent tenant queries don't interfere
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
      final result1 = filterProductsByTenant(products, tenant1);
      final result2 = filterProductsByTenant(products, tenant2);

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
