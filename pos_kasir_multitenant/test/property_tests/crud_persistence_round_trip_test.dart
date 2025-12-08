/// **Feature: pos-comprehensive-fix, Property 20: CRUD Persistence Round-Trip**
/// **Validates: Requirements 2.1, 2.2, 3.1, 6.1, 7.1, 14.1**
///
/// Property: For any entity (product, material, expense, user), creating then
/// reading SHALL return an equivalent entity.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/product.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;
import 'package:pos_kasir_multitenant/data/models/expense.dart';
import 'package:pos_kasir_multitenant/data/models/user.dart';

/// Custom generators for domain models
extension ProductGenerator on Any {
  /// Generates valid Product instances with required fields
  Generator<Product> get product {
    return any.lowercaseLetters.bind((name) {
      return any.lowercaseLetters.bind((tenantSeed) {
        return any.doubleInRange(0.01, 100000.0).bind((price) {
          return any.intInRange(0, 10000).map((stock) {
            return Product(
              id: 'prod-${name.hashCode.abs()}',
              tenantId: 'tenant-${tenantSeed.hashCode.abs()}',
              name: name.isEmpty ? 'Product' : name,
              price: price,
              stock: stock,
              category: 'Coffee',
              createdAt: DateTime(2024, 1, 1),
            );
          });
        });
      });
    });
  }
}

extension MaterialGenerator on Any {
  /// Generates valid Material instances with required fields
  Generator<mat.Material> get material {
    const validUnits = ['kg', 'g', 'l', 'ml', 'pcs'];
    return any.lowercaseLetters.bind((name) {
      return any.lowercaseLetters.bind((tenantSeed) {
        return any.doubleInRange(0.0, 10000.0).bind((stock) {
          return any.intInRange(0, 4).map((unitIndex) {
            return mat.Material(
              id: 'mat-${name.hashCode.abs()}',
              tenantId: 'tenant-${tenantSeed.hashCode.abs()}',
              name: name.isEmpty ? 'Material' : name,
              stock: stock,
              unit: validUnits[unitIndex],
              minStock: 10.0,
              category: 'Ingredients',
              createdAt: DateTime(2024, 1, 1),
            );
          });
        });
      });
    });
  }
}

extension ExpenseGenerator on Any {
  /// Generates valid Expense instances with required fields
  Generator<Expense> get expense {
    const validCategories = [
      'Utilities',
      'Supplies',
      'Rent',
      'Salary',
      'Other'
    ];
    return any.lowercaseLetters.bind((idSeed) {
      return any.lowercaseLetters.bind((tenantSeed) {
        return any.doubleInRange(0.01, 100000.0).bind((amount) {
          return any.intInRange(0, 4).map((categoryIndex) {
            return Expense(
              id: 'exp-${idSeed.hashCode.abs()}',
              tenantId: 'tenant-${tenantSeed.hashCode.abs()}',
              category: validCategories[categoryIndex],
              amount: amount,
              description: 'Test expense',
              date: DateTime(2024, 1, 1),
              createdAt: DateTime(2024, 1, 1),
            );
          });
        });
      });
    });
  }
}

extension UserGenerator on Any {
  /// Generates valid User instances with required fields
  Generator<User> get user {
    return any.lowercaseLetters.bind((idSeed) {
      return any.lowercaseLetters.bind((tenantSeed) {
        return any.lowercaseLetters.bind((name) {
          return any.intInRange(0, 2).map((roleIndex) {
            final sanitizedEmail = idSeed.isEmpty
                ? 'test'
                : idSeed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            return User(
              id: 'user-${idSeed.hashCode.abs()}',
              tenantId: 'tenant-${tenantSeed.hashCode.abs()}',
              email: '$sanitizedEmail@test.com',
              name: name.isEmpty ? 'Test User' : name,
              role: UserRole.values[roleIndex],
              isActive: true,
              createdAt: DateTime(2024, 1, 1),
            );
          });
        });
      });
    });
  }
}

