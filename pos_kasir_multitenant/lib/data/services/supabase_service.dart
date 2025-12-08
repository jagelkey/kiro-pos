import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  static bool get isInitialized => _client != null;

  /// Initialize Supabase - call this in main.dart
  static Future<void> initialize() async {
    if (_client != null) return;

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  // ==================== TENANTS ====================

  Future<Map<String, dynamic>?> getTenantByIdentifier(String identifier) async {
    final response = await client
        .from(SupabaseConfig.tenantsTable)
        .select()
        .eq('identifier', identifier)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getTenantById(String id) async {
    final response = await client
        .from(SupabaseConfig.tenantsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.tenantsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateTenant(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.tenantsTable).update(data).eq('id', id);
  }

  // ==================== USERS ====================

  Future<Map<String, dynamic>?> getUserByEmail(
      String email, String tenantId) async {
    final response = await client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('email', email)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final response = await client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> getUsersByTenant(String tenantId) async {
    final response = await client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getUsersByBranch(String branchId) async {
    final response = await client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('branch_id', branchId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.usersTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.usersTable).update(data).eq('id', id);
  }

  Future<void> deleteUser(String id) async {
    await client.from(SupabaseConfig.usersTable).delete().eq('id', id);
  }

  // ==================== BRANCHES ====================

  Future<List<Map<String, dynamic>>> getBranchesByTenant(
      String tenantId) async {
    final response = await client
        .from(SupabaseConfig.branchesTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBranchesByOwner(String ownerId) async {
    final response = await client
        .from(SupabaseConfig.branchesTable)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getBranchById(String id) async {
    final response = await client
        .from(SupabaseConfig.branchesTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.branchesTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateBranch(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.branchesTable).update(data).eq('id', id);
  }

  Future<void> deleteBranch(String id) async {
    await client.from(SupabaseConfig.branchesTable).delete().eq('id', id);
  }

  // ==================== PRODUCTS ====================

  Future<List<Map<String, dynamic>>> getProductsByTenant(
      String tenantId) async {
    final response = await client
        .from(SupabaseConfig.productsTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getProductsByBranch(
      String branchId) async {
    final response = await client
        .from(SupabaseConfig.productsTable)
        .select()
        .eq('branch_id', branchId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final response = await client
        .from(SupabaseConfig.productsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getProductByBarcode(
      String barcode, String tenantId) async {
    final response = await client
        .from(SupabaseConfig.productsTable)
        .select()
        .eq('barcode', barcode)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.productsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.productsTable).update(data).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await client.from(SupabaseConfig.productsTable).delete().eq('id', id);
  }

  // ==================== MATERIALS ====================

  Future<List<Map<String, dynamic>>> getMaterialsByTenant(
      String tenantId) async {
    final response = await client
        .from(SupabaseConfig.materialsTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMaterialsByBranch(
      String branchId) async {
    final response = await client
        .from(SupabaseConfig.materialsTable)
        .select()
        .eq('branch_id', branchId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getMaterialById(String id) async {
    final response = await client
        .from(SupabaseConfig.materialsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createMaterial(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.materialsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateMaterial(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.materialsTable).update(data).eq('id', id);
  }

  Future<void> deleteMaterial(String id) async {
    await client.from(SupabaseConfig.materialsTable).delete().eq('id', id);
  }

  // ==================== TRANSACTIONS ====================

  Future<List<Map<String, dynamic>>> getTransactionsByTenant(String tenantId,
      {DateTime? startDate, DateTime? endDate}) async {
    var query = client
        .from(SupabaseConfig.transactionsTable)
        .select()
        .eq('tenant_id', tenantId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByBranch(String branchId,
      {DateTime? startDate, DateTime? endDate}) async {
    var query = client
        .from(SupabaseConfig.transactionsTable)
        .select()
        .eq('branch_id', branchId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByShift(
      String shiftId) async {
    final response = await client
        .from(SupabaseConfig.transactionsTable)
        .select()
        .eq('shift_id', shiftId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createTransaction(
      Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.transactionsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> deleteTransaction(String id) async {
    await client.from(SupabaseConfig.transactionsTable).delete().eq('id', id);
  }

  // ==================== SHIFTS ====================

  Future<List<Map<String, dynamic>>> getShiftsByTenant(String tenantId) async {
    final response = await client
        .from(SupabaseConfig.shiftsTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('start_time', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getShiftsByBranch(String branchId) async {
    final response = await client
        .from(SupabaseConfig.shiftsTable)
        .select()
        .eq('branch_id', branchId)
        .order('start_time', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getActiveShift(String userId) async {
    final response = await client
        .from(SupabaseConfig.shiftsTable)
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getShiftById(String id) async {
    final response = await client
        .from(SupabaseConfig.shiftsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.shiftsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateShift(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.shiftsTable).update(data).eq('id', id);
  }

  // ==================== DISCOUNTS ====================

  Future<List<Map<String, dynamic>>> getDiscountsByTenant(
      String tenantId) async {
    final response = await client
        .from(SupabaseConfig.discountsTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getActiveDiscounts(String tenantId) async {
    final now = DateTime.now().toIso8601String();
    final response = await client
        .from(SupabaseConfig.discountsTable)
        .select()
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .lte('valid_from', now)
        .gte('valid_until', now)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getDiscountByPromoCode(
      String promoCode, String tenantId) async {
    final response = await client
        .from(SupabaseConfig.discountsTable)
        .select()
        .eq('promo_code', promoCode)
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> createDiscount(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.discountsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateDiscount(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.discountsTable).update(data).eq('id', id);
  }

  Future<void> deleteDiscount(String id) async {
    await client.from(SupabaseConfig.discountsTable).delete().eq('id', id);
  }

  // ==================== EXPENSES ====================

  Future<List<Map<String, dynamic>>> getExpensesByTenant(String tenantId,
      {DateTime? startDate, DateTime? endDate}) async {
    var query = client
        .from(SupabaseConfig.expensesTable)
        .select()
        .eq('tenant_id', tenantId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String().split('T')[0]);
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String().split('T')[0]);
    }

    final response = await query.order('date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getExpensesByBranch(String branchId,
      {DateTime? startDate, DateTime? endDate}) async {
    var query = client
        .from(SupabaseConfig.expensesTable)
        .select()
        .eq('branch_id', branchId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String().split('T')[0]);
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String().split('T')[0]);
    }

    final response = await query.order('date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.expensesTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.expensesTable).update(data).eq('id', id);
  }

  Future<void> deleteExpense(String id) async {
    await client.from(SupabaseConfig.expensesTable).delete().eq('id', id);
  }

  // ==================== STOCK MOVEMENTS ====================

  Future<List<Map<String, dynamic>>> getStockMovementsByMaterial(
      String materialId) async {
    final response = await client
        .from(SupabaseConfig.stockMovementsTable)
        .select()
        .eq('material_id', materialId)
        .order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getStockMovementsByTenant(
      String tenantId) async {
    final response = await client
        .from(SupabaseConfig.stockMovementsTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createStockMovement(
      Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.stockMovementsTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  // ==================== RECIPES ====================

  Future<List<Map<String, dynamic>>> getRecipesByProduct(
      String productId) async {
    final response = await client
        .from(SupabaseConfig.recipesTable)
        .select('*, materials(*)')
        .eq('product_id', productId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getRecipesByTenant(String tenantId) async {
    final response = await client
        .from(SupabaseConfig.recipesTable)
        .select('*, products(*), materials(*)')
        .eq('tenant_id', tenantId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> data) async {
    final response = await client
        .from(SupabaseConfig.recipesTable)
        .insert(data)
        .select()
        .single();
    return response;
  }

  Future<void> updateRecipe(String id, Map<String, dynamic> data) async {
    await client.from(SupabaseConfig.recipesTable).update(data).eq('id', id);
  }

  Future<void> deleteRecipe(String id) async {
    await client.from(SupabaseConfig.recipesTable).delete().eq('id', id);
  }

  Future<void> deleteRecipesByProduct(String productId) async {
    await client
        .from(SupabaseConfig.recipesTable)
        .delete()
        .eq('product_id', productId);
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Subscribe to changes on a table
  RealtimeChannel subscribeToTable(
    String table, {
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
    required void Function(Map<String, dynamic> payload) onDelete,
    String? filterColumn,
    String? filterValue,
  }) {
    var channel = client.channel('public:$table');

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: table,
      filter: filterColumn != null && filterValue != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filterColumn,
              value: filterValue,
            )
          : null,
      callback: (payload) => onInsert(payload.newRecord),
    );

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: table,
      filter: filterColumn != null && filterValue != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filterColumn,
              value: filterValue,
            )
          : null,
      callback: (payload) => onUpdate(payload.newRecord),
    );

    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: table,
      filter: filterColumn != null && filterValue != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filterColumn,
              value: filterValue,
            )
          : null,
      callback: (payload) => onDelete(payload.oldRecord),
    );

    channel.subscribe();
    return channel;
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
