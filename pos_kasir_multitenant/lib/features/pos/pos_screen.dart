import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/exceptions/checkout_exception.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/services/receipt_printer.dart';
import '../../data/models/product.dart';
import '../../data/models/discount.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/transaction.dart' as trans;
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/material_repository.dart';
import '../../data/repositories/discount_repository.dart';
import '../../core/services/sync_manager.dart';
import '../products/products_provider.dart'; // Also exports authProvider
import '../recipes/recipes_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../shift/shift_provider.dart'; // Requirements 13.5: Shift integration
import 'cart_persistence.dart';
import 'pos_checkout_helper.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
    (ref) => CartNotifier(ref));

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref _ref;

  CartNotifier(this._ref) : super([]) {
    _loadPersistedCart();
  }

  /// Load cart from persistent storage
  Future<void> _loadPersistedCart() async {
    try {
      final authState = _ref.read(authProvider);
      if (authState.tenant == null) return;

      final productRepo = _ref.read(productRepositoryProvider);
      final cart = await CartPersistence.loadCart(
        productRepo,
        authState.tenant!.id,
      );
      state = cart;
    } catch (e) {
      debugPrint('Error loading persisted cart: $e');
    }
  }

  /// Persist cart to storage
  Future<void> _persistCart() async {
    try {
      final authState = _ref.read(authProvider);
      if (authState.tenant == null) return;

      await CartPersistence.saveCart(state, authState.tenant!.id);
    } catch (e) {
      debugPrint('Error persisting cart: $e');
    }
  }

  void addItem(Product product,
      {String size = 'Regular', String temp = 'Normal'}) {
    double extra = size == 'Large' ? 5000 : 0;
    final existingIndex = state.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.size == size &&
          item.temperature == temp,
    );

    // Calculate total quantity of this product in cart
    final currentQtyInCart = state
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);

    // Validate against available stock
    if (currentQtyInCart >= product.stock) {
      return; // Don't add if exceeds stock
    }

    if (existingIndex >= 0) {
      // Check if adding one more would exceed stock
      if (state[existingIndex].quantity >= product.stock) {
        return;
      }
      final newList = List<CartItem>.from(state);
      newList[existingIndex] = state[existingIndex]
          .copyWith(quantity: state[existingIndex].quantity + 1);
      state = newList;
    } else {
      state = [
        ...state,
        CartItem(
            product: product, size: size, temperature: temp, extraPrice: extra)
      ];
    }
    _persistCart();
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.length) return;
    final newList = List<CartItem>.from(state);
    newList.removeAt(index);
    state = newList;
    _persistCart();
  }

  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= state.length) return;

    if (quantity <= 0) {
      removeItem(index);
      return;
    }

    // Validate against available stock
    final item = state[index];
    if (quantity > item.product.stock) {
      quantity = item.product.stock; // Cap at available stock
    }

    final newList = List<CartItem>.from(state);
    newList[index] = item.copyWith(quantity: quantity);
    state = newList;
    _persistCart();
  }

  void clear() {
    state = [];
    CartPersistence.clearCart();
  }

  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);

  /// Remove items from cart if their products no longer exist
  /// Returns list of removed product names for notification
  List<String> removeDeletedProducts(List<Product> availableProducts) {
    final availableProductIds = availableProducts.map((p) => p.id).toSet();
    final removedProducts = <String>[];

    final newState = state.where((item) {
      if (!availableProductIds.contains(item.product.id)) {
        removedProducts.add(item.product.name);
        return false;
      }
      return true;
    }).toList();

    // Only update state if something was removed
    if (newState.length != state.length) {
      state = newState;
      _persistCart();
    }

    return removedProducts;
  }

  /// Update product data in cart items (for price/stock changes)
  /// Returns list of updated product names for notification
  List<String> updateProductData(List<Product> availableProducts) {
    final productMap = {for (var p in availableProducts) p.id: p};
    final updatedProducts = <String>[];
    final newState = <CartItem>[];

    for (var item in state) {
      final updatedProduct = productMap[item.product.id];
      if (updatedProduct != null) {
        // Check if product data changed
        if (updatedProduct.price != item.product.price ||
            updatedProduct.stock != item.product.stock ||
            updatedProduct.name != item.product.name) {
          updatedProducts.add(updatedProduct.name);
          // Update cart item with new product data
          newState.add(item.copyWith(product: updatedProduct));
        } else {
          newState.add(item);
        }
      }
      // If product doesn't exist, it will be filtered out (deleted product)
    }

    if (updatedProducts.isNotEmpty || newState.length != state.length) {
      state = newState;
      _persistCart();
    }

    return updatedProducts;
  }
}

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final taxEnabledProvider = StateProvider<bool>((ref) => true);

