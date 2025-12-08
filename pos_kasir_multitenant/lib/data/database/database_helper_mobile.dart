import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Check if running on web platform
  bool get isWeb => kIsWeb;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on web. Use mock data instead.',
      );
    }

    if (_database != null) return _database!;
    _database = await _initDB('pos_multitenant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Tenants table
    await db.execute('''
      CREATE TABLE tenants (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        identifier TEXT UNIQUE NOT NULL,
        logo_url TEXT,
        timezone TEXT NOT NULL,
        currency TEXT NOT NULL,
        tax_rate REAL DEFAULT 0.0,
        address TEXT,
        phone TEXT,
        email TEXT,
        settings TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Users table - Multi-tenant dengan branch support
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        branch_id TEXT,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT,
        role TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (branch_id) REFERENCES branches (id)
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        cost_price REAL DEFAULT 0,
        stock INTEGER NOT NULL,
        category TEXT,
        image_url TEXT,
        composition TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id)
      )
    ''');

    // Materials table
    await db.execute('''
      CREATE TABLE materials (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        stock REAL NOT NULL,
        unit TEXT NOT NULL,
        min_stock REAL,
        category TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id)
      )
    ''');

    // Transactions table
    // Requirements 13.5: Associate transactions with shift
    // Requirements 14.6: Associate transactions with discount
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        shift_id TEXT,
        discount_id TEXT,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (shift_id) REFERENCES shifts (id),
        FOREIGN KEY (discount_id) REFERENCES discounts (id)
      )
    ''');

    // Recipes table - stores product recipes with multi-tenant support
    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        preparation_time INTEGER,
        difficulty TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        UNIQUE(tenant_id, product_id)
      )
    ''');

    // Expenses table - Multi-tenant and multi-branch support
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        branch_id TEXT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (branch_id) REFERENCES branches (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Stock movements table - tracks all material stock changes
    // Requirements 3.2: Record stock movement with timestamp and reason
    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        material_id TEXT NOT NULL,
        previous_stock REAL NOT NULL,
        new_stock REAL NOT NULL,
        change REAL NOT NULL,
        reason TEXT NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');

    // Shifts table - for cashier shift management
    // Requirements 13.1, 13.2, 13.3: Shift management
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        opening_cash REAL NOT NULL,
        closing_cash REAL,
        expected_cash REAL,
        variance REAL,
        variance_note TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Discounts table - for promotions and discounts
    // Requirements 14.1: Save discount details
    // Multi-branch support: branch_id for branch-specific discounts
    await db.execute('''
      CREATE TABLE discounts (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        branch_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        min_purchase REAL,
        promo_code TEXT,
        valid_from TEXT NOT NULL,
        valid_until TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id),
        FOREIGN KEY (branch_id) REFERENCES branches (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Branches table - for multi-branch support
    // Requirements 11.1, 11.3: Branch management with unique code
    await db.execute('''
      CREATE TABLE branches (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT UNIQUE NOT NULL,
        address TEXT,
        phone TEXT,
        tax_rate REAL DEFAULT 0.11,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (owner_id) REFERENCES users (id)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_users_tenant ON users(tenant_id)');
    await db.execute('CREATE INDEX idx_products_tenant ON products(tenant_id)');
    await db.execute(
      'CREATE INDEX idx_materials_tenant ON materials(tenant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_tenant ON transactions(tenant_id)',
    );
    await db.execute('CREATE INDEX idx_expenses_tenant ON expenses(tenant_id)');
    await db.execute(
      'CREATE INDEX idx_expenses_branch ON expenses(branch_id)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_date ON expenses(date)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_material ON stock_movements(material_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_tenant ON stock_movements(tenant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_shifts_tenant ON shifts(tenant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_shifts_user ON shifts(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_shifts_status ON shifts(status)',
    );
    await db.execute(
      'CREATE INDEX idx_discounts_tenant ON discounts(tenant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_discounts_branch ON discounts(branch_id)',
    );
    await db.execute(
      'CREATE INDEX idx_discounts_promo_code ON discounts(promo_code)',
    );
    await db.execute(
      'CREATE INDEX idx_discounts_valid_dates ON discounts(valid_from, valid_until)',
    );
    await db.execute(
      'CREATE INDEX idx_branches_owner ON branches(owner_id)',
    );
    await db.execute(
      'CREATE INDEX idx_branches_code ON branches(code)',
    );
    await db.execute(
      'CREATE INDEX idx_recipes_tenant ON recipes(tenant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_recipes_product ON recipes(product_id)',
    );

    // Sync queue table - for offline-first sync
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        operation_type TEXT NOT NULL CHECK(operation_type IN ('insert', 'update', 'delete')),
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sync_queue_created_at ON sync_queue(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)',
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
