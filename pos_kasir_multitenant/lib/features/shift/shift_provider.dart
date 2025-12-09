import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../../data/models/shift.dart';
import '../../data/models/user.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../auth/auth_provider.dart';

final shiftRepositoryProvider = Provider((ref) => ShiftRepository());
final cloudShiftRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider for shift state with additional metadata
class ShiftState {
  final Shift? activeShift;
  final List<Shift> history;
  final bool isLoading;
  final String? error;
  final bool isOffline;
  final int transactionCount;
  final double totalCashSales;

  ShiftState({
    this.activeShift,
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.isOffline = false,
    this.transactionCount = 0,
    this.totalCashSales = 0,
  });

  bool get hasError => error != null && error!.isNotEmpty;
  bool get hasActiveShift => activeShift != null;

  ShiftState copyWith({
    Shift? activeShift,
    bool clearActiveShift = false,
    List<Shift>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isOffline,
    int? transactionCount,
    double? totalCashSales,
  }) {
    return ShiftState(
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isOffline: isOffline ?? this.isOffline,
      transactionCount: transactionCount ?? this.transactionCount,
      totalCashSales: totalCashSales ?? this.totalCashSales,
    );
  }
}

/// Provider for the currently active shift
final activeShiftProvider =
    StateNotifierProvider<ActiveShiftNotifier, AsyncValue<Shift?>>((ref) {
  return ActiveShiftNotifier(ref);
});

/// Provider for shift history
final shiftHistoryProvider =
    StateNotifierProvider<ShiftHistoryNotifier, AsyncValue<List<Shift>>>((ref) {
  return ShiftHistoryNotifier(ref);
});

/// Provider for shift statistics during active shift
final shiftStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final activeShift = ref.watch(activeShiftProvider);
  final authState = ref.read(authProvider);

  if (activeShift.value == null || authState.tenant == null) {
    return {
      'transactionCount': 0,
      'totalCashSales': 0.0,
      'totalNonCashSales': 0.0
    };
  }

  List<Transaction> transactions;

  // Try cloud first if enabled
  if (AppConfig.useSupabase) {
    try {
      final cloudRepo = ref.read(cloudShiftRepositoryProvider);
      // Note: CloudRepository needs getTransactionsByShift
      transactions =
          await cloudRepo.getTransactionsByShift(activeShift.value!.id);
    } catch (e) {
      debugPrint('Cloud shift stats failed, falling back to local: $e');
      final transactionRepo = ref.read(transactionRepositoryProvider);
      transactions = await transactionRepo.getTransactionsByShift(
        authState.tenant!.id,
        activeShift.value!.id,
      );
    }
  } else {
    final transactionRepo = ref.read(transactionRepositoryProvider);
    transactions = await transactionRepo.getTransactionsByShift(
      authState.tenant!.id,
      activeShift.value!.id,
    );
  }

  final cashSales = transactions
      .where((t) => t.paymentMethod == 'cash')
      .fold<double>(0.0, (sum, t) => sum + t.total);

  final nonCashSales = transactions
      .where((t) => t.paymentMethod != 'cash')
      .fold<double>(0.0, (sum, t) => sum + t.total);

  return {
    'transactionCount': transactions.length,
    'totalCashSales': cashSales,
    'totalNonCashSales': nonCashSales,
  };
});

