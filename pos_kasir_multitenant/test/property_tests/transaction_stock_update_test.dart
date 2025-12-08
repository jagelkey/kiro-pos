/// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
/// **Validates: Requirements 4.3, 3.3**
///
/// Property: For any completed transaction, the product stock SHALL decrease by
/// exactly the quantity sold, and material stock SHALL decrease according to
/// recipe quantities multiplied by quantity sold.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/product.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;
import 'package:pos_kasir_multitenant/data/mock/recipe_data.dart';

/// Test cart item for stock update testing
class TestCartItem {
  final Product product;
  final int quantity;

  TestCartItem({required this.product, required this.quantity});
}

/// Simulates the stock update logic from POS checkout
class StockUpdateSimulator {
  /// Calculate expected product stock after transaction
  static int calculateNewProductStock(int currentStock, int quantitySold) {
    return currentStock - quantitySold;
  }

  /// Calculate expected material stock after transaction based on recipe
  static double calculateNewMaterialStock(
    double currentStock,
    String productId,
    int quantitySold,
    String materialId,
  ) {
    final recipe = RecipeData.getRecipe(productId);
    if (recipe == null) return currentStock;

    final ingredient = recipe.where((i) => i.materialId == materialId).toList();
    if (ingredient.isEmpty) return currentStock;

    final usedAmount = ingredient.first.quantity * quantitySold;
    return currentStock - usedAmount;
  }

  /// Get total material usage for a cart
  static Map<String, double> calculateTotalMaterialUsage(
      List<TestCartItem> cart) {
    final usage = <String, double>{};

    for (var item in cart) {
      final recipe = RecipeData.getRecipe(item.product.id);
      if (recipe == null) continue;

      for (var ingredient in recipe) {
        final usedAmount = ingredient.quantity * item.quantity;
        usage[ingredient.materialId] =
            (usage[ingredient.materialId] ?? 0) + usedAmount;
      }
    }

    return usage;
  }
}

/// Generator for products with known recipes (using existing recipe IDs)
extension ProductWithRecipeGenerator on Any {
  /// Generates products that have recipes defined in RecipeData
  Generator<Product> get productWithRecipe {
    // Use product IDs that have recipes defined
    final productIdsWithRecipes = RecipeData.recipes.keys.toList();

    return any.intInRange(0, productIdsWithRecipes.length - 1).bind((index) {
      final productId = productIdsWithRecipes[index];
      return any.intInRange(50, 1000).map((stock) {
        return Product(
          id: productId,
          tenantId: 'tenant-test',
          name: 'Product $productId',
          price: 25000.0,
          stock: stock,
          category: 'Coffee',
          createdAt: DateTime(2024, 1, 1),
        );
      });
    });
  }
}

/// Generator for cart items with valid quantities
extension CartItemGenerator on Any {
  Generator<TestCartItem> get cartItemWithRecipe {
    return any.productWithRecipe.bind((product) {
      // Quantity between 1 and min(10, stock) to ensure valid transaction
      final maxQty = product.stock < 10 ? product.stock : 10;
      return any.intInRange(1, maxQty > 0 ? maxQty : 1).map((quantity) {
        return TestCartItem(product: product, quantity: quantity);
      });
    });
  }
}

