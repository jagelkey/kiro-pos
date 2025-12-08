class Product {
  final String id;
  final String tenantId;
  final String name;
  final String? barcode;
  final double price; // Harga jual
  final double costPrice; // Harga pokok/modal
  final int stock;
  final String? category;
  final String? imageUrl;
  final List<MaterialComposition>? composition;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.tenantId,
    required this.name,
    this.barcode,
    required this.price,
    this.costPrice = 0,
    required this.stock,
    this.category,
    this.imageUrl,
    this.composition,
    required this.createdAt,
  });

  /// Menghitung margin keuntungan dalam rupiah
  double get profitMargin => price - costPrice;

  /// Menghitung persentase margin keuntungan
  double get profitMarginPercent =>
      costPrice > 0 ? ((price - costPrice) / costPrice) * 100 : 0;

  /// Creates a copy of this Product with the given fields replaced
  Product copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    int? stock,
    String? category,
    String? imageUrl,
    List<MaterialComposition>? composition,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      composition: composition ?? this.composition,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      tenantId: json['tenant_id'],
      name: json['name'],
      barcode: json['barcode'],
      price: (json['price'] ?? 0.0).toDouble(),
      costPrice: (json['cost_price'] ?? 0.0).toDouble(),
      stock: json['stock'] ?? 0,
      category: json['category'],
      imageUrl: json['image_url'],
      composition: json['composition'] != null
          ? (json['composition'] as List)
              .map((e) => MaterialComposition.fromJson(e))
              .toList()
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      stock: map['stock'] as int,
      category: map['category'] as String?,
      imageUrl: map['image_url'] as String?,
      composition: map['composition'] != null
          ? (map['composition'] as List)
              .map((e) => MaterialComposition.fromJson(e))
              .toList()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'composition': composition?.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'composition': composition?.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MaterialComposition {
  final String materialId;
  final double quantity;
  final String unit;

  MaterialComposition({
    required this.materialId,
    required this.quantity,
    required this.unit,
  });

  factory MaterialComposition.fromJson(Map<String, dynamic> json) {
    return MaterialComposition(
      materialId: json['material_id'],
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unit: json['unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'material_id': materialId, 'quantity': quantity, 'unit': unit};
  }
}