/// Notifier for managing active shift state
class ActiveShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final Ref ref;

  ActiveShiftNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadActiveShift();
  }

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return true; // Assume online if check fails
    }
  }

  /// Helper function to check connectivity results
  bool _checkConnectivityResults(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return true; // Assume online if unknown type
  }

  /// Validates tenant and returns tenantId or throws exception
  String _validateTenant() {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      throw Exception('Tenant tidak ditemukan. Silakan login ulang.');
    }
    final tenantId = authState.tenant!.id;
    if (tenantId.isEmpty) {
      throw Exception('ID Tenant tidak valid');
    }
    return tenantId;
  }

  /// Validates user and returns userId or throws exception
  String _validateUser() {
    final authState = ref.read(authProvider);
    if (authState.user == null) {
      throw Exception('User tidak ditemukan. Silakan login ulang.');
    }
    final userId = authState.user!.id;
    if (userId.isEmpty) {
      throw Exception('ID User tidak valid');
    }
    return userId;
  }

  /// Format error message for user-friendly display
  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network') ||
        errorStr.contains('timeout') ||
        errorStr.contains('host lookup')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }

    // Tenant errors
    if (errorStr.contains('tenant')) {
      return 'Tenant tidak ditemukan. Silakan login ulang.';
    }

    // Auth errors
    if (errorStr.contains('unauthorized') || errorStr.contains('auth')) {
      return 'Sesi telah berakhir. Silakan login ulang.';
    }

    // Shift specific errors
    if (errorStr.contains('shift aktif')) {
      return 'Anda sudah memiliki shift aktif. Silakan akhiri shift terlebih dahulu.';
    }
    if (errorStr.contains('tidak ada shift')) {
      return 'Tidak ada shift aktif untuk diakhiri.';
    }

    // Database errors
    if (errorStr.contains('database') || errorStr.contains('sqlite')) {
      return 'Gagal mengakses data lokal. Coba restart aplikasi.';
    }

    return error.toString().replaceAll('Exception: ', '');
  }

  /// Queue operation for sync when back online
  Future<void> _queueForSync(String operation, Shift shift) async {
    if (kIsWeb) return; // No sync queue for web

    try {
      final syncOp = SyncOperation(
        id: '${shift.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'shifts',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: shift.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue sync operation: $e');
    }
  }

  Future<void> loadActiveShift() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null || authState.user == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final tenantId = authState.tenant!.id;
      final userId = authState.user!.id;

      // Validate IDs
      if (tenantId.isEmpty || userId.isEmpty) {
        debugPrint('Invalid tenant or user ID');
        state = const AsyncValue.data(null);
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          final shift = await cloudRepo.getActiveShift(userId);
          state = AsyncValue.data(shift);
          return;
        } catch (e) {
          debugPrint(
              'Cloud active shift load failed, falling back to local: $e');
        }
      }

      // Fallback to local database
      if (!kIsWeb) {
        final repository = ref.read(shiftRepositoryProvider);
        final shift = await repository.getActiveShift(tenantId, userId);
        state = AsyncValue.data(shift);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      debugPrint('Error loading active shift: $e');
      state = AsyncValue.error(_formatErrorMessage(e), stack);
    }
  }

  /// Retry loading after error
  void retry() => loadActiveShift();

  /// Start a new shift
  /// Requirements 13.1: Record shift start time and opening cash
  Future<void> startShift(double openingCash) async {
    try {
      // Validate tenant and user
      final tenantId = _validateTenant();
      final userId = _validateUser();

      // Validate opening cash
      if (openingCash < 0) {
        throw Exception('Kas awal tidak boleh negatif');
      }
      if (openingCash > 999999999) {
        throw Exception('Kas awal melebihi batas maksimal (Rp 999.999.999)');
      }

      final shift = Shift(
        id: const Uuid().v4(),
        tenantId: tenantId,
        userId: userId,
        startTime: DateTime.now(),
        openingCash: openingCash,
        status: ShiftStatus.active,
        createdAt: DateTime.now(),
      );

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          final createdShift = await cloudRepo.createShift(shift);
          state = AsyncValue.data(createdShift);
          ref.read(shiftHistoryProvider.notifier).loadShiftHistory();
          return;
        } catch (e) {
          debugPrint('Cloud shift create failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Local database (offline mode or cloud failed)
      if (!kIsWeb) {
        final repository = ref.read(shiftRepositoryProvider);
        final result = await repository.startShift(shift);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal memulai shift');
        }

        state = AsyncValue.data(result.data);

        // Queue for sync when online (Android only)
        if (AppConfig.useSupabase && result.data != null) {
          await _queueForSync('insert', result.data!);
        }

        // Refresh shift history
        ref.read(shiftHistoryProvider.notifier).loadShiftHistory();
      } else {
        throw Exception('Tidak dapat memulai shift. Periksa koneksi internet.');
      }
    } catch (e) {
      debugPrint('Error starting shift: $e');
      throw Exception(_formatErrorMessage(e));
    }
  }

  /// End the current shift
  /// Requirements 13.2: Calculate expected cash and compare with actual
  Future<void> endShift(double closingCash, {String? varianceNote}) async {
    try {
      final currentShift = state.value;
      if (currentShift == null) {
        throw Exception('Tidak ada shift aktif untuk diakhiri');
      }

      // Validate tenant
      final tenantId = _validateTenant();

      // Validate closing cash
      if (closingCash < 0) {
        throw Exception('Kas akhir tidak boleh negatif');
      }
      if (closingCash > 999999999) {
        throw Exception('Kas akhir melebihi batas maksimal (Rp 999.999.999)');
      }

      // Calculate expected cash based on transactions during shift
      final expectedCash = await calculateExpectedCash(currentShift);

      // Validate variance note if there's a difference
      final variance = closingCash - expectedCash;
      if (variance.abs() > 0.01 &&
          (varianceNote == null || varianceNote.trim().isEmpty)) {
        throw Exception('Catatan wajib diisi jika ada selisih kas');
      }

      final isOnline = await _checkConnectivity();

      // Determine shift status based on variance
      final status =
          variance.abs() > 0.01 ? ShiftStatus.flagged : ShiftStatus.closed;

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          final updatedShift = Shift(
            id: currentShift.id,
            tenantId: currentShift.tenantId,
            userId: currentShift.userId,
            startTime: currentShift.startTime,
            endTime: DateTime.now(),
            openingCash: currentShift.openingCash,
            closingCash: closingCash,
            expectedCash: expectedCash,
            variance: variance,
            varianceNote: varianceNote,
            status: status,
            createdAt: currentShift.createdAt,
          );
          await cloudRepo.updateShift(updatedShift);
          state = const AsyncValue.data(null);
          ref.read(shiftHistoryProvider.notifier).loadShiftHistory();
          return;
        } catch (e) {
          debugPrint('Cloud shift end failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Local database (offline mode or cloud failed)
      if (!kIsWeb) {
        final repository = ref.read(shiftRepositoryProvider);
        final result = await repository.endShift(
          currentShift.id,
          closingCash,
          expectedCash,
          varianceNote: varianceNote,
          tenantId: tenantId, // Pass tenantId for validation
        );

        if (!result.success) {
          throw Exception(result.error ?? 'Gagal mengakhiri shift');
        }

        state = const AsyncValue.data(null);

        // Queue for sync when online (Android only)
        if (AppConfig.useSupabase && result.data != null) {
          await _queueForSync('update', result.data!);
        }

        // Refresh shift history
        ref.read(shiftHistoryProvider.notifier).loadShiftHistory();
      } else {
        throw Exception(
            'Tidak dapat mengakhiri shift. Periksa koneksi internet.');
      }
    } catch (e) {
      debugPrint('Error ending shift: $e');
      throw Exception(_formatErrorMessage(e));
    }
  }

  /// Calculate expected cash based on opening cash + cash transactions
  /// Requirements 13.2: Calculate expected cash based on transactions
  Future<double> calculateExpectedCash(Shift shift) async {
    final authState = ref.read(authProvider);
    if (authState.tenant == null) return shift.openingCash;

    try {
      List<Transaction> transactions;

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          transactions = await cloudRepo.getTransactionsByShift(shift.id);
        } catch (e) {
          debugPrint(
              'Cloud expected cash calc failed, falling back to local: $e');
          final transactionRepo = ref.read(transactionRepositoryProvider);
          transactions = await transactionRepo.getTransactionsByShift(
            authState.tenant!.id,
            shift.id,
          );
        }
      } else {
        final transactionRepo = ref.read(transactionRepositoryProvider);
        transactions = await transactionRepo.getTransactionsByShift(
          authState.tenant!.id,
          shift.id,
        );
      }

      // Sum only cash transactions
      final cashSales = transactions
          .where((t) => t.paymentMethod == 'cash')
          .fold<double>(0.0, (sum, t) => sum + t.total);

      return shift.openingCash + cashSales;
    } catch (e) {
      debugPrint('Error calculating expected cash: $e');
      // If error calculating, return opening cash as fallback
      return shift.openingCash;
    }
  }

  /// Get transaction count for current shift
  Future<int> getTransactionCount() async {
    final currentShift = state.value;
    if (currentShift == null) return 0;

    final authState = ref.read(authProvider);
    if (authState.tenant == null) return 0;

    try {
      List<Transaction> transactions;

      // Try cloud first if enabled
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          transactions =
              await cloudRepo.getTransactionsByShift(currentShift.id);
        } catch (e) {
          debugPrint('Cloud tx count failed, falling back to local: $e');
          final transactionRepo = ref.read(transactionRepositoryProvider);
          transactions = await transactionRepo.getTransactionsByShift(
            authState.tenant!.id,
            currentShift.id,
          );
        }
      } else {
        final transactionRepo = ref.read(transactionRepositoryProvider);
        transactions = await transactionRepo.getTransactionsByShift(
          authState.tenant!.id,
          currentShift.id,
        );
      }

      return transactions.length;
    } catch (e) {
      return 0;
    }
  }
}

