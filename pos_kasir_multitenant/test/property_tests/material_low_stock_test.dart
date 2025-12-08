/// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
/// **Validates: Requirements 3.4**
///
/// Property: For any material with minStock defined, the low stock warning SHALL
/// be displayed if and only if current stock is less than or equal to minStock.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;

/// Generator for materials with various stock levels relative to minStock
extension MaterialLowStockGenerator on Any {
  /// Generate material with stock below minStock (should be low stock)
  Generator<mat.Material> get materialBelowMinStock {
    return any.doubleInRange(1.0, 100.0).bind((minStock) {
      // Stock is between 0.01 and minStock (exclusive of 0 to avoid out of stock)
      return any.doubleInRange(0.01, minStock * 0.99).bind((stock) {
        return any.lowercaseLetters.map((name) {
          final materialName = name.isEmpty ? 'Material' : name;
          return mat.Material(
            id: 'mat-${DateTime.now().microsecondsSinceEpoch}',
            tenantId: 'tenant-test',
            name: materialName,
            stock: stock,
            unit: 'kg',
            minStock: minStock,
            category: 'Test',
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }

  /// Generate material with stock equal to minStock (should be low stock)
  Generator<mat.Material> get materialEqualToMinStock {
    return any.doubleInRange(0.1, 100.0).bind((minStock) {
      return any.lowercaseLetters.map((name) {
        final materialName = name.isEmpty ? 'Material' : name;
        return mat.Material(
          id: 'mat-${DateTime.now().microsecondsSinceEpoch}',
          tenantId: 'tenant-test',
          name: materialName,
          stock: minStock, // Stock equals minStock
          unit: 'kg',
          minStock: minStock,
          category: 'Test',
          createdAt: DateTime.now(),
        );
      });
    });
  }

  /// Generate material with stock above minStock (should NOT be low stock)
  Generator<mat.Material> get materialAboveMinStock {
    return any.doubleInRange(1.0, 50.0).bind((minStock) {
      // Stock is above minStock
      return any.doubleInRange(minStock * 1.01, minStock * 10.0).bind((stock) {
        return any.lowercaseLetters.map((name) {
          final materialName = name.isEmpty ? 'Material' : name;
          return mat.Material(
            id: 'mat-${DateTime.now().microsecondsSinceEpoch}',
            tenantId: 'tenant-test',
            name: materialName,
            stock: stock,
            unit: 'kg',
            minStock: minStock,
            category: 'Test',
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }

  /// Generate material with no minStock defined (should NOT be low stock)
  Generator<mat.Material> get materialWithoutMinStock {
    return any.doubleInRange(0.1, 100.0).bind((stock) {
      return any.lowercaseLetters.map((name) {
        final materialName = name.isEmpty ? 'Material' : name;
        return mat.Material(
          id: 'mat-${DateTime.now().microsecondsSinceEpoch}',
          tenantId: 'tenant-test',
          name: materialName,
          stock: stock,
          unit: 'kg',
          minStock: null, // No minStock defined
          category: 'Test',
          createdAt: DateTime.now(),
        );
      });
    });
  }

  /// Generate material with zero stock (out of stock, not low stock)
  Generator<mat.Material> get materialOutOfStock {
    return any.doubleInRange(1.0, 100.0).bind((minStock) {
      return any.lowercaseLetters.map((name) {
        final materialName = name.isEmpty ? 'Material' : name;
        return mat.Material(
          id: 'mat-${DateTime.now().microsecondsSinceEpoch}',
          tenantId: 'tenant-test',
          name: materialName,
          stock: 0, // Zero stock
          unit: 'kg',
          minStock: minStock,
          category: 'Test',
          createdAt: DateTime.now(),
        );
      });
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Material with stock below minStock should be flagged as low stock
  Glados(any.materialBelowMinStock).test(
    'Material with stock below minStock is flagged as low stock',
    (material) {
      if (!material.isLowStock) {
        throw Exception(
          'Material with stock ${material.stock} below minStock ${material.minStock} '
          'should be flagged as low stock, but isLowStock=${material.isLowStock}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Material with stock equal to minStock should be flagged as low stock
  Glados(any.materialEqualToMinStock).test(
    'Material with stock equal to minStock is flagged as low stock',
    (material) {
      if (!material.isLowStock) {
        throw Exception(
          'Material with stock ${material.stock} equal to minStock ${material.minStock} '
          'should be flagged as low stock, but isLowStock=${material.isLowStock}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Material with stock above minStock should NOT be flagged as low stock
  Glados(any.materialAboveMinStock).test(
    'Material with stock above minStock is NOT flagged as low stock',
    (material) {
      if (material.isLowStock) {
        throw Exception(
          'Material with stock ${material.stock} above minStock ${material.minStock} '
          'should NOT be flagged as low stock, but isLowStock=${material.isLowStock}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Material without minStock defined should NOT be flagged as low stock
  Glados(any.materialWithoutMinStock).test(
    'Material without minStock is NOT flagged as low stock',
    (material) {
      if (material.isLowStock) {
        throw Exception(
          'Material without minStock defined should NOT be flagged as low stock, '
          'but isLowStock=${material.isLowStock}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Material with zero stock is out of stock, not low stock
  /// (Low stock warning is for stock > 0 but <= minStock)
  Glados(any.materialOutOfStock).test(
    'Material with zero stock is out of stock, not low stock',
    (material) {
      // Zero stock should be out of stock
      if (!material.isOutOfStock) {
        throw Exception(
          'Material with zero stock should be out of stock, '
          'but isOutOfStock=${material.isOutOfStock}',
        );
      }
      // Zero stock should NOT be flagged as low stock (it's worse - out of stock)
      if (material.isLowStock) {
        throw Exception(
          'Material with zero stock should NOT be flagged as low stock '
          '(it is out of stock instead), but isLowStock=${material.isLowStock}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 6: Material Low Stock Detection**
  /// **Validates: Requirements 3.4**
  ///
  /// Property: Low stock detection is consistent - if stock <= minStock and stock > 0,
  /// then isLowStock must be true
  Glados2(any.doubleInRange(0.01, 100.0), any.doubleInRange(0.01, 100.0)).test(
    'Low stock detection is consistent with stock and minStock values',
    (stock, minStock) {
      final material = mat.Material(
        id: 'mat-test',
        tenantId: 'tenant-test',
        name: 'Test Material',
        stock: stock,
        unit: 'kg',
        minStock: minStock,
        category: 'Test',
        createdAt: DateTime.now(),
      );

      final expectedLowStock = stock > 0 && stock <= minStock;

      if (material.isLowStock != expectedLowStock) {
        throw Exception(
          'Low stock detection inconsistent: stock=$stock, minStock=$minStock, '
          'expected isLowStock=$expectedLowStock, actual=${material.isLowStock}',
        );
      }
    },
  );
}
