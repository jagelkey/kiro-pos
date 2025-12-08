import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/cloud_repository.dart';
import '../../data/models/transaction.dart';
import '../../data/models/product.dart';
import '../../data/models/material.dart' as mat;
import '../../data/mock/mock_data.dart';
import '../../core/config/app_config.dart';
import '../expenses/expenses_provider.dart';
import '../recipes/recipes_provider.dart';

final cloudRepoProvider = Provider((ref) => CloudRepository());

final transactionRepositoryProvider =
    Provider((ref) => TransactionRepository());

final dashboardMaterialRepositoryProvider =
    Provider((ref) => MaterialRepository());

final dashboardProductRepositoryProvider =
    Provider((ref) => ProductRepository());

/// Production capacity info for a product
class ProductionCapacity {
  final Product product;
  final int canProduce;
  final bool isOutOfStock;
  final String? limitingMaterial;

  ProductionCapacity({
    required this.product,
    required this.canProduce,
    required this.isOutOfStock,
    this.limitingMaterial,
  });
}

/// Dashboard data state
/// Multi-tenant aware: All data is filtered by tenant ID
class DashboardData {
  final double todaySales;
  final int todayTransactionCount;
  final double monthExpenses; // Today's expenses for accurate daily profit
  final double todayCostOfGoodsSold; // Harga pokok penjualan hari ini
  final List<Transaction> recentTransactions;
  final List<ProductionCapacity> productionCapacities;
  final int canProduceCount;
  final int outOfStockCount;
  final int lowStockMaterialCount;
  final bool isLoading;
  final String? error;
  final bool isOnline; // Connection status: true = online, false = offline
  final DateTime? lastUpdated; // Timestamp of last successful data sync

  DashboardData({
    this.todaySales = 0,
    this.todayTransactionCount = 0,
    this.monthExpenses = 0,
    this.todayCostOfGoodsSold = 0,
    this.recentTransactions = const [],
    this.productionCapacities = const [],
    this.canProduceCount = 0,
    this.outOfStockCount = 0,
    this.lowStockMaterialCount = 0,
    this.isLoading = false,
    this.error,
    this.isOnline = true,
    this.lastUpdated,
  });

  /// Laba kotor: Penjualan - Harga Pokok Penjualan
  double get grossProfit => todaySales - todayCostOfGoodsSold;

  /// Persentase margin laba kotor (safe division)
  double get grossProfitMarginPercent =>
      todaySales > 0 ? (grossProfit / todaySales) * 100 : 0.0;

  /// Calculate profit: Today's sales minus today's expenses
  /// This provides accurate daily profit calculation
  double get profit => todaySales - monthExpenses;

  /// Check if dashboard has valid data
  bool get hasData => !isLoading && error == null;

  /// Check if there are any transactions today
  bool get hasTransactions => todayTransactionCount > 0;

