import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/transaction_helper.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/money.dart';
import '../../core/exceptions/checkout_exception.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/models/transaction.dart' as trans;
import '../../data/models/cart_item.dart';
import '../../features/auth/auth_provider.dart';
import '../recipes/recipes_provider.dart';

/// Helper class for POS checkout operations
/// Implements atomic transactions to prevent race conditions and data inconsistency
class PosCheckoutHelper {
  final ProductRepository productRepo;
  final MaterialRepository materialRepo;
  final TransactionRepository transactionRepo;

  PosCheckoutHelper({
    required this.productRepo,
    required this.materialRepo,
    required this.transactionRepo,
  });

  /// Process checkout with atomic transaction
  /// All operations succeed together or fail together
  Future<CheckoutResult> processCheckout({
    required List<CartItem> cart,
    required AuthState authState,
    required double discount,
    required double tax,
    required String paymentMethod,
    required Map<String, List<RecipeIngredient>> recipes,
    String? shiftId,
    String? discountId,
  }) async {
    try {
      // Validate auth state
      final user = AuthGuard.requireUser(authState);
      final tenant = AuthGuard.requireTenant(authState);

      // Calculate totals using Money class for precision
      final subtotalMoney = cart.fold<Money>(
        Money.zero(),
        (sum, item) => sum + Money(item.total),
      );
      final taxMoney = Money(tax);
      final discountMoney = Money(discount);
      final totalMoney = subtotalMoney + taxMoney - discountMoney;

      // Validate minimum total
      if (totalMoney.amount <= 0) {
        return CheckoutResult.failure(
          'Total transaksi harus lebih dari 0',
        );
      }

      // Validate maximum total (prevent overflow/abuse)
      if (totalMoney.amount > 100000000) {
        // 100 juta
        return CheckoutResult.failure(
          'Total transaksi melebihi batas maksimum (Rp 100.000.000)',
        );
      }

      trans.Transaction? createdTransaction;

      // Execute all operations in a single atomic transaction
      await TransactionHelper.executeInTransaction((txn) async {
        // Step 1: Validate tenant ownership and lock product stocks atomically
        final productStockMap = <String, int>{};
        for (var item in cart) {
          // CRITICAL: Validate tenant ownership
          if (item.product.tenantId != tenant.id) {
            throw CheckoutException(
              'Produk ${item.product.name} tidak valid untuk tenant ini',
              userMessage:
                  'Produk ${item.product.name} tidak valid. Silakan refresh halaman.',
              suggestedAction: CheckoutAction.refreshData,
            );
          }

          productStockMap[item.product.id] =
              (productStockMap[item.product.id] ?? 0) + item.quantity;
        }

        // Decrease all product stocks atomically
        final stockResult = await productRepo.decreaseStockBatch(
          productStockMap,
          txn: txn,
        );

        if (!stockResult.success) {
          throw CheckoutException(
            stockResult.error ?? 'Gagal update stok produk',
            userMessage: 'Stok tidak mencukupi. Silakan refresh dan coba lagi.',
            suggestedAction: CheckoutAction.refreshData,
          );
        }

        // Step 2: Validate and update material stocks
        await _updateMaterialStocks(
          cart: cart,
          recipes: recipes,
          txn: txn,
        );

        // Step 3: Create transaction record
        final itemsList = cart
            .map((item) => trans.TransactionItem(
                  productId: item.product.id,
                  productName: '${item.product.name} (${item.size})',
                  price: item.unitPrice,
                  costPrice: item.product.costPrice,
                  quantity: item.quantity,
                  total: item.total,
                ))
            .toList();

        final transaction = trans.Transaction(
          id: _generateTransactionId(),
          tenantId: tenant.id,
          branchId: user
              .branchId, // Multi-branch support: Associate with user's branch
          userId: user.id,
          shiftId: shiftId,
          discountId: discountId,
          items: itemsList,
          subtotal: subtotalMoney.amount,
          discount: discountMoney.amount,
          tax: taxMoney.amount,
          total: totalMoney.amount,
          paymentMethod: paymentMethod,
          createdAt: DateTime.now(),
        );

        // Insert transaction
        final transactionMap = {
          'id': transaction.id,
          'tenant_id': transaction.tenantId,
          'branch_id': transaction.branchId,
          'user_id': transaction.userId,
          'shift_id': transaction.shiftId,
          'discount_id': transaction.discountId,
          'subtotal': transaction.subtotal,
          'discount': transaction.discount,
          'tax': transaction.tax,
          'total': transaction.total,
          'payment_method': transaction.paymentMethod,
          'created_at': transaction.createdAt.toIso8601String(),
        };
        await txn.insert('transactions', transactionMap);
        createdTransaction = transaction;

        // All operations committed together
      });

      if (createdTransaction == null) {
        return CheckoutResult.failure('Transaksi gagal dibuat');
      }

      return CheckoutResult.success(createdTransaction!);
    } on AuthException catch (e) {
      return CheckoutResult.failure('Error autentikasi: ${e.message}');
    } on CheckoutException catch (e) {
      return CheckoutResult.failure(e.message);
    } catch (e) {
      return CheckoutResult.failure('Checkout gagal: $e');
    }
  }

  /// Update material stocks based on recipes
  Future<void> _updateMaterialStocks({
    required List<CartItem> cart,
    required Map<String, List<RecipeIngredient>> recipes,
    required DatabaseExecutor txn,
  }) async {
    // Calculate total material usage
    final materialUsage = <String, double>{};

    for (var item in cart) {
      final recipe = recipes[item.product.id];
      if (recipe == null) continue;

      for (var ingredient in recipe) {
        final usedAmount = ingredient.quantity * item.quantity;
        materialUsage[ingredient.materialId] =
            (materialUsage[ingredient.materialId] ?? 0) + usedAmount;
      }
    }

    // Update each material stock atomically
    for (var entry in materialUsage.entries) {
      final materialId = entry.key;
      final quantityNeeded = entry.value;

      // Lock and validate material stock
      final results = await txn.rawQuery(
        'SELECT * FROM materials WHERE id = ?',
        [materialId],
      );

      if (results.isEmpty) {
        throw CheckoutException('Bahan baku $materialId tidak ditemukan');
      }

      final currentStock = results.first['stock'] as double;
      if (currentStock < quantityNeeded) {
        final materialName = results.first['name'] as String;
        throw CheckoutException(
          'Stok $materialName tidak mencukupi. '
          'Tersedia: $currentStock, Dibutuhkan: $quantityNeeded',
        );
      }

      // Update stock
      final newStock = currentStock - quantityNeeded;
      await txn.update(
        'materials',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [materialId],
      );
    }
  }

  String _generateTransactionId() {
    return const Uuid().v4();
  }
}

/// Result of checkout operation
class CheckoutResult {
  final trans.Transaction? transaction;
  final String? error;
  final bool success;

  CheckoutResult._({
    this.transaction,
    this.error,
    required this.success,
  });

  factory CheckoutResult.success(trans.Transaction transaction) {
    return CheckoutResult._(
      transaction: transaction,
      success: true,
    );
  }

  factory CheckoutResult.failure(String error) {
    return CheckoutResult._(
      error: error,
      success: false,
    );
  }
}

// CheckoutException is now imported from core/exceptions/checkout_exception.dart
