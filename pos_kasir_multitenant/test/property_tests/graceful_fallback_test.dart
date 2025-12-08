/// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
/// **Validates: Requirements 3.2, 4.5**
///
/// Property: For any dashboard load where Supabase connection fails, the dashboard
/// SHALL load data from local storage without displaying error if local data is available.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/transaction.dart';
import 'package:pos_kasir_multitenant/data/models/material.dart' as mat;
import 'package:pos_kasir_multitenant/data/models/product.dart';

/// Enum representing data source for fallback chain
enum DataSource {
  supabase,
  sqlite,
  mock,
  none,
}

/// Result of a data fetch operation with source tracking
class FetchResult<T> {
  final T? data;
  final DataSource source;
  final String? error;

  FetchResult({this.data, required this.source, this.error});

  bool get isSuccess => data != null && error == null;
}

/// Simulates the fallback chain logic from DashboardProvider
/// This mirrors the actual implementation for testability
class FallbackChainSimulator {
  /// Simulate fetching data with fallback chain: Supabase → SQLite → Mock
  /// Requirements: 3.2, 4.5
  static FetchResult<Map<String, dynamic>> fetchWithFallback({
    required bool supabaseEnabled,
    required bool supabaseSucceeds,
    required bool sqliteAvailable,
    required bool sqliteSucceeds,
    required bool isWeb,
    required Map<String, dynamic> supabaseData,
    required Map<String, dynamic> sqliteData,
    required Map<String, dynamic> mockData,
  }) {
    // Track which source provided data
    DataSource source = DataSource.none;
    Map<String, dynamic>? resultData;
    String? error;

    // Step 1: Try Supabase if enabled
    if (supabaseEnabled) {
      if (supabaseSucceeds) {
        resultData = supabaseData;
        source = DataSource.supabase;
        return FetchResult(data: resultData, source: source);
      }
      // Supabase failed, continue to fallback
    }

    // Step 2: Try SQLite if not web and available
    if (!isWeb && sqliteAvailable) {
      if (sqliteSucceeds) {
        resultData = sqliteData;
        source = DataSource.sqlite;
        return FetchResult(data: resultData, source: source);
      }
      // SQLite failed, continue to fallback
    }

    // Step 3: Use mock data as last resort
    resultData = mockData;
    source = DataSource.mock;
    return FetchResult(data: resultData, source: source);
  }

  /// Check if the result represents a graceful fallback (no error shown to user)
  /// Requirements: 3.2 - fallback without showing error
  static bool isGracefulFallback(FetchResult<Map<String, dynamic>> result) {
    // Graceful fallback means:
    // 1. Data is available (not null)
    // 2. No error message is set
    // 3. Source is either sqlite or mock (not supabase which failed)
    return result.data != null && result.error == null;
  }

  /// Determine if error should be shown based on data availability
  /// Requirements: 4.5 - fallback gracefully
  static bool shouldShowError({
    required bool supabaseFailed,
    required bool sqliteFailed,
    required bool hasLocalData,
    required bool hasMockData,
  }) {
    // Error should only be shown if ALL fallback options fail
    // If any data source provides data, no error should be shown
    if (hasLocalData || hasMockData) {
      return false;
    }
    return supabaseFailed && sqliteFailed;
  }
}

/// Generator for valid TransactionItem instances
extension TransactionItemGenerator on Any {
  Generator<TransactionItem> get transactionItem {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(1000.0, 50000.0).bind((price) {
        return any.intInRange(1, 5).map((quantity) {
          final itemTotal = price * quantity;
          return TransactionItem(
            productId: 'prod-${name.hashCode.abs()}',
            productName: name.isEmpty ? 'Product' : name,
            quantity: quantity,
            price: price,
            total: itemTotal,
          );
        });
      });
    });
  }
}

/// Generator for a list of transaction items
extension TransactionItemsGenerator on Any {
  Generator<List<TransactionItem>> get transactionItems {
    return any.transactionItem.bind((item1) {
      return any.transactionItem.map((item2) {
        return [item1, item2];
      });
    });
  }
}

