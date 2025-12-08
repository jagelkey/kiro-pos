/// Recipe model for product ingredients
class Recipe {
  final String productId;
  final String productName;
  final List<RecipeIngredient> ingredients;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Recipe({
    required this.productId,
    required this.productName,
    required this.ingredients,
    this.createdAt,
    this.updatedAt,
  });

  Recipe copyWith({
    String? productId,
    String? productName,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        productId: json['product_id'],
        productName: json['product_name'] ?? '',
        ingredients: (json['ingredients'] as List?)
                ?.map((i) => RecipeIngredient.fromJson(i))
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );
}

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

  RecipeIngredient copyWith({
    String? materialId,
    double? quantity,
    String? unit,
    String? name,
  }) {
    return RecipeIngredient(
      materialId: materialId ?? this.materialId,
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

/// Ingredient availability status
class IngredientAvailability {
  final String materialId;
  final String materialName;
  final double neededPerServing;
  final String unit;
  final double currentStock;
  final bool isAvailable;
  final int maxServings;

  IngredientAvailability({
    required this.materialId,
    required this.materialName,
    required this.neededPerServing,
    required this.unit,
    required this.currentStock,
    required this.isAvailable,
    required this.maxServings,
  });
}
