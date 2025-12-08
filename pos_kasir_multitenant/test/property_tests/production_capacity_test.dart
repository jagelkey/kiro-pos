/// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
/// **Validates: Requirements 3.5, 8.4**
///
/// Property: For any product with recipe, the production capacity SHALL equal
/// the minimum of (material stock / recipe quantity) across all materials in the recipe.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;

/// Recipe ingredient for testing
class TestRecipeIngredient {
  final String materialId;
  final double quantity;
  final String unit;
  final String name;

  TestRecipeIngredient({
    required this.materialId,
    required this.quantity,
    required this.unit,
    required this.name,
  });
}

/// Production capacity calculator (mirrors logic from RecipeData and DashboardProvider)
class ProductionCapacityCalculator {
  /// Calculate max servings for a product based on material stock and recipe
  /// Requirements 3.5, 8.4: Calculate based on material stock and recipes
  static int calculateMaxServings(
    List<TestRecipeIngredient> recipe,
    List<mat.Material> materials,
  ) {
    if (recipe.isEmpty) return -1; // No recipe means unlimited

    int minCapacity = 999999;

    for (final ingredient in recipe) {
      // Find material by ID
      mat.Material? material;
      try {
        material = materials.firstWhere((m) => m.id == ingredient.materialId);
      } catch (e) {
        material = null;
      }

      if (material == null || material.stock <= 0) {
        return 0; // Material not found or out of stock
      }

      final availableStock = _convertToBaseUnit(material.stock, material.unit);
      final neededPerServing =
          _convertToBaseUnit(ingredient.quantity, ingredient.unit);

      if (neededPerServing > 0) {
        final possibleServings = (availableStock / neededPerServing).floor();
        if (possibleServings < minCapacity) {
          minCapacity = possibleServings;
        }
      }
    }

    return minCapacity == 999999 ? 0 : minCapacity;
  }

  /// Convert units to base unit for comparison
  static double _convertToBaseUnit(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return value * 1000; // Convert to grams
      case 'gram':
      case 'g':
        return value;
      case 'liter':
      case 'l':
        return value * 1000; // Convert to ml
      case 'ml':
        return value;
      default:
        return value; // For units like 'pcs', 'sachet', 'botol'
    }
  }
}

