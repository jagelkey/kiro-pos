enum UserRole { superAdmin, owner, manager, cashier }

class User {
  final String id;
  final String tenantId;
  final String?
      branchId; // Multi-tenant: User dapat di-assign ke branch tertentu
  final String email;
  final String name;
  final String? passwordHash; // Untuk autentikasi
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.email,
    required this.name,
    this.passwordHash,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  /// Check if user is a super admin (full access to all features)
  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Check if user is an owner
  bool get isOwner => role == UserRole.owner || role == UserRole.superAdmin;

  /// Check if user is a manager
  bool get isManager => role == UserRole.manager;

  /// Check if user is a cashier
  bool get isCashier => role == UserRole.cashier;

  /// Check if user has super admin access (superAdmin only)
  bool get hasSuperAdminAccess => role == UserRole.superAdmin;

  /// Check if user has owner-level access (superAdmin or owner)
  bool get hasOwnerAccess =>
      role == UserRole.superAdmin || role == UserRole.owner;

  /// Check if user has manager-level access (superAdmin, owner, or manager)
  bool get hasManagerAccess =>
      role == UserRole.superAdmin ||
      role == UserRole.owner ||
      role == UserRole.manager;

  /// Check if user can access a specific feature based on role
  bool canAccess(UserRole minimumRole) {
    // Super admin can access everything
    if (role == UserRole.superAdmin) return true;

    switch (minimumRole) {
      case UserRole.superAdmin:
        return role == UserRole.superAdmin;
      case UserRole.owner:
        return role == UserRole.owner;
      case UserRole.manager:
        return role == UserRole.owner || role == UserRole.manager;
      case UserRole.cashier:
        return true; // All roles can access cashier-level features
    }
  }

  /// Copy with method untuk update user
  User copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? email,
    String? name,
    String? passwordHash,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      email: email ?? this.email,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      tenantId: json['tenant_id'],
      branchId: json['branch_id'],
      email: json['email'],
      name: json['name'],
      passwordHash: json['password_hash'],
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'email': email,
      'name': name,
      'password_hash': passwordHash,
      'role': role.name,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'email': email,
      'name': name,
      'password_hash': passwordHash,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      email: map['email'] as String,
      name: map['name'] as String,
      passwordHash: map['password_hash'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
