class Tenant {
  final String id;
  final String name;
  final String identifier; // subdomain or unique identifier
  final String? logoUrl;
  final String timezone;
  final String currency;
  final double taxRate;
  final String? address;
  final String? phone;
  final String? email;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tenant({
    required this.id,
    required this.name,
    required this.identifier,
    this.logoUrl,
    required this.timezone,
    required this.currency,
    this.taxRate = 0.0,
    this.address,
    this.phone,
    this.email,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Copy with method untuk update tenant
  Tenant copyWith({
    String? id,
    String? name,
    String? identifier,
    String? logoUrl,
    String? timezone,
    String? currency,
    double? taxRate,
    String? address,
    String? phone,
    String? email,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      identifier: identifier ?? this.identifier,
      logoUrl: logoUrl ?? this.logoUrl,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      taxRate: taxRate ?? this.taxRate,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'identifier': identifier,
      'logo_url': logoUrl,
      'timezone': timezone,
      'currency': currency,
      'tax_rate': taxRate,
      'address': address,
      'phone': phone,
      'email': email,
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String,
      name: map['name'] as String,
      identifier: map['identifier'] as String,
      logoUrl: map['logo_url'] as String?,
      timezone: (map['timezone'] as String?) ?? 'Asia/Jakarta',
      currency: (map['currency'] as String?) ?? 'IDR',
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      settings: map['settings'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'],
      name: json['name'],
      identifier: json['identifier'],
      logoUrl: json['logo_url'],
      timezone: json['timezone'] ?? 'Asia/Jakarta',
      currency: json['currency'] ?? 'IDR',
      taxRate: (json['tax_rate'] ?? 0.0).toDouble(),
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      settings: json['settings'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'identifier': identifier,
      'logo_url': logoUrl,
      'timezone': timezone,
      'currency': currency,
      'tax_rate': taxRate,
      'address': address,
      'phone': phone,
      'email': email,
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
