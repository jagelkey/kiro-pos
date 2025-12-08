class Expense {
  final String id;
  final String tenantId;
  final String? branchId; // Multi-branch support
  final String category;
  final double amount;
  final String? description;
  final DateTime date;
  final String? createdBy; // User ID who created this expense
  final DateTime createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.category,
    required this.amount,
    this.description,
    required this.date,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Validate expense data
  /// Returns null if valid, error message if invalid
  String? validate() {
    if (tenantId.isEmpty) return 'Tenant ID tidak valid';
    if (category.trim().isEmpty) return 'Kategori wajib diisi';
    if (amount <= 0) return 'Jumlah harus lebih dari 0';
    if (amount > 999999999999) return 'Jumlah terlalu besar';
    return null;
  }

  /// Create a copy with updated fields
  Expense copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    bool clearBranchId = false,
    String? category,
    double? amount,
    String? description,
    bool clearDescription = false,
    DateTime? date,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: clearDescription ? null : (description ?? this.description),
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      tenantId: json['tenant_id'],
      branchId: json['branch_id'],
      category: json['category'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'],
      date: DateTime.parse(json['date']),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Expense(id: $id, category: $category, amount: $amount, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
