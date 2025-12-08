import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/supabase_service.dart';
import '../../data/database/database_helper.dart';

/// Sync Manager - Handles automatic synchronization between SQLite and Supabase
/// Implements offline-first architecture with automatic sync when online
class SyncManager {
  static SyncManager? _instance;
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;

  // Sync queue for offline operations
  final List<SyncOperation> _syncQueue = [];

  SyncManager._();

  static SyncManager get instance {
    _instance ??= SyncManager._();
    return _instance!;
  }

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _syncQueue.length;

  /// Initialize sync manager and start monitoring connectivity
  Future<void> initialize() async {
    // Check initial connectivity
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    // Listen to connectivity changes
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      // If just came online, trigger sync
      if (!wasOnline && _isOnline) {
        syncPendingOperations();
      }
    });

    // Load pending operations from database
    await _loadPendingOperations();

    // If online, sync immediately
    if (_isOnline) {
      syncPendingOperations();
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Add operation to sync queue
  Future<void> queueOperation(SyncOperation operation) async {
    _syncQueue.add(operation);
    await _savePendingOperations();

    // If online, sync immediately
    if (_isOnline && !_isSyncing) {
      syncPendingOperations();
    }
  }

  /// Sync all pending operations
  Future<void> syncPendingOperations() async {
    if (_isSyncing || _syncQueue.isEmpty || !_isOnline) return;

    _isSyncing = true;

    try {
      final operations = List<SyncOperation>.from(_syncQueue);

      for (final operation in operations) {
        try {
          await _executeSyncOperation(operation);
          _syncQueue.remove(operation);
        } catch (e) {
          // Keep operation in queue if sync fails
          print('Sync failed for ${operation.table}/${operation.id}: $e');
        }
      }

      await _savePendingOperations();
    } finally {
      _isSyncing = false;
    }
  }

  /// Execute a single sync operation
  Future<void> _executeSyncOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.insert:
        await _syncInsert(operation);
        break;
      case SyncOperationType.update:
        await _syncUpdate(operation);
        break;
      case SyncOperationType.delete:
        await _syncDelete(operation);
        break;
    }
  }

  Future<void> _syncInsert(SyncOperation operation) async {
    switch (operation.table) {
      case 'products':
        await _supabase.createProduct(operation.data);
        break;
      case 'materials':
        await _supabase.createMaterial(operation.data);
        break;
      case 'transactions':
        await _supabase.createTransaction(operation.data);
        break;
      case 'expenses':
        await _supabase.createExpense(operation.data);
        break;
      case 'shifts':
        await _supabase.createShift(operation.data);
        break;
      case 'discounts':
        await _supabase.createDiscount(operation.data);
        break;
      case 'users':
        await _supabase.createUser(operation.data);
        break;
      case 'branches':
        await _supabase.createBranch(operation.data);
        break;
      case 'recipes':
        await _supabase.createRecipe(operation.data);
        break;
      case 'stock_movements':
        await _supabase.createStockMovement(operation.data);
        break;
    }
  }

  Future<void> _syncUpdate(SyncOperation operation) async {
    switch (operation.table) {
      case 'products':
        await _supabase.updateProduct(operation.id, operation.data);
        break;
      case 'materials':
        await _supabase.updateMaterial(operation.id, operation.data);
        break;
      case 'expenses':
        await _supabase.updateExpense(operation.id, operation.data);
        break;
      case 'shifts':
        await _supabase.updateShift(operation.id, operation.data);
        break;
      case 'discounts':
        await _supabase.updateDiscount(operation.id, operation.data);
        break;
      case 'users':
        await _supabase.updateUser(operation.id, operation.data);
        break;
      case 'branches':
        await _supabase.updateBranch(operation.id, operation.data);
        break;
      case 'recipes':
        await _supabase.updateRecipe(operation.id, operation.data);
        break;
    }
  }

  Future<void> _syncDelete(SyncOperation operation) async {
    switch (operation.table) {
      case 'products':
        await _supabase.deleteProduct(operation.id);
        break;
      case 'materials':
        await _supabase.deleteMaterial(operation.id);
        break;
      case 'transactions':
        await _supabase.deleteTransaction(operation.id);
        break;
      case 'expenses':
        await _supabase.deleteExpense(operation.id);
        break;
      case 'discounts':
        await _supabase.deleteDiscount(operation.id);
        break;
      case 'users':
        await _supabase.deleteUser(operation.id);
        break;
      case 'branches':
        await _supabase.deleteBranch(operation.id);
        break;
      case 'recipes':
        await _supabase.deleteRecipe(operation.id);
        break;
    }
  }

  /// Load pending operations from database
  Future<void> _loadPendingOperations() async {
    try {
      final db = await _db.database;
      final results = await db.query('sync_queue', orderBy: 'created_at ASC');

      _syncQueue.clear();
      for (final row in results) {
        _syncQueue.add(SyncOperation.fromMap(row));
      }
    } catch (e) {
      // Table might not exist yet, ignore
    }
  }

  /// Save pending operations to database
  Future<void> _savePendingOperations() async {
    try {
      final db = await _db.database;

      // Clear existing queue
      await db.delete('sync_queue');

      // Insert current queue
      for (final operation in _syncQueue) {
        await db.insert('sync_queue', operation.toMap());
      }
    } catch (e) {
      print('Failed to save sync queue: $e');
    }
  }

  /// Clear all pending operations (use with caution)
  Future<void> clearQueue() async {
    _syncQueue.clear();
    await _savePendingOperations();
  }
}

/// Sync operation types
enum SyncOperationType {
  insert,
  update,
  delete,
}

/// Sync operation model
class SyncOperation {
  final String id;
  final String table;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  SyncOperation({
    required this.id,
    required this.table,
    required this.type,
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table': table,
      'type': type.toString().split('.').last,
      'data': data.toString(), // Store as JSON string
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'] as String,
      table: map['table'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      data: map['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