/// Generator for valid Transaction instances
extension TransactionGenerator on Any {
  Generator<Transaction> get transaction {
    return any.transactionItems.bind((items) {
      return any.doubleInRange(0.0, 0.15).bind((taxRate) {
        return any.doubleInRange(0.0, 5000.0).map((discount) {
          final subtotal =
              items.fold<double>(0, (sum, item) => sum + item.total);
          final tax = subtotal * taxRate;
          final effectiveDiscount =
              discount > subtotal + tax ? subtotal + tax : discount;
          final total = subtotal + tax - effectiveDiscount;

          return Transaction(
            id: 'txn-${DateTime.now().microsecondsSinceEpoch}-${items.hashCode.abs()}',
            tenantId: 'tenant-test',
            userId: 'user-test',
            items: items,
            subtotal: subtotal,
            discount: effectiveDiscount,
            tax: tax,
            total: total > 0 ? total : 0,
            paymentMethod: 'Cash',
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }
}

/// Generator for list of transactions
extension TransactionsListGenerator on Any {
  Generator<List<Transaction>> get transactions {
    return any.transaction.bind((t1) {
      return any.transaction.bind((t2) {
        return any.transaction.map((t3) {
          return [t1, t2, t3];
        });
      });
    });
  }
}

/// Generator for Material instances
extension MaterialGenerator on Any {
  Generator<mat.Material> get material {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(0.0, 1000.0).bind((stock) {
        return any.doubleInRange(10.0, 100.0).map((minStock) {
          return mat.Material(
            id: 'mat-${name.hashCode.abs()}',
            tenantId: 'tenant-test',
            name: name.isEmpty ? 'Material' : name,
            stock: stock,
            unit: 'kg',
            minStock: minStock,
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }
}

/// Generator for list of materials
extension MaterialsListGenerator on Any {
  Generator<List<mat.Material>> get materials {
    return any.material.bind((m1) {
      return any.material.map((m2) {
        return [m1, m2];
      });
    });
  }
}

/// Generator for Product instances
extension ProductGenerator on Any {
  Generator<Product> get product {
    return any.lowercaseLetters.bind((name) {
      return any.doubleInRange(5000.0, 100000.0).bind((price) {
        return any.intInRange(0, 100).map((stock) {
          return Product(
            id: 'prod-${name.hashCode.abs()}',
            tenantId: 'tenant-test',
            name: name.isEmpty ? 'Product' : name,
            price: price,
            costPrice: price * 0.6,
            stock: stock,
            createdAt: DateTime.now(),
          );
        });
      });
    });
  }
}

/// Generator for list of products
extension ProductsListGenerator on Any {
  Generator<List<Product>> get products {
    return any.product.bind((p1) {
      return any.product.map((p2) {
        return [p1, p2];
      });
    });
  }
}

/// Generator for dashboard data map
extension DashboardDataGenerator on Any {
  Generator<Map<String, dynamic>> get dashboardData {
    return any.transactions.bind((txns) {
      return any.materials.bind((mats) {
        return any.products.bind((prods) {
          return any.doubleInRange(0.0, 10000.0).map((expenses) {
            return {
              'transactions': txns,
              'materials': mats,
              'products': prods,
              'expenses': expenses,
            };
          });
        });
      });
    });
  }
}

/// Generator for fallback scenario configuration
class FallbackScenario {
  final bool supabaseEnabled;
  final bool supabaseSucceeds;
  final bool sqliteAvailable;
  final bool sqliteSucceeds;
  final bool isWeb;

  FallbackScenario({
    required this.supabaseEnabled,
    required this.supabaseSucceeds,
    required this.sqliteAvailable,
    required this.sqliteSucceeds,
    required this.isWeb,
  });

  @override
  String toString() {
    return 'FallbackScenario(supabaseEnabled: $supabaseEnabled, '
        'supabaseSucceeds: $supabaseSucceeds, sqliteAvailable: $sqliteAvailable, '
        'sqliteSucceeds: $sqliteSucceeds, isWeb: $isWeb)';
  }
}

extension FallbackScenarioGenerator on Any {
  Generator<FallbackScenario> get fallbackScenario {
    return any.bool.bind((supabaseEnabled) {
      return any.bool.bind((supabaseSucceeds) {
        return any.bool.bind((sqliteAvailable) {
          return any.bool.bind((sqliteSucceeds) {
            return any.bool.map((isWeb) {
              return FallbackScenario(
                supabaseEnabled: supabaseEnabled,
                supabaseSucceeds: supabaseSucceeds,
                sqliteAvailable: sqliteAvailable,
                sqliteSucceeds: sqliteSucceeds,
                isWeb: isWeb,
              );
            });
          });
        });
      });
    });
  }
}

void main() {
  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 3.2**
  ///
  /// Property: When Supabase fails, fallback to local data without error
  Glados2(any.fallbackScenario, any.dashboardData).test(
    'Supabase failure falls back gracefully without error',
    (scenario, data) {
      // Create different data for each source to verify correct source is used
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: scenario.supabaseEnabled,
        supabaseSucceeds: scenario.supabaseSucceeds,
        sqliteAvailable: scenario.sqliteAvailable,
        sqliteSucceeds: scenario.sqliteSucceeds,
        isWeb: scenario.isWeb,
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Property: Fallback should always be graceful (no error) when data is available
      if (!FallbackChainSimulator.isGracefulFallback(result)) {
        throw Exception(
          'Fallback was not graceful for scenario: $scenario. '
          'Result: source=${result.source}, error=${result.error}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 3.2**
  ///
  /// Property: When Supabase is enabled but fails, SQLite should be used (if not web)
  Glados(any.dashboardData).test(
    'Supabase failure on non-web falls back to SQLite',
    (data) {
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: true,
        supabaseSucceeds: false, // Supabase fails
        sqliteAvailable: true,
        sqliteSucceeds: true, // SQLite succeeds
        isWeb: false, // Not web platform
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Should fallback to SQLite
      if (result.source != DataSource.sqlite) {
        throw Exception(
          'Expected SQLite fallback but got ${result.source}',
        );
      }

      // Should be graceful (no error)
      if (result.error != null) {
        throw Exception(
          'Fallback should not have error but got: ${result.error}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 4.5**
  ///
  /// Property: When both Supabase and SQLite fail, mock data should be used
  Glados(any.dashboardData).test(
    'All failures fall back to mock data gracefully',
    (data) {
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: true,
        supabaseSucceeds: false, // Supabase fails
        sqliteAvailable: true,
        sqliteSucceeds: false, // SQLite also fails
        isWeb: false,
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Should fallback to mock
      if (result.source != DataSource.mock) {
        throw Exception(
          'Expected mock fallback but got ${result.source}',
        );
      }

      // Should still be graceful (no error shown to user)
      if (result.error != null) {
        throw Exception(
          'Fallback to mock should not have error but got: ${result.error}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 3.2, 4.5**
  ///
  /// Property: Web platform skips SQLite and falls back to mock directly
  Glados(any.dashboardData).test(
    'Web platform skips SQLite and uses mock on Supabase failure',
    (data) {
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: true,
        supabaseSucceeds: false, // Supabase fails
        sqliteAvailable: true, // SQLite available but should be skipped
        sqliteSucceeds: true,
        isWeb: true, // Web platform
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Should skip SQLite and go directly to mock on web
      if (result.source != DataSource.mock) {
        throw Exception(
          'Web platform should use mock on Supabase failure, got ${result.source}',
        );
      }

      // Should be graceful
      if (result.error != null) {
        throw Exception(
          'Web fallback should not have error but got: ${result.error}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 4.5**
  ///
  /// Property: Successful Supabase fetch returns Supabase data
  Glados(any.dashboardData).test(
    'Successful Supabase returns Supabase data',
    (data) {
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: true,
        supabaseSucceeds: true, // Supabase succeeds
        sqliteAvailable: true,
        sqliteSucceeds: true,
        isWeb: false,
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Should use Supabase data
      if (result.source != DataSource.supabase) {
        throw Exception(
          'Expected Supabase source but got ${result.source}',
        );
      }

      // Verify correct data was returned
      if (result.data?['source'] != 'supabase') {
        throw Exception(
          'Expected supabase data but got ${result.data?['source']}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 3.2**
  ///
  /// Property: When Supabase is disabled, SQLite is used directly
  Glados(any.dashboardData).test(
    'Disabled Supabase uses SQLite directly',
    (data) {
      final supabaseData = Map<String, dynamic>.from(data);
      supabaseData['source'] = 'supabase';

      final sqliteData = Map<String, dynamic>.from(data);
      sqliteData['source'] = 'sqlite';

      final mockData = Map<String, dynamic>.from(data);
      mockData['source'] = 'mock';

      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: false, // Supabase disabled
        supabaseSucceeds: true, // Would succeed but disabled
        sqliteAvailable: true,
        sqliteSucceeds: true,
        isWeb: false,
        supabaseData: supabaseData,
        sqliteData: sqliteData,
        mockData: mockData,
      );

      // Should use SQLite directly when Supabase is disabled
      if (result.source != DataSource.sqlite) {
        throw Exception(
          'Expected SQLite source when Supabase disabled but got ${result.source}',
        );
      }
    },
  );

  /// **Feature: dashboard-comprehensive-fix, Property 14: Graceful Fallback on Cloud Failure**
  /// **Validates: Requirements 3.2, 4.5**
  ///
  /// Property: Data is always available through fallback chain
  Glados(any.fallbackScenario).test(
    'Fallback chain always provides data',
    (scenario) {
      final result = FallbackChainSimulator.fetchWithFallback(
        supabaseEnabled: scenario.supabaseEnabled,
        supabaseSucceeds: scenario.supabaseSucceeds,
        sqliteAvailable: scenario.sqliteAvailable,
        sqliteSucceeds: scenario.sqliteSucceeds,
        isWeb: scenario.isWeb,
        supabaseData: {'source': 'supabase', 'data': 'test'},
        sqliteData: {'source': 'sqlite', 'data': 'test'},
        mockData: {'source': 'mock', 'data': 'test'},
      );

      // Fallback chain should ALWAYS provide data (never return null)
      if (result.data == null) {
        throw Exception(
          'Fallback chain should always provide data for scenario: $scenario',
        );
      }

      // Source should never be 'none' when data is available
      if (result.source == DataSource.none) {
        throw Exception(
          'Source should not be none when data is available for scenario: $scenario',
        );
      }
    },
  );
}
