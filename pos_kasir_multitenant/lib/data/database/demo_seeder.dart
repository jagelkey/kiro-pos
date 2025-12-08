import 'database_helper.dart';
import '../../core/utils/password_utils.dart';

/// Demo Seeder - Seeds demo data to SQLite for offline mode
class DemoSeeder {
  static const String tenantId = '11111111-1111-1111-1111-111111111111';
  static const String superAdminId = '22222222-2222-2222-2222-222222222200';
  static const String branchId1 = '33333333-3333-3333-3333-333333333301';
  static const String branchId2 = '33333333-3333-3333-3333-333333333302';

  static Future<void> seedDemoData() async {
    final db = await DatabaseHelper.instance.database;

    // Check if demo data already exists
    final existingTenant = await db.query(
      'tenants',
      where: 'identifier = ?',
      whereArgs: ['demo'],
    );

    if (existingTenant.isNotEmpty) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final passwordHash = PasswordUtils.hashPassword('admin123');

    // ============ TENANT ============
    await db.insert('tenants', {
      'id': tenantId,
      'name': 'POS System',
      'identifier': 'demo',
      'timezone': 'Asia/Jakarta',
      'currency': 'IDR',
      'tax_rate': 0.11,
      'address': 'Jakarta, Indonesia',
      'phone': '081234567890',
      'email': 'admin@pos.com',
      'created_at': now,
      'updated_at': now,
    });

    // ============ SUPER ADMIN USER ============
    await db.insert('users', {
      'id': superAdminId,
      'tenant_id': tenantId,
      'branch_id': null, // Super Admin tidak terikat branch
      'email': 'admin@pos.com',
      'name': 'Super Admin',
      'password_hash': passwordHash,
      'role': 'superAdmin',
      'is_active': 1,
      'created_at':
          DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
    });

    // ============ BRANCHES ============
    await db.insert('branches', {
      'id': branchId1,
      'owner_id': superAdminId,
      'name': 'Cabang Pusat',
      'code': 'CB-001',
      'address': 'Jl. Utama No. 1, Jakarta',
      'phone': '081234567890',
      'tax_rate': 0.11,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('branches', {
      'id': branchId2,
      'owner_id': superAdminId,
      'name': 'Cabang Kemang',
      'code': 'CB-002',
      'address': 'Jl. Kemang Raya No. 45, Jakarta Selatan',
      'phone': '081234567891',
      'tax_rate': 0.11,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // ============ PRODUCTS ============
    final products = [
      {
        'id': '44444444-4444-4444-4444-444444444401',
        'name': 'Espresso',
        'price': 18000.0,
        'cost_price': 5000.0,
        'stock': 100,
        'category': 'Hot Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444402',
        'name': 'Americano',
        'price': 22000.0,
        'cost_price': 6000.0,
        'stock': 100,
        'category': 'Hot Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444403',
        'name': 'Cappuccino',
        'price': 28000.0,
        'cost_price': 9000.0,
        'stock': 100,
        'category': 'Hot Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444404',
        'name': 'Cafe Latte',
        'price': 28000.0,
        'cost_price': 8500.0,
        'stock': 100,
        'category': 'Hot Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444405',
        'name': 'Mocha',
        'price': 32000.0,
        'cost_price': 11000.0,
        'stock': 100,
        'category': 'Hot Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444406',
        'name': 'Iced Americano',
        'price': 25000.0,
        'cost_price': 7000.0,
        'stock': 100,
        'category': 'Iced Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444407',
        'name': 'Iced Latte',
        'price': 30000.0,
        'cost_price': 10000.0,
        'stock': 100,
        'category': 'Iced Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444408',
        'name': 'Iced Mocha',
        'price': 35000.0,
        'cost_price': 12000.0,
        'stock': 100,
        'category': 'Iced Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444409',
        'name': 'Cold Brew',
        'price': 32000.0,
        'cost_price': 8000.0,
        'stock': 100,
        'category': 'Iced Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444410',
        'name': 'Matcha Latte',
        'price': 30000.0,
        'cost_price': 12000.0,
        'stock': 100,
        'category': 'Non-Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444411',
        'name': 'Chocolate',
        'price': 28000.0,
        'cost_price': 9000.0,
        'stock': 100,
        'category': 'Non-Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444412',
        'name': 'Red Velvet',
        'price': 30000.0,
        'cost_price': 11000.0,
        'stock': 100,
        'category': 'Non-Coffee'
      },
      {
        'id': '44444444-4444-4444-4444-444444444413',
        'name': 'Croissant',
        'price': 25000.0,
        'cost_price': 12000.0,
        'stock': 50,
        'category': 'Food'
      },
      {
        'id': '44444444-4444-4444-4444-444444444414',
        'name': 'Sandwich',
        'price': 35000.0,
        'cost_price': 18000.0,
        'stock': 30,
        'category': 'Food'
      },
      {
        'id': '44444444-4444-4444-4444-444444444415',
        'name': 'Cheesecake',
        'price': 38000.0,
        'cost_price': 20000.0,
        'stock': 20,
        'category': 'Food'
      },
      {
        'id': '44444444-4444-4444-4444-444444444416',
        'name': 'Earl Grey Tea',
        'price': 20000.0,
        'cost_price': 4000.0,
        'stock': 50,
        'category': 'Tea'
      },
      {
        'id': '44444444-4444-4444-4444-444444444417',
        'name': 'Green Tea Latte',
        'price': 28000.0,
        'cost_price': 10000.0,
        'stock': 8,
        'category': 'Tea'
      },
      {
        'id': '44444444-4444-4444-4444-444444444418',
        'name': 'Caramel Macchiato',
        'price': 35000.0,
        'cost_price': 13000.0,
        'stock': 5,
        'category': 'Signature Drinks'
      },
      {
        'id': '44444444-4444-4444-4444-444444444419',
        'name': 'Hazelnut Latte',
        'price': 35000.0,
        'cost_price': 14000.0,
        'stock': 0,
        'category': 'Signature Drinks'
      },
      {
        'id': '44444444-4444-4444-4444-444444444420',
        'name': 'Cookies',
        'price': 15000.0,
        'cost_price': 5000.0,
        'stock': 25,
        'category': 'Snacks'
      },
      {
        'id': '44444444-4444-4444-4444-444444444421',
        'name': 'Tiramisu',
        'price': 42000.0,
        'cost_price': 22000.0,
        'stock': 3,
        'category': 'Dessert'
      },
      {
        'id': '44444444-4444-4444-4444-444444444422',
        'name': 'Brownies',
        'price': 28000.0,
        'cost_price': 12000.0,
        'stock': 0,
        'category': 'Dessert'
      },
    ];

    for (var product in products) {
      await db.insert('products', {
        ...product,
        'tenant_id': tenantId,
        'created_at': now,
      });
    }

    // ============ MATERIALS ============
    final materials = [
      {
        'id': '55555555-5555-5555-5555-555555555501',
        'name': 'Biji Kopi Arabica',
        'stock': 10.0,
        'unit': 'kg',
        'min_stock': 3.0,
        'category': 'Biji Kopi'
      },
      {
        'id': '55555555-5555-5555-5555-555555555502',
        'name': 'Biji Kopi Robusta',
        'stock': 5.0,
        'unit': 'kg',
        'min_stock': 2.0,
        'category': 'Biji Kopi'
      },
      {
        'id': '55555555-5555-5555-5555-555555555503',
        'name': 'Susu Fresh Milk',
        'stock': 20.0,
        'unit': 'liter',
        'min_stock': 5.0,
        'category': 'Susu & Dairy'
      },
      {
        'id': '55555555-5555-5555-5555-555555555504',
        'name': 'Whipping Cream',
        'stock': 3.0,
        'unit': 'liter',
        'min_stock': 2.0,
        'category': 'Susu & Dairy'
      },
      {
        'id': '55555555-5555-5555-5555-555555555505',
        'name': 'Gula Pasir',
        'stock': 15.0,
        'unit': 'kg',
        'min_stock': 5.0,
        'category': 'Gula & Pemanis'
      },
      {
        'id': '55555555-5555-5555-5555-555555555506',
        'name': 'Simple Syrup',
        'stock': 2.0,
        'unit': 'liter',
        'min_stock': 1.0,
        'category': 'Gula & Pemanis'
      },
      {
        'id': '55555555-5555-5555-5555-555555555507',
        'name': 'Matcha Powder',
        'stock': 0.5,
        'unit': 'kg',
        'min_stock': 0.3,
        'category': 'Bubuk & Powder'
      },
      {
        'id': '55555555-5555-5555-5555-555555555508',
        'name': 'Coklat Bubuk',
        'stock': 1.0,
        'unit': 'kg',
        'min_stock': 0.5,
        'category': 'Bubuk & Powder'
      },
      {
        'id': '55555555-5555-5555-5555-555555555509',
        'name': 'Caramel Sauce',
        'stock': 0.0,
        'unit': 'botol',
        'min_stock': 2.0,
        'category': 'Sirup & Sauce'
      },
      {
        'id': '55555555-5555-5555-5555-555555555510',
        'name': 'Hazelnut Syrup',
        'stock': 1.0,
        'unit': 'botol',
        'min_stock': 2.0,
        'category': 'Sirup & Sauce'
      },
      {
        'id': '55555555-5555-5555-5555-555555555511',
        'name': 'Earl Grey Tea',
        'stock': 50.0,
        'unit': 'sachet',
        'min_stock': 20.0,
        'category': 'Teh & Herbal'
      },
      {
        'id': '55555555-5555-5555-5555-555555555512',
        'name': 'Cup Plastik 16oz',
        'stock': 200.0,
        'unit': 'pcs',
        'min_stock': 100.0,
        'category': 'Kemasan'
      },
      {
        'id': '55555555-5555-5555-5555-555555555513',
        'name': 'Sedotan',
        'stock': 150.0,
        'unit': 'pcs',
        'min_stock': 100.0,
        'category': 'Kemasan'
      },
    ];

    for (var material in materials) {
      await db.insert('materials', {
        ...material,
        'tenant_id': tenantId,
        'created_at': now,
      });
    }

    // ============ EXPENSES ============
    final expenses = [
      {
        'id': '66666666-6666-6666-6666-666666666601',
        'category': 'Gaji Karyawan',
        'amount': 3500000.0,
        'description': 'Gaji barista dan kasir',
        'days_ago': 1
      },
      {
        'id': '66666666-6666-6666-6666-666666666602',
        'category': 'Listrik',
        'amount': 750000.0,
        'description': 'Tagihan listrik',
        'days_ago': 3
      },
      {
        'id': '66666666-6666-6666-6666-666666666603',
        'category': 'Sewa Tempat',
        'amount': 4500000.0,
        'description': 'Sewa lokasi',
        'days_ago': 2
      },
      {
        'id': '66666666-6666-6666-6666-666666666604',
        'category': 'Pembelian Bahan',
        'amount': 1200000.0,
        'description': 'Beli biji kopi',
        'days_ago': 4
      },
      {
        'id': '66666666-6666-6666-6666-666666666605',
        'category': 'Pembelian Bahan',
        'amount': 350000.0,
        'description': 'Susu fresh milk',
        'days_ago': 5
      },
    ];

    for (var expense in expenses) {
      final daysAgo = expense['days_ago'] as int;
      final date = DateTime.now().subtract(Duration(days: daysAgo));
      await db.insert('expenses', {
        'id': expense['id'],
        'tenant_id': tenantId,
        'branch_id': branchId1,
        'category': expense['category'],
        'amount': expense['amount'],
        'description': expense['description'],
        'date': date.toIso8601String(),
        'created_by': superAdminId,
        'created_at': now,
        'updated_at': null,
      });
    }

    // ============ DISCOUNTS ============
    await db.insert('discounts', {
      'id': '88888888-8888-8888-8888-888888888801',
      'tenant_id': tenantId,
      'branch_id': null,
      'name': 'Diskon Member',
      'type': 'percentage',
      'value': 10.0,
      'min_purchase': null,
      'promo_code': 'MEMBER10',
      'valid_from':
          DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
      'valid_until':
          DateTime.now().add(const Duration(days: 300)).toIso8601String(),
      'is_active': 1,
      'created_by': superAdminId,
      'created_at': now,
      'updated_at': null,
    });

    await db.insert('discounts', {
      'id': '88888888-8888-8888-8888-888888888802',
      'tenant_id': tenantId,
      'branch_id': null,
      'name': 'Potongan Rp 10.000',
      'type': 'fixed',
      'value': 10000.0,
      'min_purchase': 75000.0,
      'promo_code': 'HEMAT10K',
      'valid_from':
          DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      'valid_until':
          DateTime.now().add(const Duration(days: 45)).toIso8601String(),
      'is_active': 1,
      'created_by': superAdminId,
      'created_at': now,
      'updated_at': null,
    });
  }

  /// Reset demo data
  static Future<void> resetDemoData() async {
    final db = await DatabaseHelper.instance.database;

    await db.delete('transactions');
    await db.delete('shifts');
    await db.delete('discounts');
    await db.delete('stock_movements');
    await db.delete('recipes');
    await db.delete('expenses');
    await db.delete('materials');
    await db.delete('products');
    await db.delete('users');
    await db.delete('branches');
    await db.delete('tenants');

    await seedDemoData();
  }
}
