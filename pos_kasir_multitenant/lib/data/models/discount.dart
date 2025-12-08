/// Discount type enum
enum DiscountType { percentage, fixed }

/// Maximum allowed fixed discount amount
const double maxFixedDiscountAmount = 999999999;

/// Discount model for promotions and discounts
/// Requirements 14.1: Save discount details (name, type, value, validity period)
class Discount {
  final String id;
  final String tenantId;
  final String? branchId; // Multi-branch support - null means all branches
  final String name;
  final DiscountType type;
  final double value;
  final double? minPurchase;
  final String? promoCode;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool isActive;
  final String? createdBy; // User ID who created this discount
  final DateTime createdAt;
  final DateTime? updatedAt;

  Discount({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    required this.type,
    required this.value,
    this.minPurchase,
    this.promoCode,
    required this.validFrom,
    required this.validUntil,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Validate discount data
  /// Returns null if valid, error message if invalid
  String? validate() {
    if (tenantId.isEmpty) return 'Tenant ID tidak valid';
    if (name.trim().isEmpty) return 'Nama diskon wajib diisi';
    if (value <= 0) return 'Nilai diskon harus lebih dari 0';
    if (type == DiscountType.percentage && value > 100) {
      return 'Diskon persentase tidak boleh lebih dari 100%';
    }
    if (type == DiscountType.fixed && value > maxFixedDiscountAmount) {
      return 'Nilai diskon terlalu besar';
    }
    if (validUntil.isBefore(validFrom)) {
      return 'Tanggal berakhir harus setelah tanggal mulai';
    }
    if (minPurchase != null && minPurchase! < 0) {
      return 'Minimal pembelian tidak boleh negatif';
    }
    return null;
  }

  /// Check if discount is percentage-based
  bool get isPercentage => type == DiscountType.percentage;

  /// Check if discount is fixed amount
  bool get isFixed => type == DiscountType.fixed;

  /// Check if discount is currently valid based on date
  /// Requirements 14.4: Only allow application within valid dates
  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && !now.isBefore(validFrom) && !now.isAfter(validUntil);
  }

  /// Check if discount has a promo code
  bool get hasPromoCode => promoCode != null && promoCode!.isNotEmpty;

  /// Calculate discount amount for a given subtotal
  /// Requirements 14.2, 14.3: Calculate percentage or fixed discount
  double calculateDiscount(double subtotal) {
    if (!isCurrentlyValid) return 0;
    if (minPurchase != null && subtotal < minPurchase!) return 0;

    if (type == DiscountType.percentage) {
      // Requirements 14.2: Percentage discount
      return subtotal * (value / 100);
    } else {
      // Requirements 14.3: Fixed discount (capped at subtotal)
      return value > subtotal ? subtotal : value;
    }
  }

  /// Check if subtotal meets minimum purchase requirement
  /// Requirements 14.5: Validate cart total before applying discount
  bool meetsMinPurchase(double subtotal) {
    if (minPurchase == null) return true;
    return subtotal >= minPurchase!;
  }

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      name: json['name'] as String,
      type: DiscountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      minPurchase: json['min_purchase'] != null
          ? (json['min_purchase'] as num).toDouble()
          : null,
      promoCode: json['promo_code'] as String?,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'name': name,
      'type': type.name,
      'value': value,
      'min_purchase': minPurchase,
      'promo_code': promoCode,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Discount.fromMap(Map<String, dynamic> map) {
    return Discount(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      name: map['name'] as String,
      type: DiscountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (map['value'] as num).toDouble(),
      minPurchase: map['min_purchase'] != null
          ? (map['min_purchase'] as num).toDouble()
          : null,
      promoCode: map['promo_code'] as String?,
      validFrom: DateTime.parse(map['valid_from'] as String),
      validUntil: DateTime.parse(map['valid_until'] as String),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'name': name,
      'type': type.name,
      'value': value,
      'min_purchase': minPurchase,
      'promo_code': promoCode,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Discount copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    bool clearBranchId = false,
    String? name,
    DiscountType? type,
    double? value,
    double? minPurchase,
    bool clearMinPurchase = false,
    String? promoCode,
    bool clearPromoCode = false,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      minPurchase: clearMinPurchase ? null : (minPurchase ?? this.minPurchase),
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Discount(id: $id, name: $name, type: $type, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Discount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
