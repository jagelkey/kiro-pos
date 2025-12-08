import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../database/database_helper.dart';
import '../models/material.dart' as mat;
import '../mock/mock_data.dart';
import 'product_repository.dart';
import 'recipe_repository.dart';

/// Stock movement record for tracking material changes
class StockMovement {
  final String id;
  final String materialId;
  final String tenantId;
  final double previousStock;
  final double newStock;
  final double change;
  final String reason; // 'purchase', 'sale', 'adjustment', 'waste'
  final String? note;
  final DateTime timestamp;

  StockMovement({
    required this.id,
    required this.materialId,
    required this.tenantId,
    required this.previousStock,
    required this.newStock,
    required this.change,
    required this.reason,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'tenant_id': tenantId,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'change': change,
      'reason': reason,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      materialId: map['material_id'] as String,
      tenantId: map['tenant_id'] as String,
      previousStock: (map['previous_stock'] as num).toDouble(),
      newStock: (map['new_stock'] as num).toDouble(),
      change: (map['change'] as num).toDouble(),
      reason: map['reason'] as String,
      note: map['note'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

class MaterialRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - uses MockData directly for consistency
  static List<mat.Material> get _webMaterials => MockData.materials;

  // In-memory stock movements for web
  static final List<StockMovement> _webStockMovements = [];

  /// Get all materials for a tenant, optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.4: Multi-tenant data isolation with branch filtering
  Future<List<mat.Material>> getMaterials(String tenantId,
      {String? branchId}) async {
    try {
      if (kIsWeb) {
        // Note: Web mock data doesn't have branchId, so we skip branch filtering for web
        return _webMaterials.where((m) => m.tenantId == tenantId).toList();
      }

      final db = await _db.database;
      // Build query with optional branch filter
      String whereClause = 'tenant_id = ?';
      List<dynamic> whereArgs = [tenantId];

      if (branchId != null && branchId.isNotEmpty) {
        whereClause += ' AND branch_id = ?';
        whereArgs.add(branchId);
      }

      final results = await db.query(
        'materials',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );

      return results.map((map) => mat.Material.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting materials: $e');
      return [];
    }
  }

  /// Get a single material by ID
  Future<mat.Material?> getMaterial(String id) async {
    try {
      if (kIsWeb) {
        final index = _webMaterials.indexWhere((m) => m.id == id);
        return index != -1 ? _webMaterials[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'materials',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return mat.Material.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting material: $e');
      return null;
    }
  }

  /// Create a new material
  /// Returns RepositoryResult with the created material or error
  Future<RepositoryResult<mat.Material>> createMaterial(
      mat.Material material) async {
    try {
      // Validate required fields
      if (material.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama bahan baku wajib diisi');
      }
      if (material.stock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }
      if (material.unit.trim().isEmpty) {
        return RepositoryResult.failure('Satuan wajib diisi');
      }
      if (material.tenantId.isEmpty) {
        return RepositoryResult.failure('Tenant ID tidak valid');
      }
      if (material.minStock != null && material.minStock! < 0) {
        return RepositoryResult.failure('Stok minimum tidak boleh negatif');
      }

      if (kIsWeb) {
        // Check for duplicate ID
        final existingIndex =
            _webMaterials.indexWhere((m) => m.id == material.id);
        if (existingIndex != -1) {
          return RepositoryResult.failure('Bahan baku dengan ID ini sudah ada');
        }
        // Check for duplicate name within same tenant
        final duplicateName = _webMaterials.any((m) =>
            m.tenantId == material.tenantId &&
            m.name.toLowerCase() == material.name.toLowerCase().trim());
        if (duplicateName) {
          return RepositoryResult.failure(
              'Bahan baku dengan nama "${material.name}" sudah ada');
        }
        _webMaterials.add(material);

        // Record initial stock movement
        _recordStockMovementWeb(
          materialId: material.id,
          tenantId: material.tenantId,
          previousStock: 0,
          newStock: material.stock,
          reason: 'initial',
          note: 'Stok awal saat pembuatan',
        );

        return RepositoryResult.success(material);
      }

      final db = await _db.database;

      // Check for duplicate name within same tenant
      final duplicateCheck = await db.query(
        'materials',
        where: 'tenant_id = ? AND LOWER(name) = LOWER(?)',
        whereArgs: [material.tenantId, material.name.trim()],
      );
      if (duplicateCheck.isNotEmpty) {
        return RepositoryResult.failure(
            'Bahan baku dengan nama "${material.name}" sudah ada');
      }

      await db.insert('materials', material.toMap());

      // Record initial stock movement in SQLite
      await _recordStockMovementSQLite(
        db: db,
        materialId: material.id,
        tenantId: material.tenantId,
        previousStock: 0,
        newStock: material.stock,
        reason: 'initial',
        note: 'Stok awal saat pembuatan',
      );

      return RepositoryResult.success(material);
    } catch (e) {
      debugPrint('Error creating material: $e');
      return RepositoryResult.failure('Gagal membuat bahan baku: $e');
    }
  }

  /// Update an existing material
  /// Returns RepositoryResult with the updated material or error
  Future<RepositoryResult<mat.Material>> updateMaterial(
      mat.Material material) async {
    try {
      // Validate required fields
      if (material.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama bahan baku wajib diisi');
      }
      if (material.stock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }
      if (material.unit.trim().isEmpty) {
        return RepositoryResult.failure('Satuan wajib diisi');
      }
      if (material.minStock != null && material.minStock! < 0) {
        return RepositoryResult.failure('Stok minimum tidak boleh negatif');
      }

      if (kIsWeb) {
        final index = _webMaterials.indexWhere((m) => m.id == material.id);
        if (index == -1) {
          return RepositoryResult.failure('Bahan baku tidak ditemukan');
        }
        // Validate tenant ownership
        if (_webMaterials[index].tenantId != material.tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat mengubah bahan baku tenant lain');
        }
        // Check for duplicate name within same tenant (excluding current)
        final duplicateName = _webMaterials.any((m) =>
            m.id != material.id &&
            m.tenantId == material.tenantId &&
            m.name.toLowerCase() == material.name.toLowerCase().trim());
        if (duplicateName) {
          return RepositoryResult.failure(
              'Bahan baku dengan nama "${material.name}" sudah ada');
        }

        final oldMaterial = _webMaterials[index];
        _webMaterials[index] = material;

        // Record stock movement if stock changed
        if (oldMaterial.stock != material.stock) {
          _recordStockMovementWeb(
            materialId: material.id,
            tenantId: material.tenantId,
            previousStock: oldMaterial.stock,
            newStock: material.stock,
            reason: 'adjustment',
            note: 'Stok diperbarui via edit bahan baku',
          );
        }

        return RepositoryResult.success(material);
      }

      final db = await _db.database;

      // Check for duplicate name within same tenant (excluding current)
      final duplicateCheck = await db.query(
        'materials',
        where: 'tenant_id = ? AND LOWER(name) = LOWER(?) AND id != ?',
        whereArgs: [material.tenantId, material.name.trim(), material.id],
      );
      if (duplicateCheck.isNotEmpty) {
        return RepositoryResult.failure(
            'Bahan baku dengan nama "${material.name}" sudah ada');
      }

      // Get old material for stock comparison
      final oldMaterial = await getMaterial(material.id);

      final rowsAffected = await db.update(
        'materials',
        material.toMap(),
        where: 'id = ? AND tenant_id = ?', // Ensure tenant ownership
        whereArgs: [material.id, material.tenantId],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Bahan baku tidak ditemukan');
      }

      // Record stock movement if stock changed
      if (oldMaterial != null && oldMaterial.stock != material.stock) {
        await _recordStockMovementSQLite(
          db: db,
          materialId: material.id,
          tenantId: material.tenantId,
          previousStock: oldMaterial.stock,
          newStock: material.stock,
          reason: 'adjustment',
          note: 'Stock updated via material edit',
        );
      }

      return RepositoryResult.success(material);
    } catch (e) {
      debugPrint('Error updating material: $e');
      return RepositoryResult.failure('Gagal memperbarui bahan baku: $e');
    }
  }

  /// Delete a material by ID
  /// Returns RepositoryResult with success status or error
  /// tenantId is required for multi-tenant validation
  Future<RepositoryResult<bool>> deleteMaterial(String id,
      {String? tenantId}) async {
    try {
      // Check if material is used in any recipe
      if (tenantId != null) {
        final isUsedInRecipe = await _isMaterialUsedInRecipe(id, tenantId);
        if (isUsedInRecipe) {
          return RepositoryResult.failure(
              'Bahan baku ini masih digunakan di resep produk. Hapus dari resep terlebih dahulu.');
        }
      }

      if (kIsWeb) {
        final index = _webMaterials.indexWhere((m) => m.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Bahan baku tidak ditemukan');
        }
        // Validate tenant ownership if tenantId provided
        if (tenantId != null && _webMaterials[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat menghapus bahan baku tenant lain');
        }
        _webMaterials.removeAt(index);
        // Also remove related stock movements
        _webStockMovements.removeWhere((sm) => sm.materialId == id);
        return RepositoryResult.success(true);
      }

      final db = await _db.database;

      // Build query with optional tenant validation
      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [id];
      if (tenantId != null) {
        whereClause += ' AND tenant_id = ?';
        whereArgs.add(tenantId);
      }

      final rowsAffected = await db.delete(
        'materials',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Bahan baku tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting material: $e');
      return RepositoryResult.failure('Gagal menghapus bahan baku: $e');
    }
  }

  /// Check if material is used in any recipe
  Future<bool> _isMaterialUsedInRecipe(
      String materialId, String tenantId) async {
    try {
      final recipeRepo = RecipeRepository();
      final recipes = await recipeRepo.getAllRecipes(tenantId);

      for (var entry in recipes.entries) {
        for (var ingredient in entry.value) {
          if (ingredient.materialId == materialId) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking material usage in recipes: $e');
      return false; // Allow deletion if check fails
    }
  }

  /// Update material stock with movement recording
  /// Returns RepositoryResult with the updated material or error
  Future<RepositoryResult<mat.Material>> updateStock(
    String id,
    double newStock, {
    required String reason,
    String? note,
  }) async {
    try {
      if (newStock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }

      final material = await getMaterial(id);
      if (material == null) {
        return RepositoryResult.failure('Bahan baku tidak ditemukan');
      }

      final previousStock = material.stock;

      if (kIsWeb) {
        final index = _webMaterials.indexWhere((m) => m.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Bahan baku tidak ditemukan');
        }

        final updatedMaterial = mat.Material(
          id: material.id,
          tenantId: material.tenantId,
          name: material.name,
          stock: newStock,
          unit: material.unit,
          minStock: material.minStock,
          category: material.category,
          createdAt: material.createdAt,
        );
        _webMaterials[index] = updatedMaterial;

        // Record stock movement
        _recordStockMovementWeb(
          materialId: id,
          tenantId: material.tenantId,
          previousStock: previousStock,
          newStock: newStock,
          reason: reason,
          note: note,
        );

        return RepositoryResult.success(updatedMaterial);
      }

      final db = await _db.database;
      final rowsAffected = await db.update(
        'materials',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Material not found');
      }

      // Record stock movement
      await _recordStockMovementSQLite(
        db: db,
        materialId: id,
        tenantId: material.tenantId,
        previousStock: previousStock,
        newStock: newStock,
        reason: reason,
        note: note,
      );

      // Fetch and return the updated material
      final updatedMaterial = await getMaterial(id);
      return RepositoryResult.success(updatedMaterial);
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return RepositoryResult.failure('Gagal memperbarui stok: $e');
    }
  }

  /// Decrease material stock (used during transactions)
  /// Returns RepositoryResult with the updated material or error
  Future<RepositoryResult<mat.Material>> decreaseStock(
    String id,
    double quantity, {
    String? note,
  }) async {
    try {
      if (quantity <= 0) {
        return RepositoryResult.failure('Jumlah harus positif');
      }

      final material = await getMaterial(id);
      if (material == null) {
        return RepositoryResult.failure('Bahan baku tidak ditemukan');
      }

      final newStock = material.stock - quantity;
      if (newStock < 0) {
        return RepositoryResult.failure('Stok tidak mencukupi');
      }

      return updateStock(id, newStock, reason: 'sale', note: note);
    } catch (e) {
      debugPrint('Error decreasing stock: $e');
      return RepositoryResult.failure('Gagal mengurangi stok: $e');
    }
  }

  /// Increase material stock (used for purchases/restocking)
  /// Returns RepositoryResult with the updated material or error
  Future<RepositoryResult<mat.Material>> increaseStock(
    String id,
    double quantity, {
    String? note,
  }) async {
    try {
      if (quantity <= 0) {
        return RepositoryResult.failure('Jumlah harus positif');
      }

      final material = await getMaterial(id);
      if (material == null) {
        return RepositoryResult.failure('Bahan baku tidak ditemukan');
      }

      final newStock = material.stock + quantity;
      return updateStock(id, newStock, reason: 'purchase', note: note);
    } catch (e) {
      debugPrint('Error increasing stock: $e');
      return RepositoryResult.failure('Gagal menambah stok: $e');
    }
  }

  /// Get materials with low stock (stock <= minStock), optionally filtered by branch
  /// Requirements 2.5, 3.4: Multi-tenant data isolation with branch filtering
  Future<List<mat.Material>> getLowStockMaterials(String tenantId,
      {String? branchId}) async {
    try {
      final materials = await getMaterials(tenantId, branchId: branchId);
      // Use Material model's built-in isLowStock or isOutOfStock properties
      return materials.where((m) => m.isLowStock || m.isOutOfStock).toList();
    } catch (e) {
      debugPrint('Error getting low stock materials: $e');
      return [];
    }
  }

  /// Get stock movements for a material
  Future<List<StockMovement>> getStockMovements(String materialId) async {
    try {
      if (kIsWeb) {
        return _webStockMovements
            .where((sm) => sm.materialId == materialId)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      final db = await _db.database;
      final results = await db.query(
        'stock_movements',
        where: 'material_id = ?',
        whereArgs: [materialId],
        orderBy: 'timestamp DESC',
      );

      return results.map((map) => StockMovement.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting stock movements: $e');
      return [];
    }
  }

  /// Get materials by category
  Future<List<mat.Material>> getMaterialsByCategory(
      String tenantId, String category) async {
    try {
      final materials = await getMaterials(tenantId);
      return materials.where((m) => m.category == category).toList();
    } catch (e) {
      debugPrint('Error getting materials by category: $e');
      return [];
    }
  }

  // Private helper methods for recording stock movements
  void _recordStockMovementWeb({
    required String materialId,
    required String tenantId,
    required double previousStock,
    required double newStock,
    required String reason,
    String? note,
  }) {
    final movement = StockMovement(
      id: 'sm-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      tenantId: tenantId,
      previousStock: previousStock,
      newStock: newStock,
      change: newStock - previousStock,
      reason: reason,
      note: note,
      timestamp: DateTime.now(),
    );
    _webStockMovements.add(movement);
  }

  Future<void> _recordStockMovementSQLite({
    required dynamic db,
    required String materialId,
    required String tenantId,
    required double previousStock,
    required double newStock,
    required String reason,
    String? note,
  }) async {
    try {
      final movement = StockMovement(
        id: 'sm-${DateTime.now().millisecondsSinceEpoch}',
        materialId: materialId,
        tenantId: tenantId,
        previousStock: previousStock,
        newStock: newStock,
        change: newStock - previousStock,
        reason: reason,
        note: note,
        timestamp: DateTime.now(),
      );

      // Check if stock_movements table exists before inserting
      // If it doesn't exist, we'll skip recording (table will be created in future migration)
      try {
        await db.insert('stock_movements', movement.toMap());
      } catch (e) {
        // Table might not exist yet, log and continue
        debugPrint('Stock movements table not available: $e');
      }
    } catch (e) {
      debugPrint('Error recording stock movement: $e');
    }
  }
}