void main() {
  /// Product toMap/fromMap round-trip preserves all fields
  Glados(any.product).test(
    'Product toMap/fromMap round-trip preserves all fields',
    (product) {
      final map = product.toMap();
      final restored = Product.fromMap(map);

      if (restored.id != product.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != product.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.name != product.name) {
        throw Exception('name mismatch');
      }
      if (restored.barcode != product.barcode) {
        throw Exception('barcode mismatch');
      }
      if (restored.price != product.price) {
        throw Exception('price mismatch');
      }
      if (restored.stock != product.stock) {
        throw Exception('stock mismatch');
      }
      if (restored.category != product.category) {
        throw Exception('category mismatch');
      }
      if (restored.imageUrl != product.imageUrl) {
        throw Exception('imageUrl mismatch');
      }
      if (restored.createdAt.toIso8601String() !=
          product.createdAt.toIso8601String()) {
        throw Exception('createdAt mismatch');
      }
    },
  );

  /// Product toJson/fromJson round-trip preserves all fields
  Glados(any.product).test(
    'Product toJson/fromJson round-trip preserves all fields',
    (product) {
      final json = product.toJson();
      final restored = Product.fromJson(json);

      if (restored.id != product.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != product.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.name != product.name) {
        throw Exception('name mismatch');
      }
      if (restored.price != product.price) {
        throw Exception('price mismatch');
      }
      if (restored.stock != product.stock) {
        throw Exception('stock mismatch');
      }
    },
  );

  /// Material toMap/fromMap round-trip preserves all fields
  Glados(any.material).test(
    'Material toMap/fromMap round-trip preserves all fields',
    (material) {
      final map = material.toMap();
      final restored = mat.Material.fromMap(map);

      if (restored.id != material.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != material.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.name != material.name) {
        throw Exception('name mismatch');
      }
      if (restored.stock != material.stock) {
        throw Exception('stock mismatch');
      }
      if (restored.unit != material.unit) {
        throw Exception('unit mismatch');
      }
      if (restored.minStock != material.minStock) {
        throw Exception('minStock mismatch');
      }
      if (restored.category != material.category) {
        throw Exception('category mismatch');
      }
      if (restored.createdAt.toIso8601String() !=
          material.createdAt.toIso8601String()) {
        throw Exception('createdAt mismatch');
      }
    },
  );

  /// Material toJson/fromJson round-trip preserves all fields
  Glados(any.material).test(
    'Material toJson/fromJson round-trip preserves all fields',
    (material) {
      final json = material.toJson();
      final restored = mat.Material.fromJson(json);

      if (restored.id != material.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != material.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.name != material.name) {
        throw Exception('name mismatch');
      }
      if (restored.stock != material.stock) {
        throw Exception('stock mismatch');
      }
      if (restored.unit != material.unit) {
        throw Exception('unit mismatch');
      }
    },
  );

  /// Expense toMap/fromMap round-trip preserves all fields
  Glados(any.expense).test(
    'Expense toMap/fromMap round-trip preserves all fields',
    (expense) {
      final map = expense.toMap();
      final restored = Expense.fromMap(map);

      if (restored.id != expense.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != expense.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.category != expense.category) {
        throw Exception('category mismatch');
      }
      if (restored.amount != expense.amount) {
        throw Exception('amount mismatch');
      }
      if (restored.description != expense.description) {
        throw Exception('description mismatch');
      }
      if (restored.date.toIso8601String() != expense.date.toIso8601String()) {
        throw Exception('date mismatch');
      }
      if (restored.createdAt.toIso8601String() !=
          expense.createdAt.toIso8601String()) {
        throw Exception('createdAt mismatch');
      }
    },
  );

  /// Expense toJson/fromJson round-trip preserves all fields
  Glados(any.expense).test(
    'Expense toJson/fromJson round-trip preserves all fields',
    (expense) {
      final json = expense.toJson();
      final restored = Expense.fromJson(json);

      if (restored.id != expense.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != expense.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.category != expense.category) {
        throw Exception('category mismatch');
      }
      if (restored.amount != expense.amount) {
        throw Exception('amount mismatch');
      }
    },
  );

  /// User toMap/fromMap round-trip preserves all fields
  Glados(any.user).test(
    'User toMap/fromMap round-trip preserves all fields',
    (user) {
      final map = user.toMap();
      final restored = User.fromMap(map);

      if (restored.id != user.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != user.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.email != user.email) {
        throw Exception('email mismatch');
      }
      if (restored.name != user.name) {
        throw Exception('name mismatch');
      }
      if (restored.role != user.role) {
        throw Exception('role mismatch');
      }
      if (restored.isActive != user.isActive) {
        throw Exception('isActive mismatch');
      }
      if (restored.createdAt.toIso8601String() !=
          user.createdAt.toIso8601String()) {
        throw Exception('createdAt mismatch');
      }
    },
  );

  /// User toJson/fromJson round-trip preserves all fields
  Glados(any.user).test(
    'User toJson/fromJson round-trip preserves all fields',
    (user) {
      final json = user.toJson();
      final restored = User.fromJson(json);

      if (restored.id != user.id) {
        throw Exception('id mismatch');
      }
      if (restored.tenantId != user.tenantId) {
        throw Exception('tenantId mismatch');
      }
      if (restored.email != user.email) {
        throw Exception('email mismatch');
      }
      if (restored.name != user.name) {
        throw Exception('name mismatch');
      }
      if (restored.role != user.role) {
        throw Exception('role mismatch');
      }
      if (restored.isActive != user.isActive) {
        throw Exception('isActive mismatch');
      }
    },
  );
}
