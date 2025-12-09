import 'dart:async';
import '../services/supabase_service.dart';
import '../models/product.dart';
import '../models/material.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/shift.dart';
import '../models/discount.dart';
import '../models/branch.dart';
import '../models/user.dart';
import '../../core/utils/password_utils.dart';
import 'dart:convert';

/// Cloud Repository - Handles all Supabase operations
class CloudRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  /// Default timeout for network operations
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Wrapper to add timeout to async operations
  Future<T> _withTimeout<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(
        _defaultTimeout,
        onTimeout: () {
          throw TimeoutException(
              'Network request timeout after ${_defaultTimeout.inSeconds}s');
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // ==================== PRODUCTS ====================

  /// Get products filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Product>> getProducts(String tenantId, {String? branchId}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getProductsByBranch(branchId);
      // Additional tenant validation to ensure data isolation
      data = data.where((p) => p['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getProductsByTenant(tenantId);
    }
    return data.map((m) => _mapToProduct(m)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final data = await _supabase.getProductById(id);
    return data != null ? _mapToProduct(data) : null;
  }

  Future<Product?> getProductByBarcode(String barcode, String tenantId) async {
    final data = await _supabase.getProductByBarcode(barcode, tenantId);
    return data != null ? _mapToProduct(data) : null;
  }

  Future<Product> createProduct(Product product) async {
    final data = await _supabase.createProduct(_productToMap(product));
    return _mapToProduct(data);
  }

  Future<void> updateProduct(Product product) async {
    await _supabase.updateProduct(product.id, _productToMap(product));
  }

  Future<void> deleteProduct(String id) async {
    await _supabase.deleteProduct(id);
  }

  /// Decrease product stock
  Future<void> decreaseProductStock(String id, int quantity) async {
    final product = await getProductById(id);
    if (product != null) {
      final newStock = product.stock - quantity;
      if (newStock < 0) {
        throw Exception('Insufficient stock for product ${product.name}');
      }

      await updateProduct(product.copyWith(stock: newStock));
    }
  }

  Product _mapToProduct(Map<String, dynamic> m) {
    List<MaterialComposition>? composition;
    if (m['composition'] != null) {
      final compData = m['composition'] is String
          ? jsonDecode(m['composition'])
          : m['composition'];
      if (compData is List) {
        composition = compData
            .map((c) => MaterialComposition(
                  materialId: c['material_id'] ?? c['materialId'] ?? '',
                  quantity: (c['quantity'] as num?)?.toDouble() ?? 0,
                  unit: c['unit'] ?? '',
                ))
            .toList();
      }
    }

    return Product(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      name: m['name'] as String,
      barcode: m['barcode'] as String?,
      price: (m['price'] as num).toDouble(),
      costPrice: (m['cost'] as num?)?.toDouble() ??
          (m['cost_price'] as num?)?.toDouble() ??
          0,
      stock: (m['stock'] as num).toInt(),
      category: m['category'] as String?,
      imageUrl: m['image_url'] as String?,
      composition: composition,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _productToMap(Product p) {
    return {
      'id': p.id,
      'tenant_id': p.tenantId,
      'name': p.name,
      'barcode': p.barcode,
      'price': p.price,
      'cost': p.costPrice,
      'stock': p.stock,
      'category': p.category,
      'image_url': p.imageUrl,
      'composition': p.composition?.map((c) => c.toJson()).toList(),
      'is_active': true,
    };
  }

  // ==================== MATERIALS ====================

  /// Get materials filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Material>> getMaterials(String tenantId,
      {String? branchId}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getMaterialsByBranch(branchId);
      // Additional tenant validation to ensure data isolation
      data = data.where((m) => m['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getMaterialsByTenant(tenantId);
    }
    return data.map((m) => _mapToMaterial(m)).toList();
  }

  Future<Material?> getMaterialById(String id) async {
    final data = await _supabase.getMaterialById(id);
    return data != null ? _mapToMaterial(data) : null;
  }

  Future<Material> createMaterial(Material material) async {
    final data = await _supabase.createMaterial(_materialToMap(material));
    return _mapToMaterial(data);
  }

  Future<void> updateMaterial(Material material) async {
    await _supabase.updateMaterial(material.id, _materialToMap(material));
  }

  Future<void> deleteMaterial(String id) async {
    await _supabase.deleteMaterial(id);
  }

  /// Decrease material stock with stock movement recording
  Future<void> decreaseMaterialStock(String id, double quantity,
      {String? note}) async {
    final material = await getMaterialById(id);
    if (material != null) {
      final previousStock = material.stock;
      final newStock = previousStock - quantity;
      await updateMaterial(material.copyWith(stock: newStock));

      // Record stock movement for audit trail
      try {
        await _supabase.createStockMovement({
          'id': 'sm-${DateTime.now().millisecondsSinceEpoch}-${id.hashCode}',
          'material_id': id,
          'tenant_id': material.tenantId,
          'previous_stock': previousStock,
          'new_stock': newStock,
          'change': -quantity,
          'reason': 'sale',
          'note': note ?? 'Used in transaction',
        });
      } catch (e) {
        // Don't fail the transaction if stock movement recording fails
        // The stock update is more important
      }
    }
  }

  Material _mapToMaterial(Map<String, dynamic> m) {
    return Material(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      name: m['name'] as String,
      stock: (m['stock'] as num).toDouble(),
      unit: m['unit'] as String,
      minStock: (m['min_stock'] as num?)?.toDouble(),
      category: m['category'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _materialToMap(Material m) {
    return {
      'id': m.id,
      'tenant_id': m.tenantId,
      'name': m.name,
      'stock': m.stock,
      'unit': m.unit,
      'min_stock': m.minStock,
      'category': m.category,
    };
  }

  // ==================== TRANSACTIONS ====================

  /// Get transactions filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2, 2.3: Multi-tenant data isolation with branch filtering
  Future<List<Transaction>> getTransactions(String tenantId,
      {String? branchId, DateTime? startDate, DateTime? endDate}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getTransactionsByBranch(branchId,
          startDate: startDate, endDate: endDate);
      // Additional tenant validation to ensure data isolation
      data = data.where((t) => t['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getTransactionsByTenant(tenantId,
          startDate: startDate, endDate: endDate);
    }
    return data.map((m) => _mapToTransaction(m)).toList();
  }

  Future<List<Transaction>> getTransactionsByShift(String shiftId) async {
    final data = await _supabase.getTransactionsByShift(shiftId);
    return data.map((m) => _mapToTransaction(m)).toList();
  }

  Future<Transaction> createTransaction(Transaction transaction) async {
    return _withTimeout(() async {
      final data =
          await _supabase.createTransaction(_transactionToMap(transaction));
      return _mapToTransaction(data);
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _supabase.deleteTransaction(id);
  }

  Transaction _mapToTransaction(Map<String, dynamic> m) {
    List<TransactionItem> items = [];
    if (m['items'] != null) {
      final itemsData =
          m['items'] is String ? jsonDecode(m['items']) : m['items'];
      items = (itemsData as List)
          .map((i) => TransactionItem(
                productId: i['productId'] ?? i['product_id'] ?? '',
                productName: i['productName'] ?? i['product_name'] ?? '',
                quantity: (i['quantity'] as num).toInt(),
                price: (i['price'] as num).toDouble(),
                costPrice: (i['costPrice'] as num?)?.toDouble() ??
                    (i['cost_price'] as num?)?.toDouble() ??
                    0,
                total: (i['total'] as num?)?.toDouble() ??
                    (i['subtotal'] as num?)?.toDouble() ??
                    0,
              ))
          .toList();
    }

    return Transaction(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      branchId: m['branch_id'] as String?,
      userId: m['user_id'] as String,
      shiftId: m['shift_id'] as String?,
      discountId: m['discount_id'] as String?,
      items: items,
      subtotal: (m['subtotal'] as num).toDouble(),
      discount: (m['discount'] as num?)?.toDouble() ?? 0,
      tax: (m['tax'] as num?)?.toDouble() ?? 0,
      total: (m['total'] as num).toDouble(),
      paymentMethod: m['payment_method'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _transactionToMap(Transaction t) {
    return {
      'id': t.id,
      'tenant_id': t.tenantId,
      'branch_id': t.branchId,
      'user_id': t.userId,
      'shift_id': t.shiftId,
      'discount_id': t.discountId,
      'items': t.items
          .map((i) => {
                'productId': i.productId,
                'productName': i.productName,
                'quantity': i.quantity,
                'price': i.price,
                'costPrice': i.costPrice,
                'total': i.total,
              })
          .toList(),
      'subtotal': t.subtotal,
      'discount': t.discount,
      'tax': t.tax,
      'total': t.total,
      'payment_method': t.paymentMethod,
    };
  }

  // ==================== SHIFTS ====================

  /// Get shifts filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<Shift>> getShifts(String tenantId, {String? branchId}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getShiftsByBranch(branchId);
      // Additional tenant validation to ensure data isolation
      data = data.where((s) => s['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getShiftsByTenant(tenantId);
    }
    return data.map((m) => _mapToShift(m)).toList();
  }

  Future<Shift?> getActiveShift(String userId) async {
    final data = await _supabase.getActiveShift(userId);
    return data != null ? _mapToShift(data) : null;
  }

  Future<Shift?> getShiftById(String id) async {
    final data = await _supabase.getShiftById(id);
    return data != null ? _mapToShift(data) : null;
  }

  Future<Shift> createShift(Shift shift) async {
    final data = await _supabase.createShift(_shiftToMap(shift));
    return _mapToShift(data);
  }

  Future<void> updateShift(Shift shift) async {
    await _supabase.updateShift(shift.id, _shiftToMap(shift));
  }

  Shift _mapToShift(Map<String, dynamic> m) {
    return Shift(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      userId: m['user_id'] as String,
      startTime: DateTime.parse(m['start_time'] as String),
      endTime: m['end_time'] != null
          ? DateTime.parse(m['end_time'] as String)
          : null,
      openingCash: (m['opening_cash'] as num).toDouble(),
      closingCash: (m['closing_cash'] as num?)?.toDouble(),
      expectedCash: (m['expected_cash'] as num?)?.toDouble(),
      variance: (m['variance'] as num?)?.toDouble(),
      varianceNote: m['variance_note'] as String?,
      status: m['status'] == 'active' ? ShiftStatus.active : ShiftStatus.closed,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _shiftToMap(Shift s) {
    return {
      'id': s.id,
      'tenant_id': s.tenantId,
      'user_id': s.userId,
      'start_time': s.startTime.toIso8601String(),
      'end_time': s.endTime?.toIso8601String(),
      'opening_cash': s.openingCash,
      'closing_cash': s.closingCash,
      'expected_cash': s.expectedCash,
      'variance': s.variance,
      'variance_note': s.varianceNote,
      'status': s.status.toString().split('.').last,
    };
  }

  // ==================== DISCOUNTS ====================

  Future<List<Discount>> getDiscounts(String tenantId) async {
    final data = await _supabase.getDiscountsByTenant(tenantId);
    return data.map((m) => _mapToDiscount(m)).toList();
  }

  Future<List<Discount>> getActiveDiscounts(String tenantId) async {
    final data = await _supabase.getActiveDiscounts(tenantId);
    return data.map((m) => _mapToDiscount(m)).toList();
  }

  Future<Discount?> getDiscountByPromoCode(
      String promoCode, String tenantId) async {
    final data = await _supabase.getDiscountByPromoCode(promoCode, tenantId);
    return data != null ? _mapToDiscount(data) : null;
  }

  Future<Discount> createDiscount(Discount discount) async {
    final data = await _supabase.createDiscount(_discountToMap(discount));
    return _mapToDiscount(data);
  }

  Future<void> updateDiscount(Discount discount) async {
    await _supabase.updateDiscount(discount.id, _discountToMap(discount));
  }

  Future<void> deleteDiscount(String id) async {
    await _supabase.deleteDiscount(id);
  }

  Discount _mapToDiscount(Map<String, dynamic> m) {
    return Discount(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      name: m['name'] as String,
      type: m['type'] == 'percentage'
          ? DiscountType.percentage
          : DiscountType.fixed,
      value: (m['value'] as num).toDouble(),
      minPurchase: (m['min_purchase'] as num?)?.toDouble(),
      promoCode: m['promo_code'] as String?,
      validFrom: DateTime.parse(m['valid_from'] as String),
      validUntil: DateTime.parse(m['valid_until'] as String),
      isActive: m['is_active'] == true,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _discountToMap(Discount d) {
    return {
      'id': d.id,
      'tenant_id': d.tenantId,
      'name': d.name,
      'type': d.type.toString().split('.').last,
      'value': d.value,
      'min_purchase': d.minPurchase,
      'promo_code': d.promoCode,
      'valid_from': d.validFrom.toIso8601String(),
      'valid_until': d.validUntil.toIso8601String(),
      'is_active': d.isActive,
    };
  }

  // ==================== EXPENSES ====================

  /// Get expenses filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2, 2.5: Multi-tenant data isolation with branch filtering
  Future<List<Expense>> getExpenses(String tenantId,
      {String? branchId, DateTime? startDate, DateTime? endDate}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getExpensesByBranch(branchId,
          startDate: startDate, endDate: endDate);
      // Additional tenant validation to ensure data isolation
      data = data.where((e) => e['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getExpensesByTenant(tenantId,
          startDate: startDate, endDate: endDate);
    }
    return data.map((m) => _mapToExpense(m)).toList();
  }

  Future<Expense> createExpense(Expense expense) async {
    final data = await _supabase.createExpense(_expenseToMap(expense));
    return _mapToExpense(data);
  }

  Future<void> updateExpense(Expense expense) async {
    await _supabase.updateExpense(expense.id, _expenseToMap(expense));
  }

  Future<void> deleteExpense(String id) async {
    await _supabase.deleteExpense(id);
  }

  Expense _mapToExpense(Map<String, dynamic> m) {
    return Expense(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      category: m['category'] as String,
      amount: (m['amount'] as num).toDouble(),
      description: m['description'] as String?,
      date: DateTime.parse(m['date'] as String),
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _expenseToMap(Expense e) {
    return {
      'id': e.id,
      'tenant_id': e.tenantId,
      'category': e.category,
      'amount': e.amount,
      'description': e.description,
      'date': e.date.toIso8601String().split('T')[0],
    };
  }

  // ==================== BRANCHES ====================

  Future<List<Branch>> getBranches(String tenantId) async {
    final data = await _supabase.getBranchesByTenant(tenantId);
    return data.map((m) => _mapToBranch(m)).toList();
  }

  Future<List<Branch>> getBranchesByOwner(String ownerId) async {
    final data = await _supabase.getBranchesByOwner(ownerId);
    return data.map((m) => _mapToBranch(m)).toList();
  }

  Future<Branch?> getBranchById(String id) async {
    final data = await _supabase.getBranchById(id);
    return data != null ? _mapToBranch(data) : null;
  }

  Future<Branch> createBranch(Branch branch) async {
    final data = await _supabase.createBranch(_branchToMap(branch));
    return _mapToBranch(data);
  }

  Future<void> updateBranch(Branch branch) async {
    await _supabase.updateBranch(branch.id, _branchToMap(branch));
  }

  Future<void> deleteBranch(String id) async {
    await _supabase.deleteBranch(id);
  }

  Branch _mapToBranch(Map<String, dynamic> m) {
    return Branch(
      id: m['id'] as String,
      ownerId: m['owner_id'] as String,
      name: m['name'] as String,
      code: m['code'] as String,
      address: m['address'] as String?,
      phone: m['phone'] as String?,
      taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0.11,
      isActive: m['is_active'] == true,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: m['updated_at'] != null
          ? DateTime.parse(m['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _branchToMap(Branch b) {
    return {
      'id': b.id,
      'tenant_id': b.ownerId, // Use ownerId as tenant_id for now
      'owner_id': b.ownerId,
      'name': b.name,
      'code': b.code,
      'address': b.address,
      'phone': b.phone,
      'tax_rate': b.taxRate,
      'is_active': b.isActive,
    };
  }

  // ==================== USERS ====================

  /// Get users filtered by tenant ID and optionally by branch ID
  /// Requirements 2.1, 2.2: Multi-tenant data isolation with branch filtering
  Future<List<User>> getUsers(String tenantId, {String? branchId}) async {
    List<Map<String, dynamic>> data;
    if (branchId != null && branchId.isNotEmpty) {
      // Filter by branch when branch ID is provided
      data = await _supabase.getUsersByBranch(branchId);
      // Additional tenant validation to ensure data isolation
      data = data.where((u) => u['tenant_id'] == tenantId).toList();
    } else {
      // Filter by tenant only
      data = await _supabase.getUsersByTenant(tenantId);
    }
    return data.map((m) => _mapToUser(m)).toList();
  }

  Future<User?> getUserById(String id) async {
    final data = await _supabase.getUserById(id);
    return data != null ? _mapToUser(data) : null;
  }

  Future<User> createUser(User user, String password) async {
    final map = _userToMap(user);
    // Hash password before storing
    map['password_hash'] = PasswordUtils.hashPassword(password);
    final data = await _supabase.createUser(map);
    return _mapToUser(data);
  }

  Future<void> updateUser(User user) async {
    await _supabase.updateUser(user.id, _userToMap(user));
  }

  Future<void> deleteUser(String id) async {
    await _supabase.deleteUser(id);
  }

  User _mapToUser(Map<String, dynamic> m) {
    return User(
      id: m['id'] as String,
      tenantId: m['tenant_id'] as String,
      branchId: m['branch_id'] as String?,
      email: m['email'] as String,
      name: m['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == m['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: m['is_active'] == true,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> _userToMap(User u) {
    return {
      'id': u.id,
      'tenant_id': u.tenantId,
      'branch_id': u.branchId,
      'email': u.email,
      'name': u.name,
      'role': u.role.toString().split('.').last,
      'is_active': u.isActive,
    };
  }

  // ==================== RECIPES ====================

  /// Get all recipes for a tenant, grouped by product ID
  Future<Map<String, List<CloudRecipeIngredient>>> getAllRecipes(
      String tenantId) async {
    final data = await _supabase.getRecipesByTenant(tenantId);
    final Map<String, List<CloudRecipeIngredient>> recipes = {};

    for (final item in data) {
      final productId = item['product_id'] as String;
      final ingredient = CloudRecipeIngredient(
        materialId: item['material_id'] as String,
        name: item['materials']?['name'] as String? ?? '',
        quantity: (item['quantity'] as num).toDouble(),
        unit: item['materials']?['unit'] as String? ?? '',
      );

      if (recipes.containsKey(productId)) {
        recipes[productId]!.add(ingredient);
      } else {
        recipes[productId] = [ingredient];
      }
    }

    return recipes;
  }

  /// Get recipe for a specific product
  Future<List<CloudRecipeIngredient>> getRecipeByProduct(
      String productId) async {
    final data = await _supabase.getRecipesByProduct(productId);
    return data
        .map((item) => CloudRecipeIngredient(
              materialId: item['material_id'] as String,
              name: item['materials']?['name'] as String? ?? '',
              quantity: (item['quantity'] as num).toDouble(),
              unit: item['materials']?['unit'] as String? ?? '',
            ))
        .toList();
  }

  /// Save recipe for a product (replaces existing)
  Future<void> saveRecipe(String tenantId, String productId,
      List<CloudRecipeIngredient> ingredients) async {
    // Delete existing recipes for this product
    await _supabase.deleteRecipesByProduct(productId);

    // Insert new recipes
    for (final ingredient in ingredients) {
      await _supabase.createRecipe({
        'tenant_id': tenantId,
        'product_id': productId,
        'material_id': ingredient.materialId,
        'quantity': ingredient.quantity,
      });
    }
  }

  /// Delete recipe for a product
  Future<void> deleteRecipe(String productId) async {
    await _supabase.deleteRecipesByProduct(productId);
  }

  // ==================== STOCK MOVEMENTS ====================

  /// Get stock movements for a material
  Future<List<CloudStockMovement>> getStockMovementsByMaterial(
      String materialId) async {
    final data = await _supabase.getStockMovementsByMaterial(materialId);
    return data.map((m) => _mapToStockMovement(m)).toList();
  }

  /// Create a stock movement record
  Future<CloudStockMovement> createStockMovement(
      CloudStockMovement movement) async {
    final data =
        await _supabase.createStockMovement(_stockMovementToMap(movement));
    return _mapToStockMovement(data);
  }

  CloudStockMovement _mapToStockMovement(Map<String, dynamic> m) {
    return CloudStockMovement(
      id: m['id'] as String,
      materialId: m['material_id'] as String,
      tenantId: m['tenant_id'] as String,
      branchId: m['branch_id'] as String?,
      previousStock: (m['previous_stock'] as num).toDouble(),
      newStock: (m['new_stock'] as num).toDouble(),
      change: (m['change'] as num).toDouble(),
      reason: m['reason'] as String,
      note: m['note'] as String?,
      timestamp: DateTime.parse(m['timestamp'] as String),
    );
  }

  Map<String, dynamic> _stockMovementToMap(CloudStockMovement sm) {
    return {
      'id': sm.id,
      'material_id': sm.materialId,
      'tenant_id': sm.tenantId,
      'branch_id': sm.branchId,
      'previous_stock': sm.previousStock,
      'new_stock': sm.newStock,
      'change': sm.change,
      'reason': sm.reason,
      'note': sm.note,
    };
  }
}

/// Stock movement model for cloud repository
class CloudStockMovement {
  final String id;
  final String materialId;
  final String tenantId;
  final String? branchId;
  final double previousStock;
  final double newStock;
  final double change;
  final String reason;
  final String? note;
  final DateTime timestamp;

  CloudStockMovement({
    required this.id,
    required this.materialId,
    required this.tenantId,
    this.branchId,
    required this.previousStock,
    required this.newStock,
    required this.change,
    required this.reason,
    this.note,
    required this.timestamp,
  });
}

/// Recipe ingredient model for cloud repository
class CloudRecipeIngredient {
  final String materialId;
  final String name;
  final double quantity;
  final String unit;

  CloudRecipeIngredient({
    required this.materialId,
    required this.name,
    required this.quantity,
    required this.unit,
  });
}