// Repository providers for POS
final posTransactionRepositoryProvider =
    Provider((ref) => TransactionRepository());
final posMaterialRepositoryProvider = Provider((ref) => MaterialRepository());
final posDiscountRepositoryProvider = Provider((ref) => DiscountRepository());

// Provider for active discounts in POS
final posActiveDiscountsProvider =
    FutureProvider.autoDispose<List<Discount>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.user == null) return [];
  final repo = ref.read(posDiscountRepositoryProvider);
  return repo.getActiveDiscounts(authState.user!.tenantId);
});

// Provider for selected discount
final selectedDiscountProvider = StateProvider<Discount?>((ref) => null);

// Provider for sync manager
final syncManagerProvider = Provider((ref) => SyncManager.instance);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  double _discount = 0;
  double _cashReceived = 0;
  String _paymentMethod = 'cash';
  String? _lastTenantId;
  bool _isRefreshing = false;
  final bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    // Store initial tenant ID for change detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      _lastTenantId = authState.tenant?.id;
    });
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  /// Refresh all POS data
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(productProvider.notifier).loadProducts();
      ref.invalidate(posActiveDiscountsProvider);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Clear cart and discount when tenant changes (multi-tenant data isolation)
  void _checkTenantChange() {
    final authState = ref.read(authProvider);
    final currentTenantId = authState.tenant?.id;

    if (_lastTenantId != null && currentTenantId != _lastTenantId) {
      // Tenant changed - clear cart and discount to prevent data leakage
      ref.read(cartProvider.notifier).clear();
      ref.read(selectedDiscountProvider.notifier).state = null;
      _discount = 0;
      _cashReceived = 0;
      _paymentMethod = 'cash';
    }
    _lastTenantId = currentTenantId;
  }

  @override
  Widget build(BuildContext context) {
    // Check for tenant change on every build
    _checkTenantChange();
    final cart = ref.watch(cartProvider);
    final productsAsync = ref.watch(productProvider);
    final totalItems = ref.watch(cartProvider.notifier).totalItems;
    final screenWidth = MediaQuery.of(context).size.width;

    // Clean up cart when products change (remove deleted products, update product data)
    productsAsync.whenData((products) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final cartNotifier = ref.read(cartProvider.notifier);
        final updatedProducts = cartNotifier.updateProductData(products);

        // Show notification if products were updated or removed
        if (updatedProducts.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updatedProducts.length == 1
                    ? 'Produk "${updatedProducts.first}" di keranjang telah diperbarui'
                    : '${updatedProducts.length} produk di keranjang telah diperbarui',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    });

    // Responsive breakpoints
    final isDesktop = screenWidth >= 1100;
    final isTablet = screenWidth >= 700 && screenWidth < 1100;
    final isMobile = screenWidth < 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('☕ POS Kasir'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          if (isTablet || isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildCartSummaryChip(cart, totalItems),
            ),
        ],
      ),
      body: productsAsync.when(
        data: (products) => RefreshIndicator(
          onRefresh: _refreshData,
          child: _buildResponsiveBody(
              products, cart, isDesktop, isTablet, isMobile),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorWidget(e),
      ),
      // Floating cart button for mobile
      floatingActionButton:
          isMobile ? _buildFloatingCartButton(cart, totalItems) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCartSummaryChip(List<CartItem> cart, int totalItems) {
    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_cart, size: 16),
          const SizedBox(width: 4),
          Text('$totalItems',
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          if (subtotal > 0) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(_formatCurrency(subtotal),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingCartButton(List<CartItem> cart, int totalItems) {
    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    if (cart.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: FloatingActionButton.extended(
        onPressed: () => _showCartBottomSheet(),
        backgroundColor: AppTheme.primaryColor,
        icon: Badge(
          label: Text('$totalItems'),
          child: const Icon(Icons.shopping_cart),
        ),
        label: Text(_formatCurrency(subtotal)),
      ),
    );
  }

  Widget _buildResponsiveBody(List<Product> products, List<CartItem> cart,
      bool isDesktop, bool isTablet, bool isMobile) {
    if (isDesktop) {
      // Desktop: Products (60%) + Cart (40%)
      return Row(
        children: [
          Expanded(
              flex: 3,
              child: _ProductSection(products: products, crossAxisCount: 4)),
          Container(
              width: 400,
              decoration: _cartDecoration(),
              child: _CartPanel(
                  discount: _discount,
                  onDiscountChanged: (v) => setState(() => _discount = v),
                  onCheckout: _checkout,
                  onClearCart: () => setState(() => _discount = 0))),
        ],
      );
    } else if (isTablet) {
      // Tablet: Products (55%) + Cart (45%)
      return Row(
        children: [
          Expanded(
              flex: 11,
              child: _ProductSection(products: products, crossAxisCount: 3)),
          Container(
              width: 320,
              decoration: _cartDecoration(),
              child: _CartPanel(
                  discount: _discount,
                  onDiscountChanged: (v) => setState(() => _discount = v),
                  onCheckout: _checkout,
                  onClearCart: () => setState(() => _discount = 0))),
        ],
      );
    } else {
      // Mobile: Full screen products, cart in bottom sheet
      return _ProductSection(
          products: products, crossAxisCount: 2, bottomPadding: 80);
    }
  }

  BoxDecoration _cartDecoration() => const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(left: BorderSide(color: AppTheme.borderColor)),
      );

  Widget _buildErrorWidget(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $e'),
          ElevatedButton(
              onPressed: () =>
                  ref.read(productProvider.notifier).loadProducts(),
              child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (bottomSheetContext) => Consumer(
        builder: (context, ref, _) {
          // Watch cart here to ensure bottom sheet rebuilds when cart changes
          // ignore: unused_local_variable
          final cart = ref.watch(cartProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: _CartPanel(
                discount: _discount,
                onDiscountChanged: (v) => setState(() => _discount = v),
                onCheckout: () {
                  Navigator.pop(bottomSheetContext);
                  _checkout();
                },
                onClearCart: () {
                  setState(() => _discount = 0);
                  Navigator.pop(
                      bottomSheetContext); // Close bottom sheet after clearing
                },
                scrollController: scrollController,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final authState = ref.read(authProvider);
    if (authState.user == null || authState.tenant == null) return;

    // Requirements 13.5: Warn if no active shift (optional - allow transaction but warn)
    final activeShift = ref.read(activeShiftProvider).value;
    if (activeShift == null) {
      final proceedWithoutShift = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tidak Ada Shift Aktif',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'Anda belum memulai shift. Transaksi akan dicatat tanpa asosiasi shift.\n\nApakah Anda ingin melanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );
      if (proceedWithoutShift != true) return;
    }

    final taxEnabled = ref.read(taxEnabledProvider);
    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    final taxRate = taxEnabled ? authState.tenant!.taxRate : 0.0;
    final tax = subtotal * taxRate;

    // Requirements 14.2, 14.3: Calculate discount from selected discount or manual input
    final selectedDiscount = ref.read(selectedDiscountProvider);
    double calculatedDiscount = _discount;
    if (selectedDiscount != null &&
        selectedDiscount.meetsMinPurchase(subtotal)) {
      calculatedDiscount = selectedDiscount.calculateDiscount(subtotal);
    }

    // Ensure discount doesn't exceed subtotal + tax (total can't be negative)
    final effectiveDiscount = calculatedDiscount > (subtotal + tax)
        ? (subtotal + tax)
        : calculatedDiscount;
    final total = subtotal + tax - effectiveDiscount;

    final confirmed = await _showPaymentDialog(total);
    if (!confirmed) return;

    try {
      // Use repositories for consistent data operations
      final transactionRepo = ref.read(posTransactionRepositoryProvider);
      final productRepo = ref.read(productRepositoryProvider);
      final materialRepo = ref.read(posMaterialRepositoryProvider);

      // Step 1: Validate product stock availability and tenant ownership before proceeding
      for (var item in cart) {
        final product = await productRepo.getProduct(item.product.id);
        if (product == null) {
          throw Exception('Produk ${item.product.name} tidak ditemukan');
        }
        // Multi-tenant validation: Ensure product belongs to current tenant
        if (product.tenantId != authState.tenant!.id) {
          throw Exception(
              'Produk ${item.product.name} tidak valid untuk tenant ini');
        }
        if (product.stock < item.quantity) {
          throw Exception(
              'Stok ${item.product.name} tidak mencukupi (tersedia: ${product.stock}, dibutuhkan: ${item.quantity})');
        }
      }

      // Step 2: Validate material stock availability based on recipes (multi-tenant)
      final recipes = ref.read(recipeNotifierProvider).valueOrNull ?? {};
      final materialStockErrors =
          await _validateMaterialStock(materialRepo, cart, recipes);
      if (materialStockErrors.isNotEmpty) {
        throw Exception(
            'Stok bahan baku tidak mencukupi:\n${materialStockErrors.join('\n')}');
      }

      // Step 3: Create transaction items list with cost price for profit calculation
      final itemsList = cart
          .map((item) => trans.TransactionItem(
                productId: item.product.id,
                productName: '${item.product.name} (${item.size})',
                price: item.unitPrice,
                costPrice: item
                    .product.costPrice, // Harga pokok untuk kalkulasi margin
                quantity: item.quantity,
                total: item.total,
              ))
          .toList();

      // Requirements 13.5: Associate transaction with active shift
      final activeShift = ref.read(activeShiftProvider).value;

      final transaction = trans.Transaction(
        id: const Uuid().v4(),
        tenantId: authState.tenant!.id,
        userId: authState.user!.id,
        shiftId: activeShift?.id, // Associate with active shift if exists
        discountId:
            selectedDiscount?.id, // Requirements 14.1: Associate with discount
        items: itemsList,
        subtotal: subtotal,
        discount: effectiveDiscount,
        tax: tax,
        total: total,
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
      );

      // Step 4: Save transaction using repository
      final transactionResult =
          await transactionRepo.createTransaction(transaction);
      if (!transactionResult.success) {
        throw Exception(transactionResult.error ?? 'Gagal menyimpan transaksi');
      }

      // Step 5: Update product stock using repository
      for (var item in cart) {
        if (AppConfig.useSupabase) {
          try {
            final cloudRepo = ref.read(cloudRepositoryProvider);
            await cloudRepo.decreaseProductStock(
                item.product.id, item.quantity);
          } catch (e) {
            debugPrint('Warning: Failed to update cloud product stock: $e');
          }
        } else {
          final stockResult =
              await productRepo.decreaseStock(item.product.id, item.quantity);
          if (!stockResult.success) {
            debugPrint(
                'Warning: Failed to update product stock: ${stockResult.error}');
          }
        }
      }

      // Step 6: Reduce material stock based on recipe using repository (multi-tenant)
      for (var item in cart) {
        await _reduceMaterialStockWithRepo(
            materialRepo, item.product.id, item.quantity, recipes);
      }

      // Step 7: Refresh data and show receipt
      ref.read(productProvider.notifier).loadProducts();
      // Refresh dashboard data after successful transaction
      ref.invalidate(dashboardProvider);
      if (mounted) _showReceiptDialog(transaction, _cashReceived);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Validate material stock availability for all cart items (multi-tenant)
  Future<List<String>> _validateMaterialStock(MaterialRepository materialRepo,
      List<CartItem> cart, Map<String, List<RecipeIngredient>> recipes) async {
    final errors = <String>[];
    final materialUsage = <String, double>{}; // materialId -> total needed

    // Calculate total material usage across all cart items
    for (var item in cart) {
      final recipe = recipes[item.product.id];
      if (recipe == null) continue;

      for (var ingredient in recipe) {
        final usedAmount = ingredient.quantity * item.quantity;
        materialUsage[ingredient.materialId] =
            (materialUsage[ingredient.materialId] ?? 0) + usedAmount;
      }
    }

    // Check if we have enough stock for each material
    for (var entry in materialUsage.entries) {
      final material = await materialRepo.getMaterial(entry.key);
      if (material == null) {
        errors.add('Bahan ${entry.key} tidak ditemukan');
        continue;
      }
      if (material.stock < entry.value) {
        errors.add(
            '${material.name}: tersedia ${material.stock.toStringAsFixed(3)} ${material.unit}, dibutuhkan ${entry.value.toStringAsFixed(3)} ${material.unit}');
      }
    }

    return errors;
  }

  /// Reduce material stock using repository (multi-tenant)
  Future<void> _reduceMaterialStockWithRepo(
      MaterialRepository materialRepo,
      String productId,
      int quantity,
      Map<String, List<RecipeIngredient>> recipes) async {
    final recipe = recipes[productId];
    if (recipe == null) return;

    for (var ingredient in recipe) {
      final usedAmount = ingredient.quantity * quantity;
      if (AppConfig.useSupabase) {
        try {
          final cloudRepo = ref.read(cloudRepositoryProvider);
          await cloudRepo.decreaseMaterialStock(
              ingredient.materialId, usedAmount);
        } catch (e) {
          debugPrint('Warning: Failed to update cloud material stock: $e');
        }
      } else {
        final result = await materialRepo.decreaseStock(
          ingredient.materialId,
          usedAmount,
          note: 'Used in transaction for product $productId',
        );
        if (!result.success) {
          debugPrint(
              'Warning: Failed to update material stock: ${result.error}');
        }
      }
    }
  }

  Future<bool> _showPaymentDialog(double total) async {
    _cashReceived = total;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final change = _cashReceived - total;
              return AlertDialog(
                title: Row(children: [
                  Icon(Icons.payment, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Pembayaran')
                ]),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 18)),
                            Text(_formatCurrency(total),
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                            labelText: 'Metode Pembayaran',
                            prefixIcon: Icon(Icons.wallet)),
                        items: const [
                          DropdownMenuItem(
                              value: 'cash', child: Text('💵 Tunai')),
                          DropdownMenuItem(
                              value: 'qris', child: Text('📱 QRIS')),
                          DropdownMenuItem(
                              value: 'debit', child: Text('💳 Kartu Debit')),
                          DropdownMenuItem(
                              value: 'transfer',
                              child: Text('🏦 Transfer Bank')),
                          DropdownMenuItem(
                              value: 'ewallet', child: Text('📲 E-Wallet')),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => _paymentMethod = v!),
                      ),
                      if (_paymentMethod == 'cash') ...[
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                              labelText: 'Uang Diterima', prefixText: 'Rp '),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setDialogState(() => _cashReceived =
                              double.tryParse(v.replaceAll('.', '')) ?? 0),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [50000, 100000, 150000, 200000]
                              .map((amount) => ActionChip(
                                    label: Text(
                                        _formatCurrency(amount.toDouble())),
                                    onPressed: () => setDialogState(() =>
                                        _cashReceived = amount.toDouble()),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: change >= 0
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Kembalian',
                                  style: TextStyle(
                                      color: change >= 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700)),
                              Text(_formatCurrency(change < 0 ? 0 : change),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: change >= 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal')),
                  ElevatedButton.icon(
                    onPressed:
                        (_paymentMethod == 'cash' && _cashReceived < total)
                            ? null
                            : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Bayar'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  }

  void _showReceiptDialog(trans.Transaction transaction, double cashReceived) {
    final change = cashReceived - transaction.total;
    final authState = ref.read(authProvider);
    final tenant = authState.tenant;
    final user = authState.user;
    final taxEnabled = ref.read(taxEnabledProvider);
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(width: 8),
          const Text('Transaksi Berhasil!')
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Business Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Logo placeholder
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          tenant?.name.substring(0, 1).toUpperCase() ?? '☕',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Business Name
                    Text(
                      tenant?.name ?? 'Toko',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Address
                    if (tenant?.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        tenant!.address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    // Phone
                    if (tenant?.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Telp: ${tenant!.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Transaction Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tanggal:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        Text(dateFormat.format(now),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jam:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        Text(timeFormat.format(now),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kasir:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        Text(user?.name ?? '-',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('No. Transaksi:',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        Text(transaction.id.substring(0, 8).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              // Items
              ...transaction.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(
                                  '${item.quantity}x ${item.productName}')),
                          Text(_formatCurrency(item.total)),
                        ]),
                  )),
              const Divider(),
              _receiptRow('Subtotal', transaction.subtotal),
              if (taxEnabled && transaction.tax > 0)
                _receiptRow('Pajak (${(tenant?.taxRate ?? 0.11) * 100}%)',
                    transaction.tax),
              if (transaction.discount > 0)
                _receiptRow('Diskon', -transaction.discount),
              const Divider(),
              _receiptRow('TOTAL', transaction.total, isBold: true),
              if (_paymentMethod == 'cash') ...[
                _receiptRow('Tunai', cashReceived),
                _receiptRow('Kembalian', change, isBold: true)
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('Terima kasih!',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Selamat menikmati ☕',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Preview & Print button
          OutlinedButton.icon(
              onPressed: () async {
                final authState = ref.read(authProvider);
                if (authState.tenant != null && authState.user != null) {
                  try {
                    // Show preview with print option
                    await ReceiptPrinter.showReceiptPreview(
                      context: context,
                      transaction: transaction,
                      tenant: authState.tenant!,
                      user: authState.user!,
                      cashReceived: cashReceived,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal membuka struk: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Lihat Struk')),
          const SizedBox(width: 8),
          // Direct print button
          OutlinedButton.icon(
              onPressed: () async {
                final authState = ref.read(authProvider);
                if (authState.tenant != null && authState.user != null) {
                  try {
                    await ReceiptPrinter.printReceipt(
                      context: context,
                      transaction: transaction,
                      tenant: authState.tenant!,
                      user: authState.user!,
                      cashReceived: cashReceived,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mencetak struk: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Cetak')),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              ref.read(taxEnabledProvider.notifier).state = true;
              ref.read(selectedDiscountProvider.notifier).state =
                  null; // Clear selected discount
              setState(() {
                _discount = 0;
                _cashReceived = 0;
                _paymentMethod = 'cash';
              });
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(_formatCurrency(amount),
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? AppTheme.primaryColor : null)),
      ]),
    );
  }
}

// Product Section Widget
class _ProductSection extends ConsumerWidget {
  final List<Product> products;
  final int crossAxisCount;
  final double bottomPadding;

  const _ProductSection(
      {required this.products,
      required this.crossAxisCount,
      this.bottomPadding = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final categories =
        products.map((p) => p.category ?? 'Lainnya').toSet().toList()..sort();

    var filteredProducts = products;
    if (selectedCategory != null) {
      filteredProducts = filteredProducts
          .where((p) => p.category == selectedCategory)
          .toList();
    }
    if (searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts
          .where(
              (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari menu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          ref.read(searchQueryProvider.notifier).state = '')
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
          ),
        ),
        // Category chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Semua'),
                  selected: selectedCategory == null,
                  onSelected: (_) =>
                      ref.read(selectedCategoryProvider.notifier).state = null,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${_getCategoryIcon(cat)} $cat'),
                      selected: selectedCategory == cat,
                      onSelected: (_) => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = selectedCategory == cat ? null : cat,
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  )),
            ],
          ),
        ),
        // Products grid
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.coffee_outlined,
                          size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text('Tidak ada produk',
                          style: Theme.of(context).textTheme.titleLarge),
                    ]))
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPadding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) => _ProductCard(
                    key: ValueKey(
                        '${filteredProducts[index].id}_${filteredProducts[index].name}_${filteredProducts[index].price}_${filteredProducts[index].stock}_${filteredProducts[index].imageUrl?.hashCode ?? 0}'),
                    product: filteredProducts[index],
                  ),
                ),
        ),
      ],
    );
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Hot Coffee':
        return '☕';
      case 'Iced Coffee':
        return '🧊';
      case 'Non-Coffee':
        return '🍵';
      case 'Food':
        return '🥐';
      default:
        return '📦';
    }
  }
}

// Product Card Widget
class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.stock <= 0;
    return Opacity(
      opacity: isOutOfStock ? 0.5 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: isOutOfStock ? null : () => _showAddToCartDialog(context, ref),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = constraints.maxHeight * 0.4;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                      color: _getCategoryColor(product.category),
                      borderRadius: BorderRadius.circular(8)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildProductImage(imageHeight),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text(
                          NumberFormat.currency(
                                  locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                              .format(product.price),
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(
                            isOutOfStock
                                ? Icons.error_outline
                                : Icons.inventory_2_outlined,
                            size: 11,
                            color:
                                isOutOfStock ? Colors.red : AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                              isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isOutOfStock
                                      ? Colors.red
                                      : AppTheme.textMuted)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductImage(double imageHeight) {
    // Check if product has a valid image URL (stored as base64)
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(product.imageUrl!);
        return SizedBox(
          width: double.infinity,
          height: imageHeight,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to emoji if image fails to load
              return Center(
                child: Text(
                  _getCategoryEmoji(product.category),
                  style: TextStyle(fontSize: imageHeight * 0.5),
                ),
              );
            },
          ),
        );
      } catch (e) {
        // If base64 decode fails, fallback to emoji
        return Center(
          child: Text(
            _getCategoryEmoji(product.category),
            style: TextStyle(fontSize: imageHeight * 0.5),
          ),
        );
      }
    }
    // Fallback to emoji if no image URL
    return Center(
      child: Text(
        _getCategoryEmoji(product.category),
        style: TextStyle(fontSize: imageHeight * 0.5),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return Colors.brown.shade100;
      case 'Iced Coffee':
        return Colors.blue.shade100;
      case 'Non-Coffee':
        return Colors.green.shade100;
      case 'Food':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return '☕';
      case 'Iced Coffee':
        return '🧊';
      case 'Non-Coffee':
        return '🍵';
      case 'Food':
        return '🥐';
      default:
        return '📦';
    }
  }

  void _showAddToCartDialog(BuildContext context, WidgetRef ref) {
    String selectedSize = 'Regular';
    String selectedTemp =
        product.category?.contains('Coffee') == true ? 'Hot' : 'Normal';
    int quantity = 1;

    // Calculate current quantity of this product already in cart
    final cart = ref.read(cartProvider);
    final currentQtyInCart = cart
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final availableStock = product.stock - currentQtyInCart;

    // If no stock available, show message and return
    if (availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok produk ini sudah habis di keranjang'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double extraPrice = selectedSize == 'Large' ? 5000 : 0;
          double totalPrice = (product.price + extraPrice) * quantity;

          return AlertDialog(
            title: Text(product.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show available stock info if some already in cart
                  if (currentQtyInCart > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sudah ada $currentQtyInCart di keranjang. Sisa stok: $availableStock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Ukuran:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: ChoiceChip(
                            label: const Text('Regular'),
                            selected: selectedSize == 'Regular',
                            onSelected: (_) =>
                                setState(() => selectedSize = 'Regular'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: ChoiceChip(
                            label: const Text('Large (+5K)'),
                            selected: selectedSize == 'Large',
                            onSelected: (_) =>
                                setState(() => selectedSize = 'Large'))),
                  ]),
                  if (product.category?.contains('Coffee') == true) ...[
                    const SizedBox(height: 16),
                    const Text('Suhu:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: ChoiceChip(
                              label: const Text('☕ Hot'),
                              selected: selectedTemp == 'Hot',
                              onSelected: (_) =>
                                  setState(() => selectedTemp = 'Hot'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: ChoiceChip(
                              label: const Text('🧊 Iced'),
                              selected: selectedTemp == 'Iced',
                              onSelected: (_) =>
                                  setState(() => selectedTemp = 'Iced'))),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  const Text('Jumlah:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(
                        onPressed: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('$quantity',
                          style: const TextStyle(fontSize: 18)),
                    ),
                    IconButton(
                        // Use availableStock instead of product.stock
                        onPressed: quantity < availableStock
                            ? () => setState(() => quantity++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:'),
                          Text(
                              NumberFormat.currency(
                                      locale: 'id',
                                      symbol: 'Rp ',
                                      decimalDigits: 0)
                                  .format(totalPrice),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal')),
              ElevatedButton.icon(
                onPressed: () {
                  for (int i = 0; i < quantity; i++) {
                    ref.read(cartProvider.notifier).addItem(product,
                        size: selectedSize, temp: selectedTemp);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$quantity ${product.name} ditambahkan'),
                      duration: const Duration(seconds: 1)));
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Cart Panel Widget
class _CartPanel extends ConsumerWidget {
  final double discount;
  final Function(double) onDiscountChanged;
  final VoidCallback onCheckout;
  final VoidCallback? onClearCart;
  final ScrollController? scrollController;

  const _CartPanel({
    required this.discount,
    required this.onDiscountChanged,
    required this.onCheckout,
    this.onClearCart,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch cart directly from provider for proper reactivity
    final cart = ref.watch(cartProvider);
    final taxEnabled = ref.watch(taxEnabledProvider);
    final authState = ref.watch(authProvider);
    final taxRate = authState.tenant?.taxRate ?? 0.11;
    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    final tax = taxEnabled ? subtotal * taxRate : 0.0;

    // Requirements 14.2, 14.3: Calculate discount from selected discount or manual input
    final selectedDiscount = ref.watch(selectedDiscountProvider);
    double calculatedDiscount = discount;
    if (selectedDiscount != null &&
        selectedDiscount.meetsMinPurchase(subtotal)) {
      calculatedDiscount = selectedDiscount.calculateDiscount(subtotal);
    }

    // Ensure discount doesn't exceed subtotal + tax (total can't be negative)
    final effectiveDiscount = calculatedDiscount > (subtotal + tax)
        ? (subtotal + tax)
        : calculatedDiscount;
    final total = subtotal + tax - effectiveDiscount;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1)),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart),
              const SizedBox(width: 8),
              Text('Keranjang (${cart.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clear();
                    ref.read(selectedDiscountProvider.notifier).state = null;
                    onClearCart?.call();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text('Keranjang kosong',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('Pilih menu untuk memulai',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                          ]),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.length,
                  itemBuilder: (context, index) => _CartItemCard(
                    key: ValueKey(
                        '${cart[index].product.id}_${cart[index].size}_${cart[index].temperature}_$index'),
                    item: cart[index],
                    index: index,
                  ),
                ),
        ),
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            children: [
              _SummaryRow('Subtotal', subtotal),
              // Tax Toggle Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('Pajak (${(taxRate * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const Spacer(),
                    // Tax Toggle Switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: taxEnabled,
                        onChanged: (value) {
                          ref.read(taxEnabledProvider.notifier).state = value;
                        },
                        activeThumbColor: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        taxEnabled
                            ? NumberFormat.currency(
                                    locale: 'id',
                                    symbol: 'Rp ',
                                    decimalDigits: 0)
                                .format(tax)
                            : 'Rp 0',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: taxEnabled ? null : AppTheme.textMuted,
                          decoration:
                              taxEnabled ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Requirements 14.6: Promo code and discount selection
              _DiscountSection(
                subtotal: subtotal,
                manualDiscount: discount,
                effectiveDiscount: effectiveDiscount,
                onManualDiscountChanged: onDiscountChanged,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                          NumberFormat.currency(
                                  locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                              .format(total),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.payment),
                  label: const Text('BAYAR', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Cart Item Card Widget
class _CartItemCard extends ConsumerWidget {
  final CartItem item;
  final int index;
  const _CartItemCard({super.key, required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          '${item.size}${item.temperature != 'Normal' ? ' • ${item.temperature}' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () =>
                    ref.read(cartProvider.notifier).removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text(
                  NumberFormat.currency(
                          locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                      .format(item.unitPrice),
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  InkWell(
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(index, item.quantity - 1),
                      child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.remove, size: 18))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}')),
                  InkWell(
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(index, item.quantity + 1),
                      child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add, size: 18))),
                ]),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 75,
                child: Text(
                    NumberFormat.currency(
                            locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                        .format(item.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// Summary Row Widget
class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  const _SummaryRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary)),
        Text(
            NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                .format(amount)),
      ]),
    );
  }
}

// Discount Section Widget for POS
// Requirements 14.6: Promo code input and discount selection
class _DiscountSection extends ConsumerStatefulWidget {
  final double subtotal;
  final double manualDiscount;
  final double effectiveDiscount;
  final Function(double) onManualDiscountChanged;

  const _DiscountSection({
    required this.subtotal,
    required this.manualDiscount,
    required this.effectiveDiscount,
    required this.onManualDiscountChanged,
  });

  @override
  ConsumerState<_DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends ConsumerState<_DiscountSection> {
  final _promoController = TextEditingController();
  String? _promoError;
  bool _isApplyingPromo = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() => _promoError = 'Masukkan kode promo');
      return;
    }

    setState(() {
      _isApplyingPromo = true;
      _promoError = null;
    });

    try {
      final authState = ref.read(authProvider);
      if (authState.user == null) return;

      final repo = ref.read(posDiscountRepositoryProvider);
      final discount =
          await repo.getByPromoCode(authState.user!.tenantId, code);

      if (discount == null) {
        setState(
            () => _promoError = 'Kode promo tidak valid atau sudah kadaluarsa');
      } else if (!discount.meetsMinPurchase(widget.subtotal)) {
        setState(() => _promoError =
            'Minimal pembelian Rp ${discount.minPurchase?.toStringAsFixed(0) ?? 0}');
      } else {
        ref.read(selectedDiscountProvider.notifier).state = discount;
        widget.onManualDiscountChanged(0); // Clear manual discount
        _promoController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Promo "${discount.name}" berhasil diterapkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _promoError = 'Gagal menerapkan promo');
    } finally {
      setState(() => _isApplyingPromo = false);
    }
  }

  void _clearDiscount() {
    ref.read(selectedDiscountProvider.notifier).state = null;
    widget.onManualDiscountChanged(0);
    _promoController.clear();
    setState(() => _promoError = null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDiscount = ref.watch(selectedDiscountProvider);
    final activeDiscountsAsync = ref.watch(posActiveDiscountsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected discount display
          if (selectedDiscount != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer,
                      color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDiscount.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          selectedDiscount.isPercentage
                              ? '${selectedDiscount.value.toStringAsFixed(0)}% OFF'
                              : 'Rp ${selectedDiscount.value.toStringAsFixed(0)} OFF',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(widget.effectiveDiscount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearDiscount,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Promo code input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    decoration: InputDecoration(
                      hintText: 'Kode Promo',
                      prefixIcon:
                          const Icon(Icons.confirmation_number, size: 20),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                      errorText: _promoError,
                      errorStyle: const TextStyle(fontSize: 11),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isApplyingPromo ? null : _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _isApplyingPromo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pakai'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Available discounts dropdown
            activeDiscountsAsync.when(
              data: (discounts) {
                if (discounts.isEmpty) return const SizedBox.shrink();
                final validDiscounts = discounts
                    .where(
                        (d) => !d.hasPromoCode) // Only show non-promo discounts
                    .toList();
                if (validDiscounts.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atau pilih diskon:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: validDiscounts.map((d) {
                        final meetsMin = d.meetsMinPurchase(widget.subtotal);
                        return ActionChip(
                          avatar: Icon(
                            d.isPercentage ? Icons.percent : Icons.attach_money,
                            size: 16,
                            color:
                                meetsMin ? AppTheme.primaryColor : Colors.grey,
                          ),
                          label: Text(
                            d.isPercentage
                                ? '${d.value.toStringAsFixed(0)}%'
                                : 'Rp ${d.value.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: meetsMin ? null : Colors.grey,
                            ),
                          ),
                          onPressed: meetsMin
                              ? () {
                                  ref
                                      .read(selectedDiscountProvider.notifier)
                                      .state = d;
                                  widget.onManualDiscountChanged(0);
                                }
                              : null,
                          tooltip: meetsMin
                              ? d.name
                              : 'Min. Rp ${d.minPurchase?.toStringAsFixed(0) ?? 0}',
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            // Manual discount input
            Row(
              children: [
                Text('Diskon Manual',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                SizedBox(
                  width: 100,
                  height: 36,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onChanged: (v) {
                      ref.read(selectedDiscountProvider.notifier).state = null;
                      widget.onManualDiscountChanged(
                          double.tryParse(v.replaceAll('.', '')) ?? 0);
                    },
                  ),
                ),
              ],
            ),
          ],
          // Show warning if discount was capped
          if (widget.manualDiscount > 0 &&
              widget.effectiveDiscount < widget.manualDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Diskon dibatasi maksimal ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(widget.effectiveDiscount)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