/// Generator for valid material with positive stock
extension MaterialGenerator on Any {
  Generator<mat.Material> get materialWithStock {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(0.1, 100.0).bind((stock) {
        return any.intInRange(0, 3).map((unitIndex) {
          final units = ['kg', 'liter', 'pcs', 'sachet'];
          final materialName = name.isEmpty ? 'Material' : name;
          return mat.Material(
            id: 'mat-${materialName.hashCode.abs()}',
            tenantId: 'tenant-test',
            name: materialName,
            stock: stock,
            unit: units[unitIndex],
            minStock: stock * 0.2,
            category: 'Test Category',
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }

  Generator<mat.Material> get materialOutOfStock {
    return any.lowercaseLetters.bind((name) {
      return any.intInRange(0, 3).map((unitIndex) {
        final units = ['kg', 'liter', 'pcs', 'sachet'];
        final materialName = name.isEmpty ? 'Material' : name;
        return mat.Material(
          id: 'mat-${materialName.hashCode.abs()}',
          tenantId: 'tenant-test',
          name: materialName,
          stock: 0,
          unit: units[unitIndex],
          minStock: 1,
          category: 'Test Category',
          createdAt: DateTime.now(),
        );
      });
    });
  }
}

/// Generator for recipe ingredient that matches a material
extension RecipeIngredientGenerator on Any {
  Generator<TestRecipeIngredient> recipeIngredientFor(mat.Material material) {
    return any.doubleInRange(0.01, 1.0).map((quantity) {
      return TestRecipeIngredient(
        materialId: material.id,
        quantity: quantity,
        unit: material.unit,
        name: material.name,
      );
    });
  }
}

/// Generator for a product with recipe and matching materials
extension ProductWithRecipeGenerator on Any {
  /// Generate a single material with its recipe ingredient
  Generator<(mat.Material, TestRecipeIngredient)> get materialWithIngredient {
    return any.materialWithStock.bind((material) {
      return any.recipeIngredientFor(material).map((ingredient) {
        return (material, ingredient);
      });
    });
  }

  /// Generate exactly 2 materials with their recipe ingredients
  Generator<(List<mat.Material>, List<TestRecipeIngredient>)>
      get materialsWithRecipe {
    return any.materialWithIngredient.bind((pair1) {
      return any.materialWithIngredient.map((pair2) {
        // Ensure unique material IDs
        final mat2 = mat.Material(
          id: '${pair2.$1.id}-2',
          tenantId: pair2.$1.tenantId,
          name: '${pair2.$1.name}2',
          stock: pair2.$1.stock,
          unit: pair2.$1.unit,
          minStock: pair2.$1.minStock,
          category: pair2.$1.category,
          createdAt: pair2.$1.createdAt,
        );
        final ing2 = TestRecipeIngredient(
          materialId: mat2.id,
          quantity: pair2.$2.quantity,
          unit: pair2.$2.unit,
          name: mat2.name,
        );
        return (
          [pair1.$1, mat2],
          [pair1.$2, ing2],
        );
      });
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 3.5, 8.4**
  ///
  /// Property: Production capacity equals minimum of (stock / recipe quantity)
  /// across all materials in the recipe
  Glados(any.materialsWithRecipe).test(
    'Production capacity equals minimum capacity across all materials',
    (data) {
      final (materials, recipe) = data;

      final calculatedCapacity =
          ProductionCapacityCalculator.calculateMaxServings(recipe, materials);

      // Calculate expected capacity manually
      int expectedCapacity = 999999;
      for (int i = 0; i < recipe.length; i++) {
        final ingredient = recipe[i];
        final material = materials.firstWhere(
          (m) => m.id == ingredient.materialId,
        );

        final availableStock = ProductionCapacityCalculator._convertToBaseUnit(
          material.stock,
          material.unit,
        );
        final neededPerServing =
            ProductionCapacityCalculator._convertToBaseUnit(
          ingredient.quantity,
          ingredient.unit,
        );

        if (neededPerServing > 0) {
          final possibleServings = (availableStock / neededPerServing).floor();
          if (possibleServings < expectedCapacity) {
            expectedCapacity = possibleServings;
          }
        }
      }
      expectedCapacity = expectedCapacity == 999999 ? 0 : expectedCapacity;

      if (calculatedCapacity != expectedCapacity) {
        throw Exception(
          'Capacity mismatch: calculated $calculatedCapacity, expected $expectedCapacity',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 3.5**
  ///
  /// Property: Capacity is limited by the material with lowest availability
  Glados(any.materialsWithRecipe).test(
    'Capacity is limited by material with lowest availability',
    (data) {
      final (materials, recipe) = data;

      final capacity =
          ProductionCapacityCalculator.calculateMaxServings(recipe, materials);

      // For each material, verify that capacity doesn't exceed what that material allows
      for (int i = 0; i < recipe.length; i++) {
        final ingredient = recipe[i];
        final material = materials.firstWhere(
          (m) => m.id == ingredient.materialId,
        );

        final availableStock = ProductionCapacityCalculator._convertToBaseUnit(
          material.stock,
          material.unit,
        );
        final neededPerServing =
            ProductionCapacityCalculator._convertToBaseUnit(
          ingredient.quantity,
          ingredient.unit,
        );

        if (neededPerServing > 0) {
          final maxFromThisMaterial =
              (availableStock / neededPerServing).floor();
          if (capacity > maxFromThisMaterial) {
            throw Exception(
              'Capacity $capacity exceeds what material ${material.name} allows ($maxFromThisMaterial)',
            );
          }
        }
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 8.4**
  ///
  /// Property: Empty recipe returns -1 (unlimited/no recipe)
  Glados(any.materialWithStock).test(
    'Empty recipe returns -1 indicating no recipe',
    (material) {
      final capacity = ProductionCapacityCalculator.calculateMaxServings(
        [], // Empty recipe
        [material],
      );

      if (capacity != -1) {
        throw Exception(
          'Empty recipe should return -1, got $capacity',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 3.5, 8.4**
  ///
  /// Property: Missing material in inventory returns 0 capacity
  Glados(any.materialWithStock).test(
    'Missing material returns 0 capacity',
    (material) {
      // Create recipe that requires a material not in inventory
      final recipe = [
        TestRecipeIngredient(
          materialId: 'non-existent-material',
          quantity: 1.0,
          unit: 'kg',
          name: 'Missing Material',
        ),
      ];

      final capacity = ProductionCapacityCalculator.calculateMaxServings(
        recipe,
        [material], // Material in inventory doesn't match recipe
      );

      if (capacity != 0) {
        throw Exception(
          'Missing material should return 0 capacity, got $capacity',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 3.5, 8.4**
  ///
  /// Property: Zero stock material returns 0 capacity
  Glados(any.materialOutOfStock).test(
    'Zero stock material returns 0 capacity',
    (material) {
      final recipe = [
        TestRecipeIngredient(
          materialId: material.id,
          quantity: 0.1,
          unit: material.unit,
          name: material.name,
        ),
      ];

      final capacity = ProductionCapacityCalculator.calculateMaxServings(
        recipe,
        [material],
      );

      if (capacity != 0) {
        throw Exception(
          'Zero stock should return 0 capacity, got $capacity',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 3.5**
  ///
  /// Property: Doubling stock doubles capacity (or increases by at least factor of 2)
  Glados(any.materialWithIngredient).test(
    'Doubling stock at least doubles capacity',
    (data) {
      final (material, ingredient) = data;

      final originalCapacity =
          ProductionCapacityCalculator.calculateMaxServings(
        [ingredient],
        [material],
      );

      // Create material with doubled stock
      final doubledMaterial = mat.Material(
        id: material.id,
        tenantId: material.tenantId,
        name: material.name,
        stock: material.stock * 2,
        unit: material.unit,
        minStock: material.minStock,
        category: material.category,
        createdAt: material.createdAt,
      );

      final doubledCapacity = ProductionCapacityCalculator.calculateMaxServings(
        [ingredient],
        [doubledMaterial],
      );

      // Doubling stock should at least double capacity (floor division may cause slight variance)
      // We check that doubled capacity is at least 2x original (accounting for floor)
      if (originalCapacity > 0 && doubledCapacity < originalCapacity * 2) {
        throw Exception(
          'Doubling stock should at least double capacity: original $originalCapacity, doubled $doubledCapacity',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 7: Production Capacity Calculation**
  /// **Validates: Requirements 8.4**
  ///
  /// Property: Unit conversion is consistent (kg to gram, liter to ml)
  Glados(any.doubleInRange(1.0, 10.0)).test(
    'Unit conversion is consistent',
    (value) {
      // Test kg to gram conversion
      final kgValue =
          ProductionCapacityCalculator._convertToBaseUnit(value, 'kg');
      final gramValue =
          ProductionCapacityCalculator._convertToBaseUnit(value * 1000, 'gram');

      if ((kgValue - gramValue).abs() > 0.001) {
        throw Exception(
          'kg to gram conversion inconsistent: $value kg = $kgValue, ${value * 1000} gram = $gramValue',
        );
      }

      // Test liter to ml conversion
      final literValue =
          ProductionCapacityCalculator._convertToBaseUnit(value, 'liter');
      final mlValue =
          ProductionCapacityCalculator._convertToBaseUnit(value * 1000, 'ml');

      if ((literValue - mlValue).abs() > 0.001) {
        throw Exception(
          'liter to ml conversion inconsistent: $value liter = $literValue, ${value * 1000} ml = $mlValue',
        );
      }
    },
  );
}
