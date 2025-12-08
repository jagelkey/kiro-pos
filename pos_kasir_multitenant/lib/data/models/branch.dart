/// Branch model for multi-branch support
/// Requirements 11.1, 11.3: Branch management with unique code and settings
class Branch {
  final String id;
  final String ownerId; // Owner user ID who manages this branch
  final String name;
  final String code; // Unique branch code (e.g., "JKT-001")
  final String? address;
  final String? phone;
  final double taxRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Branch({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.code,
    this.address,
    this.phone,
    this.taxRate = 0.11,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if branch is currently active
  bool get isOperational => isActive;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.11,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'tax_rate': taxRate,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.11,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'tax_rate': taxRate,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Branch copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? code,
    String? address,
    String? phone,
    double? taxRate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Branch(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxRate: taxRate ?? this.taxRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Branch($code: $name)';
}
