import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../data/models/tenant.dart';
import '../../data/mock/mock_data.dart';

class DemoSeederService {
  static final DemoSeederService _instance = DemoSeederService._();
  static DemoSeederService get instance => _instance;

  DemoSeederService._();

  final _client = Supabase.instance.client;

  static const String _demoTenantId = '11111111-1111-1111-1111-111111111111';
  static const String _superAdminId = '22222222-2222-2222-2222-222222222200';

  static final _mockTenant = Tenant(
    id: _demoTenantId,
    name: 'POS System',
    identifier: 'demo',
    timezone: 'Asia/Jakarta',
    currency: 'IDR',
    taxRate: 0.11,
    address: 'Jakarta, Indonesia',
    phone: '081234567890',
    email: 'admin@pos.com',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// Seed demo data if it doesn't exist
  Future<void> seedDemoData() async {
    try {
      debugPrint('🌱 Checking and seeding demo data to Supabase...');

      await _seedTenant();
      await _seedUsers(); // Users first (before branches)
      await _seedBranches(); // Branches after users (needs owner_id)
      await _seedProducts();
      await _seedMaterials();
      await _seedDiscounts();
      await _seedExpenses();

      debugPrint('✅ Demo data seeding completed.');
    } catch (e) {
      debugPrint('❌ Error seeding demo data: $e');
    }
  }

  Future<void> _seedTenant() async {
    try {
      final existing = await _client
          .from(SupabaseConfig.tenantsTable)
          .select()
          .eq('identifier', 'demo')
          .maybeSingle();

      if (existing == null) {
        debugPrint('Creating demo tenant...');
        await _client
            .from(SupabaseConfig.tenantsTable)
            .insert(_mockTenant.toMap());
        debugPrint('Demo tenant created.');
      } else {
        debugPrint('Demo tenant already exists.');
      }
    } catch (e) {
      debugPrint('Error seeding tenant: $e');
      rethrow;
    }
  }

  Future<void> _seedUsers() async {
    try {
      for (final user in MockData.users) {
        final existing = await _client
            .from(SupabaseConfig.usersTable)
            .select()
            .eq('email', user.email)
            .eq('tenant_id', user.tenantId)
            .maybeSingle();

        if (existing == null) {
          debugPrint('  Creating user: ${user.email}');

          final supabaseMap = {
            'id': user.id,
            'tenant_id': user.tenantId,
            'branch_id': user.branchId,
            'email': user.email,
            'name': user.name,
            'password_hash': user.passwordHash,
            'role': user.role.name,
            'is_active': user.isActive,
            'created_at': user.createdAt.toIso8601String(),
          };

          await _client.from(SupabaseConfig.usersTable).insert(supabaseMap);
        }
      }
      debugPrint('  ✓ Users seeded');
    } catch (e) {
      debugPrint('  ✗ Error seeding users: $e');
    }
  }

  Future<void> _seedBranches() async {
    try {
      for (final branch in MockData.branches) {
        final existing = await _client
            .from(SupabaseConfig.branchesTable)
            .select()
            .eq('id', branch.id)
            .maybeSingle();

        if (existing == null) {
          debugPrint('  Creating branch: ${branch.name}');

          await _client.from(SupabaseConfig.branchesTable).insert({
            'id': branch.id,
            'tenant_id': _demoTenantId,
            'owner_id': _superAdminId,
            'name': branch.name,
            'code': branch.code,
            'address': branch.address,
            'phone': branch.phone,
            'tax_rate': branch.taxRate,
            'is_active': branch.isActive,
            'created_at': branch.createdAt.toIso8601String(),
          });
        }
      }
      debugPrint('  ✓ Branches seeded');
    } catch (e) {
      debugPrint('  ✗ Error seeding branches: $e');
    }
  }

  Future<void> _seedProducts() async {
    try {
      final existing = await _client
          .from(SupabaseConfig.productsTable)
          .select('id')
          .eq('tenant_id', _demoTenantId)
          .limit(1);

      if ((existing as List).isEmpty) {
        debugPrint('  Seeding ${MockData.products.length} products...');

        for (final product in MockData.products) {
          await _client.from(SupabaseConfig.productsTable).insert({
            'id': product.id,
            'tenant_id': product.tenantId,
            'name': product.name,
            'barcode': product.barcode,
            'price': product.price,
            'cost': product.costPrice,
            'stock': product.stock,
            'category': product.category,
            'image_url': product.imageUrl,
            'is_active': true,
            'created_at': product.createdAt.toIso8601String(),
          });
        }
        debugPrint('  ✓ Products seeded');
      } else {
        debugPrint('  Products already exist, skipping');
      }
    } catch (e) {
      debugPrint('  ✗ Error seeding products: $e');
    }
  }

  Future<void> _seedMaterials() async {
    try {
      final existing = await _client
          .from(SupabaseConfig.materialsTable)
          .select('id')
          .eq('tenant_id', _demoTenantId)
          .limit(1);

      if ((existing as List).isEmpty) {
        debugPrint('  Seeding ${MockData.materials.length} materials...');

        for (final material in MockData.materials) {
          await _client.from(SupabaseConfig.materialsTable).insert({
            'id': material.id,
            'tenant_id': material.tenantId,
            'name': material.name,
            'stock': material.stock,
            'unit': material.unit,
            'min_stock': material.minStock,
            'category': material.category,
            'created_at': material.createdAt.toIso8601String(),
          });
        }
        debugPrint('  ✓ Materials seeded');
      } else {
        debugPrint('  Materials already exist, skipping');
      }
    } catch (e) {
      debugPrint('  ✗ Error seeding materials: $e');
    }
  }

  Future<void> _seedDiscounts() async {
    try {
      final existing = await _client
          .from(SupabaseConfig.discountsTable)
          .select('id')
          .eq('tenant_id', _demoTenantId)
          .limit(1);

      if ((existing as List).isEmpty) {
        debugPrint('  Seeding ${MockData.discounts.length} discounts...');

        for (final discount in MockData.discounts) {
          await _client.from(SupabaseConfig.discountsTable).insert({
            'id': discount.id,
            'tenant_id': discount.tenantId,
            'name': discount.name,
            'type': discount.type.name,
            'value': discount.value,
            'min_purchase': discount.minPurchase,
            'promo_code': discount.promoCode,
            'valid_from': discount.validFrom.toIso8601String(),
            'valid_until': discount.validUntil.toIso8601String(),
            'is_active': discount.isActive,
            'created_at': discount.createdAt.toIso8601String(),
          });
        }
        debugPrint('  ✓ Discounts seeded');
      } else {
        debugPrint('  Discounts already exist, skipping');
      }
    } catch (e) {
      debugPrint('  ✗ Error seeding discounts: $e');
    }
  }

  Future<void> _seedExpenses() async {
    try {
      final existing = await _client
          .from(SupabaseConfig.expensesTable)
          .select('id')
          .eq('tenant_id', _demoTenantId)
          .limit(1);

      if ((existing as List).isEmpty) {
        debugPrint('  Seeding ${MockData.expenses.length} expenses...');

        for (final expense in MockData.expenses) {
          await _client.from(SupabaseConfig.expensesTable).insert({
            'id': expense.id,
            'tenant_id': expense.tenantId,
            'category': expense.category,
            'amount': expense.amount,
            'description': expense.description,
            'date': expense.date.toIso8601String().split('T')[0],
            'created_at': expense.createdAt.toIso8601String(),
          });
        }
        debugPrint('  ✓ Expenses seeded');
      } else {
        debugPrint('  Expenses already exist, skipping');
      }
    } catch (e) {
      debugPrint('  ✗ Error seeding expenses: $e');
    }
  }

  /// Delete all demo data from Supabase and reseed
  Future<void> resetDemoData() async {
    try {
      debugPrint('🗑️ Deleting all demo data from Supabase...');

      // Delete in order (foreign key constraints)
      await _client
          .from(SupabaseConfig.transactionsTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.shiftsTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.discountsTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.expensesTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.materialsTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.productsTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.usersTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.branchesTable)
          .delete()
          .eq('tenant_id', _demoTenantId);
      await _client
          .from(SupabaseConfig.tenantsTable)
          .delete()
          .eq('id', _demoTenantId);

      debugPrint('✅ All demo data deleted. Reseeding...');
      await seedDemoData();
    } catch (e) {
      debugPrint('❌ Error resetting demo data: $e');
    }
  }
}
