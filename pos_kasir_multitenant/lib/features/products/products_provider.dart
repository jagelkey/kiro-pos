import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../core/config/app_config.dart';
import '../../core/services/sync_manager.dart';
import '../auth/auth_provider.dart';

export '../auth/auth_provider.dart' show authProvider;

final productRepositoryProvider = Provider((ref) => ProductRepository());
final cloudRepositoryProvider = Provider((ref) => CloudRepository());

/// Provider untuk cek konektivitas
final productConnectivityProvider = FutureProvider<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return _checkConnectivityResults(results);
});

/// Helper function to check connectivity results
/// Handles both List<ConnectivityResult> (new API) and single ConnectivityResult (old API)
bool _checkConnectivityResults(dynamic results) {
  if (results is List<ConnectivityResult>) {
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  } else if (results is ConnectivityResult) {
    return results != ConnectivityResult.none;
  }
  return true; // Assume online if unknown type
}

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.tenant == null) return [];

  final repository = ref.read(productRepositoryProvider);
  // Support branch filtering for multi-tenant
  return repository.getProducts(
    authState.tenant!.id,
    branchId: authState.user?.branchId,
  );
});

final productProvider =
    StateNotifierProvider<ProductNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductNotifier(ref);
});

class ProductNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref ref;

  ProductNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadProducts();
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

  Future<void> loadProducts() async {
    state = const AsyncValue.loading();
    try {
      final authState = ref.read(authProvider);
      if (authState.tenant == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final tenantId = authState.tenant!.id;
      if (tenantId.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final branchId = authState.user?.branchId;
      List<Product> products;

      // Check connectivity for offline-first approach
      final isOnline = await _checkConnectivity();

      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          products = await cloudRepo.getProducts(tenantId, branchId: branchId);
        } catch (e) {
          // Fallback to local database if cloud fails
          debugPrint('Cloud fetch failed, falling back to local: $e');
          if (!kIsWeb) {
            final repository = ref.read(productRepositoryProvider);
            products =
                await repository.getProducts(tenantId, branchId: branchId);
          } else {
            rethrow;
          }
        }
      } else {
        // Offline mode or Supabase not configured
        final repository = ref.read(productRepositoryProvider);
        products = await repository.getProducts(tenantId, branchId: branchId);
      }
      state = AsyncValue.data(products);
    } catch (e, stack) {
      debugPrint('Error loading products: $e');
      state = AsyncValue.error(e, stack);
    }
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

  Future<void> addProduct(Product product) async {
    try {
      final tenantId = _validateTenant();

      // Ensure product has correct tenantId (branchId is optional for products)
      final productWithTenant = product.copyWith(
        tenantId: tenantId,
      );

      // Validate product data
      if (productWithTenant.name.trim().isEmpty) {
        throw Exception('Nama produk wajib diisi');
      }
      if (productWithTenant.price < 0) {
        throw Exception('Harga tidak boleh negatif');
      }
      if (productWithTenant.stock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      // Validate max stock
      if (productWithTenant.stock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }
      // Validate max price
      if (productWithTenant.price > 999999999) {
        throw Exception('Harga maksimal Rp 999.999.999');
      }

      final isOnline = await _checkConnectivity();

      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          await cloudRepo.createProduct(productWithTenant);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud create failed, saving locally: $e');
            final repository = ref.read(productRepositoryProvider);
            final result = await repository.createProduct(productWithTenant);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal membuat produk');
            }
            // Queue for sync when online
            await _queueForSync('insert', productWithTenant);
          } else {
            rethrow;
          }
        }
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result = await repository.createProduct(productWithTenant);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal membuat produk');
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('insert', productWithTenant);
        }
      }

      // Force refresh to update all screens
      await loadProducts();
      ref.invalidate(productsProvider);
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
  }

  /// Queue operation for sync when back online
  Future<void> _queueForSync(String operation, Product product) async {
    try {
      final syncOp = SyncOperation(
        id: '${product.id}-$operation-${DateTime.now().millisecondsSinceEpoch}',
        table: 'products',
        type: operation == 'insert'
            ? SyncOperationType.insert
            : operation == 'update'
                ? SyncOperationType.update
                : SyncOperationType.delete,
        data: product.toMap(),
      );
      await SyncManager.instance.queueOperation(syncOp);
    } catch (e) {
      debugPrint('Failed to queue sync operation: $e');
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final tenantId = _validateTenant();

      // Ensure product has correct tenantId
      final productWithTenant = product.copyWith(tenantId: tenantId);

      // Validate product data
      if (productWithTenant.name.trim().isEmpty) {
        throw Exception('Nama produk wajib diisi');
      }
      if (productWithTenant.price < 0) {
        throw Exception('Harga tidak boleh negatif');
      }
      if (productWithTenant.stock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      // Validate max stock
      if (productWithTenant.stock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }
      // Validate max price
      if (productWithTenant.price > 999999999) {
        throw Exception('Harga maksimal Rp 999.999.999');
      }

      final isOnline = await _checkConnectivity();

      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          await cloudRepo.updateProduct(productWithTenant);
        } catch (e) {
          // Offline fallback: save locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud update failed, saving locally: $e');
            final repository = ref.read(productRepositoryProvider);
            final result = await repository.updateProduct(productWithTenant);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal memperbarui produk');
            }
            // Queue for sync when online
            await _queueForSync('update', productWithTenant);
          } else {
            rethrow;
          }
        }
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result = await repository.updateProduct(productWithTenant);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal memperbarui produk');
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          await _queueForSync('update', productWithTenant);
        }
      }

      // Force refresh to update all screens
      await loadProducts();
      ref.invalidate(productsProvider);
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final tenantId = _validateTenant();

      if (id.isEmpty) {
        throw Exception('ID produk tidak valid');
      }

      final isOnline = await _checkConnectivity();

      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          await cloudRepo.deleteProduct(id);
        } catch (e) {
          // Offline fallback: delete locally and queue for sync
          if (!kIsWeb) {
            debugPrint('Cloud delete failed, deleting locally: $e');
            final repository = ref.read(productRepositoryProvider);
            final result =
                await repository.deleteProduct(id, tenantId: tenantId);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal menghapus produk');
            }
            // Queue for sync when online - create dummy product for sync data
            final dummyProduct = Product(
              id: id,
              tenantId: tenantId,
              name: '',
              price: 0,
              stock: 0,
              createdAt: DateTime.now(),
            );
            await _queueForSync('delete', dummyProduct);
          } else {
            rethrow;
          }
        }
      } else {
        final repository = ref.read(productRepositoryProvider);
        // Pass tenantId for multi-tenant validation
        final result = await repository.deleteProduct(
          id,
          tenantId: tenantId,
        );
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal menghapus produk');
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase) {
          final dummyProduct = Product(
            id: id,
            tenantId: tenantId,
            name: '',
            price: 0,
            stock: 0,
            createdAt: DateTime.now(),
          );
          await _queueForSync('delete', dummyProduct);
        }
      }

      // Force refresh to update all screens
      await loadProducts();
      ref.invalidate(productsProvider);
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  Future<void> updateStock(String id, int newStock) async {
    try {
      final tenantId = _validateTenant();

      if (id.isEmpty) {
        throw Exception('ID produk tidak valid');
      }
      if (newStock < 0) {
        throw Exception('Stok tidak boleh negatif');
      }
      if (newStock > 999999) {
        throw Exception('Stok maksimal 999.999');
      }

      final isOnline = await _checkConnectivity();

      if (AppConfig.useSupabase && isOnline) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          final product = await cloudRepo.getProductById(id);
          if (product != null) {
            await cloudRepo.updateProduct(product.copyWith(stock: newStock));
          } else {
            throw Exception('Produk tidak ditemukan');
          }
        } catch (e) {
          // Offline fallback
          if (!kIsWeb) {
            debugPrint('Cloud stock update failed, updating locally: $e');
            final repository = ref.read(productRepositoryProvider);
            final result =
                await repository.updateStock(id, newStock, tenantId: tenantId);
            if (!result.success) {
              throw Exception(result.error ?? 'Gagal memperbarui stok');
            }
            // Queue for sync - get product data for sync
            if (result.data != null) {
              await _queueForSync('update', result.data!);
            }
          } else {
            rethrow;
          }
        }
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result =
            await repository.updateStock(id, newStock, tenantId: tenantId);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal memperbarui stok');
        }
        // Queue for sync when online (Android only)
        if (!kIsWeb && AppConfig.useSupabase && result.data != null) {
          await _queueForSync('update', result.data!);
        }
      }

      // Force refresh to update all screens
      await loadProducts();
      ref.invalidate(productsProvider);
    } catch (e) {
      debugPrint('Error updating stock: $e');
      rethrow;
    }
  }
}
