class Transaction {
  final String id;
  final String tenantId;
  final String userId;
  final String? shiftId; // Requirements 13.5: Associate with shift
  final String? discountId; // Requirements 14.6: Associate with discount
  final List<TransactionItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod; // cash, transfer, e-wallet
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.tenantId,
    required this.userId,
    this.shiftId,
    this.discountId,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
  });

  /// Total harga pokok penjualan untuk transaksi ini
  double get totalCostPrice =>
      items.fold<double>(0, (sum, item) => sum + item.totalCostPrice);

  /// Laba kotor transaksi ini
  double get grossProfit => subtotal - totalCostPrice;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      tenantId: json['tenant_id'],
      userId: json['user_id'],
      shiftId: json['shift_id'],
      discountId: json['discount_id'],
      items: (json['items'] as List)
          .map((e) => TransactionItem.fromJson(e))
          .toList(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      discount: (json['discount'] ?? 0.0).toDouble(),
      tax: (json['tax'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
      paymentMethod: json['payment_method'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'shift_id': shiftId,
      'discount_id': discountId,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Transaction copyWith({
    String? id,
    String? tenantId,
    String? userId,
    String? shiftId,
    String? discountId,
    List<TransactionItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? paymentMethod,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      shiftId: shiftId ?? this.shiftId,
      discountId: discountId ?? this.discountId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TransactionItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double costPrice; // Harga pokok per unit
  final double total;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.costPrice = 0,
    required this.total,
  });

  /// Total harga pokok untuk item ini
  double get totalCostPrice => costPrice * quantity;

  /// Profit margin untuk item ini
  double get profitMargin => total - totalCostPrice;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id'],
      productName: json['product_name'],
      quantity: json['quantity'],
      price: (json['price'] ?? 0.0).toDouble(),
      costPrice: (json['cost_price'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'cost_price': costPrice,
      'total': total,
    };
  }
}