  DashboardData copyWith({
    double? todaySales,
    int? todayTransactionCount,
    double? monthExpenses,
    double? todayCostOfGoodsSold,
    List<Transaction>? recentTransactions,
    List<ProductionCapacity>? productionCapacities,
    int? canProduceCount,
    int? outOfStockCount,
    int? lowStockMaterialCount,
    bool? isLoading,
    String? error,
    bool? isOnline,
    DateTime? lastUpdated,
  }) {
    return DashboardData(
      todaySales: todaySales ?? this.todaySales,
      todayTransactionCount:
          todayTransactionCount ?? this.todayTransactionCount,
      monthExpenses: monthExpenses ?? this.monthExpenses,
      todayCostOfGoodsSold: todayCostOfGoodsSold ?? this.todayCostOfGoodsSold,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      productionCapacities: productionCapacities ?? this.productionCapacities,
      canProduceCount: canProduceCount ?? this.canProduceCount,
      outOfStockCount: outOfStockCount ?? this.outOfStockCount,
      lowStockMaterialCount:
          lowStockMaterialCount ?? this.lowStockMaterialCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOnline: isOnline ?? this.isOnline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Data source enum for tracking where data came from
enum DataSource {
  supabase,
  sqlite,
  mock,
  none,
}

/// Result of a safe data fetch operation
class SafeFetchResult<T> {
  final T? data;
  final DataSource source;
  final String? error;

  SafeFetchResult({this.data, required this.source, this.error});

  bool get isSuccess => data != null && error == null;
}

class DashboardNotifier extends StateNotifier<DashboardData> {
  final Ref ref;

  DashboardNotifier(this.ref) : super(DashboardData(isLoading: true)) {
    loadDashboardData();
  }

  /// Safe wrapper for fetching transactions from Supabase
  /// Returns empty list on failure without throwing
  Future<List<Transaction>> _safeGetTransactionsFromCloud(
    CloudRepository cloudRepo,
    String tenantId, {
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await cloudRepo.getTransactions(
        tenantId,
        branchId: branchId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Cloud transaction fetch failed: $e');
      return <Transaction>[];
    }
  }

  /// Safe wrapper for fetching expenses from Supabase
  /// Returns 0.0 on failure without throwing
  Future<double> _safeGetExpensesFromCloud(
    CloudRepository cloudRepo,
    String tenantId, {
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final expenses = await cloudRepo.getExpenses(
        tenantId,
        branchId: branchId,
        startDate: startDate,
        endDate: endDate,
      );
      return expenses.fold<double>(0, (sum, e) => sum + e.amount);
    } catch (e) {
      debugPrint('Cloud expense fetch failed: $e');
      return 0.0;
    }
  }

  /// Safe wrapper for fetching materials from Supabase
  /// Returns empty list on failure without throwing
  Future<List<mat.Material>> _safeGetMaterialsFromCloud(
    CloudRepository cloudRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      return await cloudRepo.getMaterials(tenantId, branchId: branchId);
    } catch (e) {
      debugPrint('Cloud material fetch failed: $e');
      return <mat.Material>[];
    }
  }

  /// Safe wrapper for fetching products from Supabase
  /// Returns empty list on failure without throwing
  Future<List<Product>> _safeGetProductsFromCloud(
    CloudRepository cloudRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      return await cloudRepo.getProducts(tenantId, branchId: branchId);
    } catch (e) {
      debugPrint('Cloud product fetch failed: $e');
      return <Product>[];
    }
  }

  /// Safe wrapper for fetching transactions from SQLite
  /// Returns empty list on failure without throwing
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Transaction>> _safeGetTransactionsFromSQLite(
    TransactionRepository transactionRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return await transactionRepo.getTransactionsByDateRange(
        tenantId,
        startOfDay,
        endOfDay,
        branchId: branchId,
      );
    } catch (e) {
      debugPrint('SQLite transaction fetch failed: $e');
      return <Transaction>[];
    }
  }

  /// Safe wrapper for fetching recent transactions from SQLite
  /// Returns empty list on failure without throwing
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Transaction>> _safeGetRecentTransactionsFromSQLite(
    TransactionRepository transactionRepo,
    String tenantId, {
    String? branchId,
    int limit = 5,
  }) async {
    try {
      final transactions =
          await transactionRepo.getTransactions(tenantId, branchId: branchId);
      return transactions.take(limit).toList();
    } catch (e) {
      debugPrint('SQLite recent transaction fetch failed: $e');
      return <Transaction>[];
    }
  }

  /// Safe wrapper for fetching expenses from SQLite
  /// Returns 0.0 on failure without throwing
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<double> _safeGetExpensesFromSQLite(
    dynamic expenseRepo,
    String tenantId,
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    try {
      return await expenseRepo.getTotalExpenses(tenantId, startDate, endDate,
          branchId: branchId);
    } catch (e) {
      debugPrint('SQLite expense fetch failed: $e');
      return 0.0;
    }
  }

  /// Safe wrapper for fetching materials from SQLite
  /// Returns empty list on failure without throwing
  /// Requirements 2.1, 2.2, 2.4: Multi-tenant data isolation with branch filtering
  Future<List<dynamic>> _safeGetMaterialsFromSQLite(
    MaterialRepository materialRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      return await materialRepo.getMaterials(tenantId, branchId: branchId);
    } catch (e) {
      debugPrint('SQLite material fetch failed: $e');
      return [];
    }
  }

