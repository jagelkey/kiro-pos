import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/material.dart' as mat;
import 'product_repository.dart';

/// Recipe ingredient model with multi-tenant support
class RecipeIngredient {
  final String materialId;
  double quantity;
  String unit;
  String name;

  RecipeIngredient({
    required this.materialId,
    required this.quantity,
    required this.unit,
    required this.name,
  });

  RecipeIngredient copyWith({double? quantity, String? unit, String? name}) {
    return RecipeIngredient(
      materialId: materialId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
        'material_id': materialId,
        'quantity': quantity,
        'unit': unit,
        'name': name,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        materialId: json['material_id'],
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'],
        name: json['name'],
      );
}

/// Material status for recipe display
class MaterialStatus {
  final String materialId;
  final String materialName;
  final double neededPerServing;
  final String unit;
  final double currentStock;
  final bool isAvailable;

  MaterialStatus({
    required this.materialId,
    required this.materialName,
    required this.neededPerServing,
    required this.unit,
    required this.currentStock,
    required this.isAvailable,
  });

  int get maxServings {
    if (neededPerServing <= 0) return 0;
    return (currentStock / neededPerServing).floor();
  }
}

/// Recipe Repository with multi-tenant support
class RecipeRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - keyed by tenantId then productId
  // Using UUID format for consistency with MockData.tenantId
  static final Map<String, Map<String, List<RecipeIngredient>>> _webRecipes = {
    '11111111-1111-1111-1111-111111111111': _defaultDemoRecipes,
  };

