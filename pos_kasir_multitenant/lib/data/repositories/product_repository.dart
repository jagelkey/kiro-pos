import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../mock/mock_data.dart';

/// Result class for repository operations
class RepositoryResult<T> {
  final T? data;
  final bool success;
  final String? error;

  RepositoryResult.success(this.data)
      : success = true,
        error = null;

  RepositoryResult.failure(this.error)
      : success = false,
        data = null;
}

class ProductRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // In-memory storage for web - uses MockData directly for consistency
  static List<Product> get _webProducts => MockData.products;

  /// Get all products for a tenant, optionally filtered by branch
  /// Requirements 2.1, 2.2, 2.4: Multi-tenant data isolation with branch filtering
  /// Supports offline mode for Android
  Future<List<Product>> getProducts(String tenantId, {String? branchId}) async {
    try {
      // Validate tenantId
      if (tenantId.isEmpty) {
        debugPrint('Warning: Empty tenantId provided to getProducts');
        return [];
      }

      if (kIsWeb) {
        // Note: Web mock data doesn't have branchId, so we skip branch filtering for web
        return _webProducts.where((p) => p.tenantId == tenantId).toList();
      }

      final db = await _db.database;
      // Build query with optional branch filter
      // Note: Products table may not have branch_id column in all schemas
      // For now, filter by tenant only - products are typically shared across branches
      String whereClause = 'tenant_id = ?';
      List<dynamic> whereArgs = [tenantId];

      // Branch filtering is optional for products (products can be shared across branches)
      // Uncomment below if products should be branch-specific
      // if (branchId != null && branchId.isNotEmpty) {
      //   whereClause += ' AND (branch_id = ? OR branch_id IS NULL)';
      //   whereArgs.add(branchId);
      // }

      final results = await db.query(
        'products',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );

      return results.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  /// Get a single product by ID
  Future<Product?> getProduct(String id) async {
    try {
      if (kIsWeb) {
        final index = _webProducts.indexWhere((p) => p.id == id);
        return index != -1 ? _webProducts[index] : null;
      }

      final db = await _db.database;
      final results = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) return null;
      return Product.fromMap(results.first);
    } catch (e) {
      debugPrint('Error getting product: $e');
      return null;
    }
  }

  /// Create a new product
  /// Returns RepositoryResult with the created product or error
  Future<RepositoryResult<Product>> createProduct(Product product) async {
    try {
      // Validate required fields
      if (product.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama produk wajib diisi');
      }
      if (product.price < 0) {
        return RepositoryResult.failure('Harga tidak boleh negatif');
      }
      if (product.stock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }
      if (product.tenantId.isEmpty) {
        return RepositoryResult.failure('Tenant ID tidak valid');
      }

      if (kIsWeb) {
        // Check for duplicate ID
        final existingIndex =
            _webProducts.indexWhere((p) => p.id == product.id);
        if (existingIndex != -1) {
          return RepositoryResult.failure('Produk dengan ID ini sudah ada');
        }
        // Check for duplicate name within same tenant
        final duplicateName = _webProducts.any((p) =>
            p.tenantId == product.tenantId &&
            p.name.toLowerCase() == product.name.toLowerCase().trim());
        if (duplicateName) {
          return RepositoryResult.failure(
              'Produk dengan nama "${product.name}" sudah ada');
        }
        _webProducts.add(product);
        return RepositoryResult.success(product);
      }

      final db = await _db.database;

      // Check for duplicate name within same tenant
      final duplicateCheck = await db.query(
        'products',
        where: 'tenant_id = ? AND LOWER(name) = LOWER(?)',
        whereArgs: [product.tenantId, product.name.trim()],
      );
      if (duplicateCheck.isNotEmpty) {
        return RepositoryResult.failure(
            'Produk dengan nama "${product.name}" sudah ada');
      }

      await db.insert('products', product.toMap());
      return RepositoryResult.success(product);
    } catch (e) {
      debugPrint('Error creating product: $e');
      return RepositoryResult.failure('Gagal membuat produk: $e');
    }
  }

  /// Update an existing product
  /// Returns RepositoryResult with the updated product or error
  Future<RepositoryResult<Product>> updateProduct(Product product) async {
    try {
      // Validate required fields
      if (product.name.trim().isEmpty) {
        return RepositoryResult.failure('Nama produk wajib diisi');
      }
      if (product.price < 0) {
        return RepositoryResult.failure('Harga tidak boleh negatif');
      }
      if (product.stock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }

      if (kIsWeb) {
        final index = _webProducts.indexWhere((p) => p.id == product.id);
        if (index == -1) {
          return RepositoryResult.failure('Produk tidak ditemukan');
        }
        // Validate tenant ownership
        if (_webProducts[index].tenantId != product.tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat mengubah produk tenant lain');
        }
        // Check for duplicate name within same tenant (excluding current product)
        final duplicateName = _webProducts.any((p) =>
            p.id != product.id &&
            p.tenantId == product.tenantId &&
            p.name.toLowerCase() == product.name.toLowerCase().trim());
        if (duplicateName) {
          return RepositoryResult.failure(
              'Produk dengan nama "${product.name}" sudah ada');
        }
        _webProducts[index] = product;
        return RepositoryResult.success(product);
      }

      final db = await _db.database;

      // Check for duplicate name within same tenant (excluding current product)
      final duplicateCheck = await db.query(
        'products',
        where: 'tenant_id = ? AND LOWER(name) = LOWER(?) AND id != ?',
        whereArgs: [product.tenantId, product.name.trim(), product.id],
      );
      if (duplicateCheck.isNotEmpty) {
        return RepositoryResult.failure(
            'Produk dengan nama "${product.name}" sudah ada');
      }

      final rowsAffected = await db.update(
        'products',
        product.toMap(),
        where: 'id = ? AND tenant_id = ?', // Ensure tenant ownership
        whereArgs: [product.id, product.tenantId],
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Produk tidak ditemukan');
      }
      return RepositoryResult.success(product);
    } catch (e) {
      debugPrint('Error updating product: $e');
      return RepositoryResult.failure('Gagal memperbarui produk: $e');
    }
  }

  /// Delete a product by ID
  /// Returns RepositoryResult with success status or error
  /// tenantId is required for multi-tenant validation
  Future<RepositoryResult<bool>> deleteProduct(String id,
      {String? tenantId}) async {
    try {
      if (kIsWeb) {
        final index = _webProducts.indexWhere((p) => p.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Produk tidak ditemukan');
        }
        // Validate tenant ownership if tenantId provided
        if (tenantId != null && _webProducts[index].tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat menghapus produk tenant lain');
        }
        _webProducts.removeAt(index);
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
        'products',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Produk tidak ditemukan');
      }
      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return RepositoryResult.failure('Gagal menghapus produk: $e');
    }
  }

  /// Update product stock
  /// Returns RepositoryResult with the updated product or error
  /// tenantId is optional for multi-tenant validation
  Future<RepositoryResult<Product>> updateStock(String id, int newStock,
      {String? tenantId}) async {
    try {
      if (id.isEmpty) {
        return RepositoryResult.failure('ID produk tidak valid');
      }
      if (newStock < 0) {
        return RepositoryResult.failure('Stok tidak boleh negatif');
      }
      if (newStock > 999999) {
        return RepositoryResult.failure('Stok maksimal 999.999');
      }

      if (kIsWeb) {
        final index = _webProducts.indexWhere((p) => p.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Produk tidak ditemukan');
        }
        final product = _webProducts[index];

        // Validate tenant ownership if tenantId provided
        if (tenantId != null && product.tenantId != tenantId) {
          return RepositoryResult.failure(
              'Tidak dapat mengubah produk tenant lain');
        }

        final updatedProduct = product.copyWith(stock: newStock);
        _webProducts[index] = updatedProduct;
        return RepositoryResult.success(updatedProduct);
      }

      final db = await _db.database;

      // Build query with optional tenant validation
      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [id];
      if (tenantId != null) {
        whereClause += ' AND tenant_id = ?';
        whereArgs.add(tenantId);
      }

      final rowsAffected = await db.update(
        'products',
        {'stock': newStock},
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (rowsAffected == 0) {
        return RepositoryResult.failure('Produk tidak ditemukan');
      }

      // Fetch and return the updated product
      final updatedProduct = await getProduct(id);
      return RepositoryResult.success(updatedProduct);
    } catch (e) {
      debugPrint('Error updating stock: $e');
      return RepositoryResult.failure('Gagal memperbarui stok: $e');
    }
  }

  /// Decrease product stock by quantity (used during transactions)
  /// Returns RepositoryResult with the updated product or error
  Future<RepositoryResult<Product>> decreaseStock(
      String id, int quantity) async {
    try {
      if (quantity <= 0) {
        return RepositoryResult.failure('Quantity must be positive');
      }

      final product = await getProduct(id);
      if (product == null) {
        return RepositoryResult.failure('Product not found');
      }

      final newStock = product.stock - quantity;
      if (newStock < 0) {
        return RepositoryResult.failure('Insufficient stock');
      }

      return updateStock(id, newStock);
    } catch (e) {
      debugPrint('Error decreasing stock: $e');
      return RepositoryResult.failure('Failed to decrease stock: $e');
    }
  }

  /// Get products with low stock (stock <= threshold)
  Future<List<Product>> getLowStockProducts(String tenantId,
      {int threshold = 10}) async {
    try {
      final products = await getProducts(tenantId);
      return products.where((p) => p.stock <= threshold).toList();
    } catch (e) {
      debugPrint('Error getting low stock products: $e');
      return [];
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(
      String tenantId, String category) async {
    try {
      final products = await getProducts(tenantId);
      return products.where((p) => p.category == category).toList();
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  /// Search products by name
  Future<List<Product>> searchProducts(String tenantId, String query) async {
    try {
      final products = await getProducts(tenantId);
      final lowerQuery = query.toLowerCase();
      return products
          .where((p) => p.name.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  /// Decrease stock with row-level locking (atomic operation)
  /// CRITICAL: Prevents race conditions during concurrent checkouts
  /// Must be called within a transaction
  Future<RepositoryResult<Product>> decreaseStockAtomic(
    String id,
    int quantity, {
    required DatabaseExecutor txn,
  }) async {
    try {
      if (kIsWeb) {
        // Web fallback - no true locking available
        final index = _webProducts.indexWhere((p) => p.id == id);
        if (index == -1) {
          return RepositoryResult.failure('Produk tidak ditemukan');
        }

        final product = _webProducts[index];
        if (product.stock < quantity) {
          return RepositoryResult.failure(
            'Stok tidak mencukupi. Tersedia: ${product.stock}, Dibutuhkan: $quantity',
          );
        }

        final updatedProduct =
            product.copyWith(stock: product.stock - quantity);
        _webProducts[index] = updatedProduct;
        return RepositoryResult.success(updatedProduct);
      }

      // Lock row for update (prevents concurrent modifications)
      final results = await txn.rawQuery(
        'SELECT * FROM products WHERE id = ?',
        [id],
      );

      if (results.isEmpty) {
        return RepositoryResult.failure('Produk tidak ditemukan');
      }

      final product = Product.fromMap(results.first);

      // Validate stock availability
      if (product.stock < quantity) {
        return RepositoryResult.failure(
          'Stok tidak mencukupi. Tersedia: ${product.stock}, Dibutuhkan: $quantity',
        );
      }

      // Update stock atomically
      final newStock = product.stock - quantity;
      await txn.update(
        'products',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [id],
      );

      return RepositoryResult.success(product.copyWith(stock: newStock));
    } catch (e) {
      debugPrint('Error in decreaseStockAtomic: $e');
      return RepositoryResult.failure('Gagal update stok: $e');
    }
  }

  /// Batch decrease stock for multiple products atomically
  /// Used during checkout to update all product stocks in one transaction
  Future<RepositoryResult<List<Product>>> decreaseStockBatch(
    Map<String, int> productQuantities, {
    required DatabaseExecutor txn,
  }) async {
    try {
      final updatedProducts = <Product>[];

      for (final entry in productQuantities.entries) {
        final result = await decreaseStockAtomic(
          entry.key,
          entry.value,
          txn: txn,
        );

        if (!result.success) {
          return RepositoryResult.failure(result.error ?? 'Gagal update stok');
        }

        updatedProducts.add(result.data!);
      }

      return RepositoryResult.success(updatedProducts);
    } catch (e) {
      debugPrint('Error in decreaseStockBatch: $e');
      return RepositoryResult.failure('Gagal update batch stok: $e');
    }
  }
}