  /// Safe wrapper for fetching low stock materials from SQLite
  /// Returns empty list on failure without throwing
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<List<dynamic>> _safeGetLowStockMaterialsFromSQLite(
    MaterialRepository materialRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      return await materialRepo.getLowStockMaterials(tenantId,
          branchId: branchId);
    } catch (e) {
      debugPrint('SQLite low stock material fetch failed: $e');
      return [];
    }
  }

  /// Safe wrapper for fetching products from SQLite
  /// Returns empty list on failure without throwing
  /// Requirements 2.1, 2.2, 2.4: Multi-tenant data isolation with branch filtering
  Future<List<Product>> _safeGetProductsFromSQLite(
    ProductRepository productRepo,
    String tenantId, {
    String? branchId,
  }) async {
    try {
      return await productRepo.getProducts(tenantId, branchId: branchId);
    } catch (e) {
      debugPrint('SQLite product fetch failed: $e');
      return <Product>[];
    }
  }

  /// Get mock data for web platform when other sources fail
  /// Requirements: 3.5
  Map<String, dynamic> _getMockData(String tenantId) {
    final mockTransactions =
        MockData.transactions.where((t) => t.tenantId == tenantId).toList();
    final mockMaterials =
        MockData.materials.where((m) => m.tenantId == tenantId).toList();
    final mockProducts =
        MockData.products.where((p) => p.tenantId == tenantId).toList();
    final mockExpenses =
        MockData.expenses.where((e) => e.tenantId == tenantId).toList();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final todayTransactions = mockTransactions.where((t) {
      return !t.createdAt.isBefore(startOfDay) &&
          !t.createdAt.isAfter(endOfDay);
    }).toList();

    final todayExpenses = mockExpenses.where((e) {
      return !e.date.isBefore(startOfDay) && !e.date.isAfter(endOfDay);
    }).fold<double>(0, (sum, e) => sum + e.amount);

    final lowStockMaterials = mockMaterials
        .where((m) => m.minStock != null && m.stock <= m.minStock!)
        .toList();

    return {
      'todayTransactions': todayTransactions,
      'todayExpenses': todayExpenses,
      'recentTransactions': mockTransactions.take(5).toList(),
      'materials': mockMaterials,
      'lowStockMaterials': lowStockMaterials,
      'products': mockProducts,
    };
  }

  /// Load dashboard data with fallback chain: Supabase → SQLite → Mock Data
  /// Requirements: 1.2, 1.4, 1.5, 3.2, 4.5
  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authState = ref.read(authProvider);

      // Tenant validation (Requirements 1.4, 1.5)
      if (authState.tenant == null) {
        // Return empty state when no tenant - prevents null errors
        state = DashboardData(isLoading: false, isOnline: false);
        return;
      }

      final tenantId = authState.tenant!.id;

      // Validate tenantId is not empty (Requirement 1.5)
      if (tenantId.isEmpty) {
        state = DashboardData(
          isLoading: false,
          error: 'Tenant ID tidak valid',
          isOnline: false,
        );
        return;
      }

      final transactionRepo = ref.read(transactionRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final materialRepo = ref.read(dashboardMaterialRepositoryProvider);
      final productRepo = ref.read(dashboardProductRepositoryProvider);
      final cloudRepo = ref.read(cloudRepoProvider);
      final branchId = authState.user?.branchId;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      // Track data source and online status
      bool isOnline = false;
      DataSource dataSource = DataSource.none;

      List<Transaction> todayTransactions = [];
      double todayExpenses = 0.0;
      List<Transaction> recentTransactions = [];
      List<dynamic> materials = [];
      List<dynamic> lowStockMaterials = [];
      List<Product> products = [];

      // Fallback chain: Supabase → SQLite → Mock Data
      // Requirements: 3.2, 4.5

      if (AppConfig.useSupabase) {
        // Try Supabase first
        try {
          final results = await Future.wait([
            _safeGetTransactionsFromCloud(
              cloudRepo,
              tenantId,
              branchId: branchId,
              startDate: startOfDay,
              endDate: endOfDay,
            ),
            _safeGetExpensesFromCloud(
              cloudRepo,
              tenantId,
              branchId: branchId,
              startDate: startOfDay,
              endDate: endOfDay,
            ),
            _safeGetTransactionsFromCloud(cloudRepo, tenantId,
                    branchId: branchId)
                .then((list) => list.take(5).toList()),
            _safeGetMaterialsFromCloud(cloudRepo, tenantId, branchId: branchId),
            _safeGetMaterialsFromCloud(cloudRepo, tenantId, branchId: branchId)
                .then((list) => list
                    .where((m) => m.minStock != null && m.stock <= m.minStock!)
                    .toList()),
            _safeGetProductsFromCloud(cloudRepo, tenantId, branchId: branchId),
          ]);

          todayTransactions = results[0] as List<Transaction>;
          todayExpenses = results[1] as double;
          recentTransactions = results[2] as List<Transaction>;
          materials = results[3] as List<mat.Material>;
          lowStockMaterials = results[4] as List<mat.Material>;
          products = results[5] as List<Product>;

          // Check if we got valid data from Supabase
          if (todayTransactions.isNotEmpty ||
              materials.isNotEmpty ||
              products.isNotEmpty) {
            isOnline = true;
            dataSource = DataSource.supabase;
          }
        } catch (e) {
          debugPrint('Supabase fetch failed, falling back to SQLite: $e');
        }
      }

      // Fallback to SQLite if Supabase failed or not enabled (and not web)
      // Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
      if (dataSource == DataSource.none && !kIsWeb) {
        try {
          final results = await Future.wait([
            _safeGetTransactionsFromSQLite(transactionRepo, tenantId,
                branchId: branchId),
            _safeGetExpensesFromSQLite(
                expenseRepo, tenantId, startOfDay, endOfDay,
                branchId: branchId),
            _safeGetRecentTransactionsFromSQLite(transactionRepo, tenantId,
                branchId: branchId, limit: 5),
            _safeGetMaterialsFromSQLite(materialRepo, tenantId,
                branchId: branchId),
            _safeGetLowStockMaterialsFromSQLite(materialRepo, tenantId,
                branchId: branchId),
            _safeGetProductsFromSQLite(productRepo, tenantId,
                branchId: branchId),
          ]);

          todayTransactions = results[0] as List<Transaction>;
          todayExpenses = results[1] as double;
          recentTransactions = results[2] as List<Transaction>;
          materials = results[3] as List<dynamic>;
          lowStockMaterials = results[4] as List<dynamic>;
          products = results[5] as List<Product>;

          dataSource = DataSource.sqlite;
          isOnline = false;
        } catch (e) {
          debugPrint('SQLite fetch failed, falling back to mock data: $e');
        }
      }

      // Fallback to mock data for web or if all else fails
      // Requirement 3.5
      if (dataSource == DataSource.none) {
        final mockData = _getMockData(tenantId);
        todayTransactions = mockData['todayTransactions'] as List<Transaction>;
        todayExpenses = mockData['todayExpenses'] as double;
        recentTransactions =
            mockData['recentTransactions'] as List<Transaction>;
        materials = mockData['materials'] as List<dynamic>;
        lowStockMaterials = mockData['lowStockMaterials'] as List<dynamic>;
        products = mockData['products'] as List<Product>;

        dataSource = DataSource.mock;
        isOnline = false;
      }

      // Get recipes for multi-tenant support with safe access
      Map<String, List<RecipeIngredient>> recipes = {};
      try {
        recipes = ref.read(recipeNotifierProvider).valueOrNull ?? {};
      } catch (e) {
        // Recipes not available, continue without them
        debugPrint('Recipe fetch failed: $e');
        recipes = {};
      }

      // Calculate today's sales from actual transactions (Requirements 8.1)
      final todaySales = todayTransactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.total,
      );

      // Calculate today's cost of goods sold (HPP)
      final todayCostOfGoodsSold = todayTransactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.totalCostPrice,
      );

      // Get transaction count from actual database records (Requirements 8.2)
      final todayTransactionCount = todayTransactions.length;

      // Calculate production capacity for each product with recipes
      // Requirements 8.4: Show correct "can produce" vs "out of stock" counts
      final productionCapacities = <ProductionCapacity>[];
      int canProduceCount = 0;
      int outOfStockCount = 0;

      for (final product in products) {
        try {
          final capacity =
              _calculateProductionCapacity(product, materials, recipes);
          productionCapacities.add(capacity);

          // Only count products that have recipes defined
          // canProduce == -1 means no recipe (skip counting)
          if (capacity.canProduce >= 0) {
            if (capacity.isOutOfStock) {
              outOfStockCount++;
            } else {
              canProduceCount++;
            }
          }
        } catch (e) {
          // Skip products that fail capacity calculation
          debugPrint('Capacity calculation failed for ${product.name}: $e');
          continue;
        }
      }

      state = DashboardData(
        todaySales: todaySales,
        todayTransactionCount: todayTransactionCount,
        monthExpenses: todayExpenses,
        todayCostOfGoodsSold: todayCostOfGoodsSold,
        recentTransactions: recentTransactions,
        productionCapacities: productionCapacities,
        canProduceCount: canProduceCount,
        outOfStockCount: outOfStockCount,
        lowStockMaterialCount: lowStockMaterials.length,
        isLoading: false,
        isOnline: isOnline,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      state = DashboardData(
        isLoading: false,
        error: 'Terjadi kesalahan: $e',
        isOnline: false,
      );
    }
  }

  /// Calculate production capacity for a product based on material stock and recipe
  /// Requirements 8.4, 3.5: Calculate based on material stock and recipes (multi-tenant)
  ProductionCapacity _calculateProductionCapacity(Product product,
      List materials, Map<String, List<RecipeIngredient>> recipes) {
    try {
      final recipe = recipes[product.id];

      // If no recipe, product doesn't require materials - can always produce
      // (e.g., pre-made items or items without recipe defined)
      if (recipe == null || recipe.isEmpty) {
        return ProductionCapacity(
          product: product,
          canProduce:
              -1, // -1 indicates no recipe/unlimited production capacity
          isOutOfStock: false,
        );
      }

      // Calculate minimum production capacity based on materials
      // The capacity is limited by the material with the lowest availability
      int minCapacity = 999999;
      String? limitingMaterial;

      for (final ingredient in recipe) {
        // Find material by ID using safe iteration
        dynamic foundMaterial;
        for (final m in materials) {
          try {
            if (m.id == ingredient.materialId) {
              foundMaterial = m;
              break;
            }
          } catch (e) {
            // Skip invalid material entries
            continue;
          }
        }

        if (foundMaterial == null) {
          // Material required but not found in inventory
          minCapacity = 0;
          limitingMaterial = ingredient.name;
          break;
        }

        // Safely get material stock with null check and type conversion
        double materialStock = 0.0;
        try {
          final stockValue = foundMaterial.stock;
          if (stockValue != null) {
            materialStock = (stockValue is num) ? stockValue.toDouble() : 0.0;
          }
        } catch (e) {
          materialStock = 0.0;
        }

        final requiredPerUnit = ingredient.quantity;

        // Prevent division by zero
        if (requiredPerUnit > 0) {
          // Calculate how many units can be produced with available material
          final capacity = (materialStock / requiredPerUnit).floor();
          if (capacity < minCapacity) {
            minCapacity = capacity;
            // Safely get material name
            try {
              limitingMaterial = foundMaterial.name?.toString() ?? 'Unknown';
            } catch (e) {
              limitingMaterial = 'Unknown';
            }
          }
        }
      }

      // If no valid capacity was calculated, set to 0
      final finalCapacity = minCapacity == 999999 ? 0 : minCapacity;

      return ProductionCapacity(
        product: product,
        canProduce: finalCapacity,
        isOutOfStock: finalCapacity <= 0,
        limitingMaterial: limitingMaterial,
      );
    } catch (e) {
      // Return safe default on any error
      debugPrint('Production capacity calculation error: $e');
      return ProductionCapacity(
        product: product,
        canProduce: -1,
        isOutOfStock: false,
      );
    }
  }

  void refresh() => loadDashboardData();
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardData>((ref) {
  return DashboardNotifier(ref);
});