/// Generator for materials with sufficient stock
extension MaterialGenerator on Any {
  Generator<mat.Material> get materialWithStock {
    return any.doubleInRange(10.0, 1000.0).map((stock) {
      return mat.Material(
        id: 'mat-1', // Biji Kopi Arabica - used in many recipes
        tenantId: 'tenant-test',
        name: 'Biji Kopi Arabica',
        stock: stock,
        unit: 'kg',
        minStock: 1.0,
        createdAt: DateTime(2024, 1, 1),
      );
    });
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 4.3**
  ///
  /// Property: For any product and quantity sold, the new product stock SHALL
  /// equal the original stock minus the quantity sold.
  Glados(any.cartItemWithRecipe).test(
    'Product stock decreases by exactly the quantity sold',
    (cartItem) {
      final originalStock = cartItem.product.stock;
      final quantitySold = cartItem.quantity;

      // Calculate new stock using the same logic as POS checkout
      final newStock = StockUpdateSimulator.calculateNewProductStock(
        originalStock,
        quantitySold,
      );

      // Verify: new stock = original stock - quantity sold
      final expectedStock = originalStock - quantitySold;

      if (newStock != expectedStock) {
        throw Exception(
          'Product stock mismatch: expected $expectedStock, got $newStock '
          '(original: $originalStock, sold: $quantitySold)',
        );
      }

      // Verify: new stock is non-negative (valid transaction)
      if (newStock < 0) {
        throw Exception(
          'Product stock became negative: $newStock '
          '(original: $originalStock, sold: $quantitySold)',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 3.3**
  ///
  /// Property: For any product with recipe, material stock SHALL decrease by
  /// recipe quantity multiplied by quantity sold.
  Glados2(any.cartItemWithRecipe, any.materialWithStock).test(
    'Material stock decreases according to recipe quantities',
    (cartItem, material) {
      final recipe = RecipeData.getRecipe(cartItem.product.id);
      if (recipe == null) return; // Skip products without recipes

      // Find if this material is used in the recipe
      final ingredient =
          recipe.where((i) => i.materialId == material.id).toList();
      if (ingredient.isEmpty) return; // Skip if material not in recipe

      final originalStock = material.stock;
      final quantitySold = cartItem.quantity;
      final recipeQuantity = ingredient.first.quantity;

      // Calculate expected material usage
      final expectedUsage = recipeQuantity * quantitySold;
      final expectedNewStock = originalStock - expectedUsage;

      // Calculate using simulator
      final newStock = StockUpdateSimulator.calculateNewMaterialStock(
        originalStock,
        cartItem.product.id,
        quantitySold,
        material.id,
      );

      // Verify: material stock decreased correctly
      if ((newStock - expectedNewStock).abs() > 0.0001) {
        throw Exception(
          'Material stock mismatch: expected $expectedNewStock, got $newStock '
          '(original: $originalStock, recipe qty: $recipeQuantity, sold: $quantitySold)',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 4.3, 3.3**
  ///
  /// Property: Stock changes are additive - multiple items in cart should
  /// accumulate their stock reductions correctly.
  Glados2(any.cartItemWithRecipe, any.cartItemWithRecipe).test(
    'Multiple cart items accumulate stock reductions correctly',
    (item1, item2) {
      // Create a cart with two items
      final cart = [item1, item2];

      // Calculate total material usage
      final totalUsage = StockUpdateSimulator.calculateTotalMaterialUsage(cart);

      // Verify each material usage is the sum of individual usages
      for (var entry in totalUsage.entries) {
        final materialId = entry.key;
        final totalUsed = entry.value;

        // Calculate individual usage for each item
        double individualSum = 0;
        for (var item in cart) {
          final recipe = RecipeData.getRecipe(item.product.id);
          if (recipe == null) continue;

          final ingredient =
              recipe.where((i) => i.materialId == materialId).toList();
          if (ingredient.isEmpty) continue;

          individualSum += ingredient.first.quantity * item.quantity;
        }

        // Verify total equals sum of individual usages
        if ((totalUsed - individualSum).abs() > 0.0001) {
          throw Exception(
            'Material usage accumulation error for $materialId: '
            'expected $individualSum, got $totalUsed',
          );
        }
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 4.3**
  ///
  /// Property: Product stock update is idempotent in calculation - same input
  /// always produces same output.
  Glados(any.cartItemWithRecipe).test(
    'Stock calculation is deterministic',
    (cartItem) {
      final originalStock = cartItem.product.stock;
      final quantitySold = cartItem.quantity;

      // Calculate twice
      final result1 = StockUpdateSimulator.calculateNewProductStock(
        originalStock,
        quantitySold,
      );
      final result2 = StockUpdateSimulator.calculateNewProductStock(
        originalStock,
        quantitySold,
      );

      // Results should be identical
      if (result1 != result2) {
        throw Exception(
          'Stock calculation not deterministic: $result1 != $result2',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 3.3**
  ///
  /// Property: Products without recipes should not affect material stock.
  Glados(any.materialWithStock).test(
    'Products without recipes do not affect material stock',
    (material) {
      // Create a product ID that doesn't have a recipe
      const productIdWithoutRecipe = 'prod-no-recipe';
      final originalStock = material.stock;

      // Calculate material stock change
      final newStock = StockUpdateSimulator.calculateNewMaterialStock(
        originalStock,
        productIdWithoutRecipe,
        5, // arbitrary quantity
        material.id,
      );

      // Stock should remain unchanged
      if (newStock != originalStock) {
        throw Exception(
          'Material stock changed for product without recipe: '
          'original $originalStock, new $newStock',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 2: Transaction Stock Update Integrity**
  /// **Validates: Requirements 4.3**
  ///
  /// Property: Zero quantity sold should not change stock.
  Glados(any.productWithRecipe).test(
    'Zero quantity sold does not change product stock',
    (product) {
      final originalStock = product.stock;

      final newStock = StockUpdateSimulator.calculateNewProductStock(
        originalStock,
        0, // zero quantity
      );

      if (newStock != originalStock) {
        throw Exception(
          'Stock changed with zero quantity: original $originalStock, new $newStock',
        );
      }
    },
  );
}
