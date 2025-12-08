class Material {
  final String id;
  final String tenantId;
  final String name;
  final double stock;
  final String unit; // kg, g, l, ml, pcs
  final double? minStock;
  final String? category;
  final DateTime createdAt;

  Material({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.stock,
    required this.unit,
    this.minStock,
    this.category,
    required this.createdAt,
  });

  Material copyWith({
    String? id,
    String? tenantId,
    String? name,
    double? stock,
    String? unit,
    double? minStock,
    String? category,
    DateTime? createdAt,
  }) {
    return Material(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if material is low on stock (stock <= minStock)
  /// Requirements 3.4: Display warning when stock falls below minimum threshold
  bool get isLowStock => minStock != null && stock > 0 && stock <= minStock!;

  /// Check if material is out of stock
  bool get isOutOfStock => stock <= 0;

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'],
      tenantId: json['tenant_id'],
      name: json['name'],
      stock: (json['stock'] ?? 0.0).toDouble(),
      unit: json['unit'],
      minStock: json['min_stock'] != null
          ? (json['min_stock'] as num).toDouble()
          : null,
      category: json['category'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    return Material(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      stock: (map['stock'] as num).toDouble(),
      unit: map['unit'] as String,
      minStock: map['min_stock'] != null
          ? (map['min_stock'] as num).toDouble()
          : null,
      category: map['category'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'stock': stock,
      'unit': unit,
      'min_stock': minStock,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'stock': stock,
      'unit': unit,
      'min_stock': minStock,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
