/// Shift status enum
enum ShiftStatus { active, closed, flagged }

/// Shift model for cashier shift management
/// Requirements 13.1: Record shift start time and opening cash amount
class Shift {
  final String id;
  final String tenantId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? variance;
  final String? varianceNote;
  final ShiftStatus status;
  final DateTime createdAt;

  Shift({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.variance,
    this.varianceNote,
    this.status = ShiftStatus.active,
    required this.createdAt,
  });

  /// Check if shift is currently active
  bool get isActive => status == ShiftStatus.active;

  /// Check if shift is closed
  bool get isClosed => status == ShiftStatus.closed;

  /// Check if shift has variance (flagged)
  bool get isFlagged => status == ShiftStatus.flagged;

  /// Calculate shift duration
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      openingCash: (json['opening_cash'] as num).toDouble(),
      closingCash: json['closing_cash'] != null
          ? (json['closing_cash'] as num).toDouble()
          : null,
      expectedCash: json['expected_cash'] != null
          ? (json['expected_cash'] as num).toDouble()
          : null,
      variance: json['variance'] != null
          ? (json['variance'] as num).toDouble()
          : null,
      varianceNote: json['variance_note'] as String?,
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ShiftStatus.active,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'opening_cash': openingCash,
      'closing_cash': closingCash,
      'expected_cash': expectedCash,
      'variance': variance,
      'variance_note': varianceNote,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      openingCash: (map['opening_cash'] as num).toDouble(),
      closingCash: map['closing_cash'] != null
          ? (map['closing_cash'] as num).toDouble()
          : null,
      expectedCash: map['expected_cash'] != null
          ? (map['expected_cash'] as num).toDouble()
          : null,
      variance:
          map['variance'] != null ? (map['variance'] as num).toDouble() : null,
      varianceNote: map['variance_note'] as String?,
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ShiftStatus.active,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'opening_cash': openingCash,
      'closing_cash': closingCash,
      'expected_cash': expectedCash,
      'variance': variance,
      'variance_note': varianceNote,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Shift copyWith({
    String? id,
    String? tenantId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? openingCash,
    double? closingCash,
    double? expectedCash,
    double? variance,
    String? varianceNote,
    ShiftStatus? status,
    DateTime? createdAt,
  }) {
    return Shift(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
      expectedCash: expectedCash ?? this.expectedCash,
      variance: variance ?? this.variance,
      varianceNote: varianceNote ?? this.varianceNote,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