/// Notifier for managing shift history
class ShiftHistoryNotifier extends StateNotifier<AsyncValue<List<Shift>>> {
  final Ref ref;

  ShiftHistoryNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadShiftHistory();
  }

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _checkConnectivityResults(results);
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Helper function to check connectivity results
  bool _checkConnectivityResults(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return true; // Assume online if unknown type
  }

  /// Format error message for user-friendly display
  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network') ||
        errorStr.contains('timeout')) {
      return 'Tidak dapat terhubung ke server. Menampilkan data lokal.';
    }

    if (errorStr.contains('tenant')) {
      return 'Tenant tidak ditemukan. Silakan login ulang.';
    }

    return 'Gagal memuat riwayat shift. Silakan coba lagi.';
  }

  Future<void> loadShiftHistory({DateTime? from, DateTime? to}) async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final tenantId = authState.tenant!.id;
      if (tenantId.isEmpty) {
        debugPrint('Invalid tenant ID');
        state = const AsyncValue.data([]);
        return;
      }

      final isOnline = await _checkConnectivity();

      // Try cloud first if enabled and online
      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudShiftRepositoryProvider);
          var shifts = await cloudRepo.getShifts(tenantId);

          // Role-based filtering for cloud
          final user = authState.user;
          if (user != null && user.role == UserRole.cashier) {
            shifts = shifts.where((s) => s.userId == user.id).toList();
          }

          // Apply date filter
          if (from != null) {
            shifts = shifts.where((s) => !s.startTime.isBefore(from)).toList();
          }
          if (to != null) {
            shifts = shifts.where((s) => !s.startTime.isAfter(to)).toList();
          }

          // Sort by start time descending
          shifts.sort((a, b) => b.startTime.compareTo(a.startTime));

          state = AsyncValue.data(shifts);
          return;
        } catch (e) {
          debugPrint(
              'Cloud shift history load failed, falling back to local: $e');
          // Continue to local fallback
        }
      }

      // Fallback to local database
      if (!kIsWeb) {
        final repository = ref.read(shiftRepositoryProvider);
        List<Shift> shifts;

        // Role-based filtering: Cashier only sees their own shifts
        // Owner/Admin can see all shifts
        final user = authState.user;
        if (user != null && user.role == UserRole.cashier) {
          // Cashier only sees their own shifts
          if (user.id.isEmpty) {
            debugPrint('Invalid user ID');
            state = const AsyncValue.data([]);
            return;
          }
          shifts = await repository.getShiftsByUser(tenantId, user.id);
        } else {
          // Owner/Admin sees all shifts
          shifts = await repository.getShiftHistory(
            tenantId,
            from: from,
            to: to,
          );
        }

        // Apply date filter if provided (for user-specific queries)
        if (from != null) {
          shifts = shifts.where((s) => !s.startTime.isBefore(from)).toList();
        }
        if (to != null) {
          shifts = shifts.where((s) => !s.startTime.isAfter(to)).toList();
        }

        state = AsyncValue.data(shifts);
      } else {
        // Web without cloud - show empty
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      debugPrint('Error loading shift history: $e');
      state = AsyncValue.error(_formatErrorMessage(e), stack);
    }
  }

  /// Retry loading after error
  void retry() => loadShiftHistory();
}

/// Provider for transaction repository (used for calculating expected cash)
final transactionRepositoryProvider =
    Provider((ref) => TransactionRepository());

/// Provider to check if current platform is offline-capable
final isOfflineCapableProvider = Provider<bool>((ref) => !kIsWeb);