  // Default demo recipes for demo tenant
  static final Map<String, List<RecipeIngredient>> _defaultDemoRecipes = {
    // Hot Coffee
    'prod-1': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica')
    ],
    'prod-2': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica')
    ],
    'prod-3': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.15,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    'prod-4': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    'prod-5': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.15,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
      RecipeIngredient(
          materialId: 'mat-8',
          quantity: 0.02,
          unit: 'kg',
          name: 'Coklat Bubuk'),
    ],
    // Iced Coffee
    'prod-6': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica')
    ],
    'prod-7': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    'prod-8': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.15,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
      RecipeIngredient(
          materialId: 'mat-8',
          quantity: 0.02,
          unit: 'kg',
          name: 'Coklat Bubuk'),
    ],
    'prod-9': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.025,
          unit: 'kg',
          name: 'Biji Kopi Arabica')
    ],
    // Non-Coffee
    'prod-10': [
      RecipeIngredient(
          materialId: 'mat-7',
          quantity: 0.005,
          unit: 'kg',
          name: 'Matcha Powder'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.25,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    'prod-11': [
      RecipeIngredient(
          materialId: 'mat-8',
          quantity: 0.03,
          unit: 'kg',
          name: 'Coklat Bubuk'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.25,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    'prod-12': [
      RecipeIngredient(
          materialId: 'mat-8',
          quantity: 0.02,
          unit: 'kg',
          name: 'Coklat Bubuk'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
      RecipeIngredient(
          materialId: 'mat-4',
          quantity: 0.05,
          unit: 'liter',
          name: 'Whipping Cream'),
    ],
    // Tea
    'prod-16': [
      RecipeIngredient(
          materialId: 'mat-11',
          quantity: 1,
          unit: 'sachet',
          name: 'Earl Grey Tea')
    ],
    'prod-17': [
      RecipeIngredient(
          materialId: 'mat-7',
          quantity: 0.003,
          unit: 'kg',
          name: 'Matcha Powder'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
    ],
    // Signature Drinks
    'prod-18': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
      RecipeIngredient(
          materialId: 'mat-9',
          quantity: 0.03,
          unit: 'botol',
          name: 'Caramel Sauce'),
    ],
    'prod-19': [
      RecipeIngredient(
          materialId: 'mat-1',
          quantity: 0.018,
          unit: 'kg',
          name: 'Biji Kopi Arabica'),
      RecipeIngredient(
          materialId: 'mat-3',
          quantity: 0.2,
          unit: 'liter',
          name: 'Susu Fresh Milk'),
      RecipeIngredient(
          materialId: 'mat-10',
          quantity: 0.02,
          unit: 'botol',
          name: 'Hazelnut Syrup'),
    ],
  };

  /// Get recipe for a product (multi-tenant)
  Future<List<RecipeIngredient>?> getRecipe(
      String tenantId, String productId) async {
    try {
      if (kIsWeb) {
        final tenantRecipes = _webRecipes[tenantId];
        if (tenantRecipes == null) return null;
        return tenantRecipes[productId];
      }

      final db = await _db.database;
      final results = await db.query(
        'recipes',
        where: 'tenant_id = ? AND product_id = ?',
        whereArgs: [tenantId, productId],
      );

      if (results.isEmpty) return null;

      final ingredientsJson = results.first['ingredients'] as String;
      final List<dynamic> ingredientsList = jsonDecode(ingredientsJson);
      return ingredientsList
          .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting recipe: $e');
      return null;
    }
  }

  /// Check if product has a recipe (multi-tenant)
  Future<bool> hasRecipe(String tenantId, String productId) async {
    final recipe = await getRecipe(tenantId, productId);
    return recipe != null && recipe.isNotEmpty;
  }

  /// Get all recipes for a tenant
  Future<Map<String, List<RecipeIngredient>>> getAllRecipes(
      String tenantId) async {
    try {
      if (kIsWeb) {
        return Map.from(_webRecipes[tenantId] ?? {});
      }

      final db = await _db.database;
      final results = await db.query(
        'recipes',
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
      );

      final recipes = <String, List<RecipeIngredient>>{};
      for (var row in results) {
        final productId = row['product_id'] as String;
        final ingredientsJson = row['ingredients'] as String;
        final List<dynamic> ingredientsList = jsonDecode(ingredientsJson);
        recipes[productId] = ingredientsList
            .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
            .toList();
      }
      return recipes;
    } catch (e) {
      debugPrint('Error getting all recipes: $e');
      return {};
    }
  }

  /// Save recipe for a product (multi-tenant)
  Future<RepositoryResult<bool>> saveRecipe(
    String tenantId,
    String productId,
    List<RecipeIngredient> ingredients,
  ) async {
    try {
      // Validate
      if (tenantId.isEmpty) {
        return RepositoryResult.failure('Tenant ID tidak valid');
      }
      if (productId.isEmpty) {
        return RepositoryResult.failure('Product ID tidak valid');
      }

      // Validate ingredients
      for (var ingredient in ingredients) {
        if (ingredient.materialId.isEmpty) {
          return RepositoryResult.failure(
              'Material ID tidak valid untuk bahan "${ingredient.name}"');
        }
        if (ingredient.quantity <= 0) {
          return RepositoryResult.failure(
              'Jumlah bahan "${ingredient.name}" harus lebih dari 0');
        }
        if (ingredient.unit.isEmpty) {
          return RepositoryResult.failure(
              'Satuan tidak valid untuk bahan "${ingredient.name}"');
        }
      }

      // Check for duplicate materials in recipe
      final materialIds = ingredients.map((i) => i.materialId).toList();
      final uniqueMaterialIds = materialIds.toSet();
      if (materialIds.length != uniqueMaterialIds.length) {
        return RepositoryResult.failure(
            'Tidak boleh ada bahan yang duplikat dalam resep');
      }

      if (kIsWeb) {
        if (!_webRecipes.containsKey(tenantId)) {
          _webRecipes[tenantId] = {};
        }
        if (ingredients.isEmpty) {
          _webRecipes[tenantId]!.remove(productId);
        } else {
          _webRecipes[tenantId]![productId] = List.from(ingredients);
        }
        return RepositoryResult.success(true);
      }

      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      if (ingredients.isEmpty) {
        // Delete recipe
        await db.delete(
          'recipes',
          where: 'tenant_id = ? AND product_id = ?',
          whereArgs: [tenantId, productId],
        );
      } else {
        // Check if exists
        final existing = await db.query(
          'recipes',
          where: 'tenant_id = ? AND product_id = ?',
          whereArgs: [tenantId, productId],
        );

        final ingredientsJson =
            jsonEncode(ingredients.map((i) => i.toJson()).toList());

        if (existing.isEmpty) {
          // Insert
          await db.insert('recipes', {
            'id': 'recipe-${DateTime.now().millisecondsSinceEpoch}',
            'tenant_id': tenantId,
            'product_id': productId,
            'ingredients': ingredientsJson,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          // Update
          await db.update(
            'recipes',
            {
              'ingredients': ingredientsJson,
              'updated_at': now,
            },
            where: 'tenant_id = ? AND product_id = ?',
            whereArgs: [tenantId, productId],
          );
        }
      }

      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      return RepositoryResult.failure('Gagal menyimpan resep: $e');
    }
  }

  /// Delete recipe for a product (multi-tenant)
  Future<RepositoryResult<bool>> deleteRecipe(
      String tenantId, String productId) async {
    return saveRecipe(tenantId, productId, []);
  }

  /// Calculate max servings from materials (multi-tenant)
  /// Returns -1 if no recipe exists, 0 if materials are insufficient
  int calculateMaxServings(
    String tenantId,
    String productId,
    List<mat.Material> materials,
    Map<String, List<RecipeIngredient>> recipes,
  ) {
    final recipe = recipes[productId];
    if (recipe == null || recipe.isEmpty) return -1;

    int maxServings = 999999;
    for (var ingredient in recipe) {
      final material = materials.firstWhere(
        (m) => m.id == ingredient.materialId,
        orElse: () => mat.Material(
            id: '',
            tenantId: '',
            name: '',
            stock: 0,
            unit: '',
            createdAt: DateTime.now()),
      );

      // Material not found or no stock
      if (material.id.isEmpty || material.stock <= 0) return 0;

      // Check unit compatibility
      if (!_areUnitsCompatible(material.unit, ingredient.unit)) {
        // Units are incompatible, use direct comparison as fallback
        debugPrint('Warning: Incompatible units for ${ingredient.name}: '
            'material=${material.unit}, recipe=${ingredient.unit}');
        if (ingredient.quantity > 0) {
          final possibleServings =
              (material.stock / ingredient.quantity).floor();
          if (possibleServings < maxServings) maxServings = possibleServings;
        }
        continue;
      }

      final availableStock = _convertToBaseUnit(material.stock, material.unit);
      final neededPerServing =
          _convertToBaseUnit(ingredient.quantity, ingredient.unit);

      if (neededPerServing > 0) {
        final possibleServings = (availableStock / neededPerServing).floor();
        if (possibleServings < maxServings) maxServings = possibleServings;
      }
    }
    return maxServings == 999999 ? 0 : maxServings;
  }

  /// Get all products capacity (multi-tenant)
  Map<String, int> calculateAllProductCapacity(
    String tenantId,
    List<mat.Material> materials,
    Map<String, List<RecipeIngredient>> recipes,
  ) {
    final capacity = <String, int>{};
    for (var productId in recipes.keys) {
      capacity[productId] =
          calculateMaxServings(tenantId, productId, materials, recipes);
    }
    return capacity;
  }

  /// Get material status for recipe (multi-tenant)
  List<MaterialStatus> getMaterialStatus(
    List<RecipeIngredient> recipe,
    List<mat.Material> materials,
  ) {
    return recipe.map((ingredient) {
      final material = materials.firstWhere(
        (m) => m.id == ingredient.materialId,
        orElse: () => mat.Material(
            id: ingredient.materialId,
            tenantId: '',
            name: ingredient.name,
            stock: 0,
            unit: ingredient.unit,
            createdAt: DateTime.now()),
      );

      return MaterialStatus(
        materialId: ingredient.materialId,
        materialName:
            material.name.isNotEmpty ? material.name : ingredient.name,
        neededPerServing: ingredient.quantity,
        unit: ingredient.unit,
        currentStock: material.stock,
        isAvailable: material.stock >= ingredient.quantity,
      );
    }).toList();
  }

  /// Convert value to base unit for consistent calculation
  /// Weight: converts to grams
  /// Volume: converts to milliliters
  /// Other units: returns as-is
  double _convertToBaseUnit(double value, String unit) {
    if (value <= 0) return 0;

    final normalizedUnit = unit.toLowerCase().trim();
    switch (normalizedUnit) {
      // Weight units - convert to grams
      case 'kg':
      case 'kilogram':
        return value * 1000;
      case 'gram':
      case 'g':
      case 'gr':
        return value;
      case 'mg':
      case 'miligram':
        return value / 1000;
      // Volume units - convert to milliliters
      case 'liter':
      case 'l':
      case 'lt':
        return value * 1000;
      case 'ml':
      case 'mililiter':
        return value;
      // Count units - return as-is
      case 'pcs':
      case 'buah':
      case 'biji':
      case 'lembar':
      case 'sachet':
      case 'botol':
      case 'pack':
      case 'dus':
      case 'karton':
        return value;
      default:
        return value;
    }
  }

  /// Check if two units are compatible for comparison
  bool _areUnitsCompatible(String unit1, String unit2) {
    final weightUnits = {'kg', 'kilogram', 'gram', 'g', 'gr', 'mg', 'miligram'};
    final volumeUnits = {'liter', 'l', 'lt', 'ml', 'mililiter'};
    final countUnits = {
      'pcs',
      'buah',
      'biji',
      'lembar',
      'sachet',
      'botol',
      'pack',
      'dus',
      'karton'
    };

    final u1 = unit1.toLowerCase().trim();
    final u2 = unit2.toLowerCase().trim();

    if (weightUnits.contains(u1) && weightUnits.contains(u2)) return true;
    if (volumeUnits.contains(u1) && volumeUnits.contains(u2)) return true;
    if (countUnits.contains(u1) && countUnits.contains(u2)) return true;

    // Same unit
    return u1 == u2;
  }
}
