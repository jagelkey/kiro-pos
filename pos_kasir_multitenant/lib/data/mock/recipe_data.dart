import '../models/material.dart' as mat;

/// Recipe ingredient model
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

/// Recipe Manager - Handles all recipe operations
class RecipeData {
  // Mutable recipe storage
  static final Map<String, List<RecipeIngredient>> _recipes = {
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

  /// Get all recipes (read-only view)
  static Map<String, List<RecipeIngredient>> get recipes =>
      Map.unmodifiable(_recipes);

  /// Get recipe for a product
  static List<RecipeIngredient>? getRecipe(String productId) =>
      _recipes[productId];

  /// Check if product has a recipe
  static bool hasRecipe(String productId) => _recipes.containsKey(productId);

  /// Add or update recipe for a product
  static void setRecipe(String productId, List<RecipeIngredient> ingredients) {
    _recipes[productId] = List.from(ingredients);
  }

  /// Add ingredient to recipe
  static void addIngredient(String productId, RecipeIngredient ingredient) {
    if (!_recipes.containsKey(productId)) {
      _recipes[productId] = [];
    }
    // Check if ingredient already exists
    final existingIdx = _recipes[productId]!
        .indexWhere((i) => i.materialId == ingredient.materialId);
    if (existingIdx >= 0) {
      _recipes[productId]![existingIdx] = ingredient;
    } else {
      _recipes[productId]!.add(ingredient);
    }
  }

  /// Update ingredient quantity
  static void updateIngredient(
      String productId, String materialId, double quantity) {
    final recipe = _recipes[productId];
    if (recipe == null) return;
    final idx = recipe.indexWhere((i) => i.materialId == materialId);
    if (idx >= 0) {
      recipe[idx].quantity = quantity;
    }
  }

  /// Remove ingredient from recipe
  static void removeIngredient(String productId, String materialId) {
    final recipe = _recipes[productId];
    if (recipe == null) return;
    recipe.removeWhere((i) => i.materialId == materialId);
    if (recipe.isEmpty) {
      _recipes.remove(productId);
    }
  }

  /// Delete entire recipe
  static void deleteRecipe(String productId) {
    _recipes.remove(productId);
  }

  /// Calculate max servings from materials
  static int calculateMaxServings(
      String productId, List<mat.Material> materials) {
    final recipe = _recipes[productId];
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

      if (material.id.isEmpty || material.stock <= 0) return 0;

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

  /// Get all products capacity
  static Map<String, int> calculateAllProductCapacity(
      List<mat.Material> materials) {
    final capacity = <String, int>{};
    for (var productId in _recipes.keys) {
      capacity[productId] = calculateMaxServings(productId, materials);
    }
    return capacity;
  }

  /// Get material status for recipe
  static List<MaterialStatus> getMaterialStatus(
      String productId, List<mat.Material> materials) {
    final recipe = _recipes[productId];
    if (recipe == null) return [];

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

  static double _convertToBaseUnit(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return value * 1000;
      case 'gram':
      case 'g':
        return value;
      case 'liter':
      case 'l':
        return value * 1000;
      case 'ml':
        return value;
      default:
        return value;
    }
  }
}
