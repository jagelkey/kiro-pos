import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/shift.dart';
import 'product_repository.dart'; // For RepositoryResult

/// Repository for managing shift data
/// Requirements 13.1, 13.2, 13.3: Shift management operations
class ShiftRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web
  static final List<Shift> _webShifts = [];

  /// Get active shift for a user
  /// Requirements 13.1: Record shift start time
  Future<Shift?> getActiveShift(String tenantId, String userId) async {
    try {
      if (kIsWeb) {
        final index = _webShifts.indexWhere(
          (s) =>
              s.tenantId == tenantId &&
              s.userId == userId &&
              s.status == ShiftStatus.active,
        );
        return index != -1 ? _webShifts[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'shifts',
        where: 'tenant_id = ? AND user_id = ? AND status = ?',
        whereArgs: [tenantId, userId, ShiftStatus.active.name],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return Shift.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting active shift: $e');
      return null;
    }
  }

  /// Get shift history for a tenant
  /// Requirements 13.3: View shift history
  Future<List<Shift>> getShiftHistory(
    String tenantId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      if (kIsWeb) {
        var shifts = _webShifts.where((s) => s.tenantId == tenantId).toList();

        if (from != null) {
          shifts = shifts.where((s) => s.startTime.isAfter(from)).toList();
        }
        if (to != null) {
          shifts = shifts.where((s) => s.startTime.isBefore(to)).toList();
        }

        shifts.sort((a, b) => b.startTime.compareTo(a.startTime));

        if (limit != null && shifts.length > limit) {
          shifts = shifts.take(limit).toList();
        }

        return shifts;
      }

      final db = await _db.database;
      String whereClause = 'tenant_id = ?';
      List<dynamic> whereArgs = [tenantId];

      if (from != null) {
        whereClause += ' AND start_time >= ?';
        whereArgs.add(from.toIso8601String());
      }
      if (to != null) {
        whereClause += ' AND start_time <= ?';
        whereArgs.add(to.toIso8601String());
      }

      final results = await db.query(
        'shifts',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_time DESC',
        limit: limit,
      );

      return results.map((map) => Shift.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting shift history: $e');
      return [];
    }
  }

  /// Start a new shift
  /// Requirements 13.1: Record shift start time and opening cash
  Future<RepositoryResult<Shift>> startShift(Shift shift) async {
    try {
      // Validate opening cash
      if (shift.openingCash < 0) {
        return RepositoryResult.failure('Kas awal tidak boleh negatif');
      }

      // Check if user already has an active shift
      final existingShift = await getActiveShift(shift.tenantId, shift.userId);
      if (existingShift != null) {
        return RepositoryResult.failure(
            'Anda sudah memiliki shift aktif. Silakan akhiri shift terlebih dahulu.');
      }

      if (kIsWeb) {
        _webShifts.add(shift);
        return RepositoryResult.success(shift);
      }

      final db = await _db.database;
      await db.insert('shifts', shift.toMap());
      return RepositoryResult.success(shift);
    } catch (e) {
      debugPrint('Error starting shift: $e');
      return RepositoryResult.failure('Gagal memulai shift: $e');
    }
  }

  /// End a shift
  /// Requirements 13.2: Calculate expected cash and compare with actual
  /// Validates tenant ownership before ending shift
  Future<RepositoryResult<Shift>> endShift(
    String shiftId,
    double closingCash,
    double expectedCash, {
    String? varianceNote,
    String? tenantId,
  }) async {
    try {
      if (closingCash < 0) {
        return RepositoryResult.failure('Kas akhir tidak boleh negatif');
      }

      final variance = closingCash - expectedCash;
      final status =
          variance.abs() > 0.01 ? ShiftStatus.flagged : ShiftStatus.closed;

      // Requirements 13.4: Require explanation note if variance exists
      if (status == ShiftStatus.flagged &&
          (varianceNote == null || varianceNote.trim().isEmpty)) {
        return RepositoryResult.failure(
            'Catatan wajib diisi jika ada selisih kas');
      }

      if (kIsWeb) {
        final index = _webShifts.indexWhere((s) => s.id == shiftId);
        if (index == -1) {
          return RepositoryResult.failure('Shift tidak ditemukan');
        }

        // Validate tenant ownership if tenantId provided
        if (tenantId != null && _webShifts[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak memiliki akses untuk mengakhiri shift ini');
        }

        // Validate shift is still active
        if (_webShifts[index].status != ShiftStatus.active) {
          return RepositoryResult.failure('Shift sudah diakhiri sebelumnya');
        }

        final updatedShift = _webShifts[index].copyWith(
          endTime: DateTime.now(),
          closingCash: closingCash,
          expectedCash: expectedCash,
          variance: variance,
          varianceNote: varianceNote,
          status: status,
        );
        _webShifts[index] = updatedShift;
        return RepositoryResult.success(updatedShift);
      }

      final db = await _db.database;

      // Validate shift exists and is active
      final existing = await db.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
      );
      if (existing.isEmpty) {
        return RepositoryResult.failure('Shift tidak ditemukan');
      }

      final currentShift = Shift.fromMap(existing.first);

      // Validate tenant ownership if tenantId provided
      if (tenantId != null && currentShift.tenantId != tenantId) {
        return RepositoryResult.failure(
            'Tidak memiliki akses untuk mengakhiri shift ini');
      }

      // Validate shift is still active
      if (currentShift.status != ShiftStatus.active) {
        return RepositoryResult.failure('Shift sudah diakhiri sebelumnya');
      }

      final rowsAffected = await db.update(
        'shifts',
        {
          'end_time': DateTime.now().toIso8601String(),
          'closing_cash': closingCash,
          'expected_cash': expectedCash,
          'variance': variance,
          'variance_note': varianceNote,
          'status': status.name,
        },
        where: 'id = ?',
        whereArgs: [shiftId],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Shift tidak ditemukan');
      }

      final updatedShift = await getShift(shiftId);
      return RepositoryResult.success(updatedShift);
    } catch (e) {
      debugPrint('Error ending shift: $e');
      return RepositoryResult.failure('Gagal mengakhiri shift: $e');
    }
  }

  /// Get a single shift by ID
  Future<Shift?> getShift(String id) async {
    try {
      if (kIsWeb) {
        final index = _webShifts.indexWhere((s) => s.id == id);
        return index != -1 ? _webShifts[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return Shift.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting shift: $e');
      return null;
    }
  }

  /// Get shifts by user
  Future<List<Shift>> getShiftsByUser(String tenantId, String userId) async {
    try {
      if (kIsWeb) {
        return _webShifts
            .where((s) => s.tenantId == tenantId && s.userId == userId)
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
      }

      final db = await _db.database;
      final results = await db.query(
        'shifts',
        where: 'tenant_id = ? AND user_id = ?',
        whereArgs: [tenantId, userId],
        orderBy: 'start_time DESC',
      );

      return results.map((map) => Shift.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting shifts by user: $e');
      return [];
    }
  }

  /// Get flagged shifts (with variance)
  Future<List<Shift>> getFlaggedShifts(String tenantId) async {
    try {
      if (kIsWeb) {
        return _webShifts
            .where((s) =>
                s.tenantId == tenantId && s.status == ShiftStatus.flagged)
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
      }

      final db = await _db.database;
      final results = await db.query(
        'shifts',
        where: 'tenant_id = ? AND status = ?',
        whereArgs: [tenantId, ShiftStatus.flagged.name],
        orderBy: 'start_time DESC',
      );

      return results.map((map) => Shift.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting flagged shifts: $e');
      return [];
    }
  }
}
