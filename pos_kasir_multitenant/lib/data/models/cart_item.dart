import 'product.dart';

/// Cart Item Model
/// Represents an item in the shopping cart with customization options
class CartItem {
  final Product product;
  final int quantity;
  final String? notes;
  final String size;
  final String temperature;
  final double extraPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
    this.size = 'Regular',
    this.temperature = 'Normal',
    this.extraPrice = 0,
  });

  double get unitPrice => product.price + extraPrice;
  double get total => unitPrice * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? notes,
    String? size,
    String? temperature,
    double? extraPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      size: size ?? this.size,
      temperature: temperature ?? this.temperature,
      extraPrice: extraPrice ?? this.extraPrice,
    );
  }

  /// Convert to map for persistence
  Map<String, dynamic> toMap() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'notes': notes,
      'size': size,
      'temperature': temperature,
      'extra_price': extraPrice,
    };
  }

  /// Create from map with product
  factory CartItem.fromMap(Map<String, dynamic> map, Product product) {
    return CartItem(
      product: product,
      quantity: map['quantity'] as int,
      notes: map['notes'] as String?,
      size: map['size'] as String? ?? 'Regular',
      temperature: map['temperature'] as String? ?? 'Normal',
      extraPrice: (map['extra_price'] as num?)?.toDouble() ?? 0,
    );
  }
}
