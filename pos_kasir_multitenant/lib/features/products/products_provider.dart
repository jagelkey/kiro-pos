import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../core/config/app_config.dart';
import '../auth/auth_provider.dart';

export '../auth/auth_provider.dart' show authProvider;

final productRepositoryProvider = Provider((ref) => ProductRepository());
final cloudRepositoryProvider = Provider((ref) => CloudRepository());

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.tenant == null) return [];

  final repository = ref.read(productRepositoryProvider);
  return repository.getProducts(authState.tenant!.id);
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

      List<Product> products;
      if (AppConfig.useSupabase) {
        final cloudRepo = ref.read(cloudRepositoryProvider);
        products = await cloudRepo.getProducts(tenantId,
            branchId: authState.user?.branchId);
      } else {
        final repository = ref.read(productRepositoryProvider);
        products = await repository.getProducts(tenantId);
      }
      state = AsyncValue.data(products);
    } catch (e, stack) {
      debugPrint('Error loading products: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final tenantId = _validateTenant();

      // Ensure product has correct tenantId
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

      if (AppConfig.useSupabase) {
        final cloudRepo = ref.read(cloudRepositoryProvider);
        await cloudRepo.createProduct(productWithTenant);
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result = await repository.createProduct(productWithTenant);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal membuat produk');
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

      if (AppConfig.useSupabase) {
        final cloudRepo = ref.read(cloudRepositoryProvider);
        await cloudRepo.updateProduct(productWithTenant);
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result = await repository.updateProduct(productWithTenant);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal memperbarui produk');
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

      if (AppConfig.useSupabase) {
        final cloudRepo = ref.read(cloudRepositoryProvider);
        await cloudRepo.deleteProduct(id);
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

      if (AppConfig.useSupabase) {
        final cloudRepo = ref.read(cloudRepositoryProvider);
        final product = await cloudRepo.getProductById(id);
        if (product != null) {
          await cloudRepo.updateProduct(product.copyWith(stock: newStock));
        }
      } else {
        final repository = ref.read(productRepositoryProvider);
        final result =
            await repository.updateStock(id, newStock, tenantId: tenantId);
        if (!result.success) {
          throw Exception(result.error ?? 'Gagal memperbarui stok');
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
