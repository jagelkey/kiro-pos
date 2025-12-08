import '../models/product.dart';
import '../models/material.dart' as mat;
import '../models/expense.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/branch.dart';
import '../models/discount.dart';
import '../../core/utils/password_utils.dart';

class MockData {
  static const String tenantId = '11111111-1111-1111-1111-111111111111';
  static const String branchId1 = '33333333-3333-3333-3333-333333333301';
  static const String branchId2 = '33333333-3333-3333-3333-333333333302';

  // Pre-computed hash for passwords
  static final String _adminPasswordHash =
      PasswordUtils.hashPassword('admin123');
  static final String _demoPasswordHash =
      PasswordUtils.hashPassword('password');

  // Demo users with different roles
  static final List<User> users = [
    // Super Admin
    User(
      id: '22222222-2222-2222-2222-222222222200',
      tenantId: tenantId,
      branchId: null,
      email: 'admin@pos.com',
      name: 'Super Admin',
      passwordHash: _adminPasswordHash, // Password: admin123
      role: UserRole.superAdmin,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    // Owner
    User(
      id: '22222222-2222-2222-2222-222222222201',
      tenantId: tenantId,
      branchId: null,
      email: 'owner@demo.com',
      name: 'Demo Owner',
      passwordHash: _demoPasswordHash, // Password: password
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
    ),
    // Manager
    User(
      id: '22222222-2222-2222-2222-222222222202',
      tenantId: tenantId,
      branchId: branchId1,
      email: 'manager@demo.com',
      name: 'Demo Manager',
      passwordHash: _demoPasswordHash, // Password: password
      role: UserRole.manager,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    // Kasir
    User(
      id: '22222222-2222-2222-2222-222222222203',
      tenantId: tenantId,
      branchId: branchId1,
      email: 'kasir@demo.com',
      name: 'Demo Kasir',
      passwordHash: _demoPasswordHash, // Password: password
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  // Coffee Shop Products with Cost Price
  static final List<Product> products = [
    // Hot Coffee
    Product(
      id: '44444444-4444-4444-4444-444444444401',
      tenantId: tenantId,
      name: 'Espresso',
      price: 18000,
      costPrice: 5000,
      stock: 100,
      category: 'Hot Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444402',
      tenantId: tenantId,
      name: 'Americano',
      price: 22000,
      costPrice: 6000,
      stock: 100,
      category: 'Hot Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444403',
      tenantId: tenantId,
      name: 'Cappuccino',
      price: 28000,
      costPrice: 9000,
      stock: 100,
      category: 'Hot Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444404',
      tenantId: tenantId,
      name: 'Cafe Latte',
      price: 28000,
      costPrice: 8500,
      stock: 100,
      category: 'Hot Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444405',
      tenantId: tenantId,
      name: 'Mocha',
      price: 32000,
      costPrice: 11000,
      stock: 100,
      category: 'Hot Coffee',
      createdAt: DateTime.now(),
    ),
    // Iced Coffee
    Product(
      id: '44444444-4444-4444-4444-444444444406',
      tenantId: tenantId,
      name: 'Iced Americano',
      price: 25000,
      costPrice: 7000,
      stock: 100,
      category: 'Iced Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444407',
      tenantId: tenantId,
      name: 'Iced Latte',
      price: 30000,
      costPrice: 10000,
      stock: 100,
      category: 'Iced Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444408',
      tenantId: tenantId,
      name: 'Iced Mocha',
      price: 35000,
      costPrice: 12000,
      stock: 100,
      category: 'Iced Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444409',
      tenantId: tenantId,
      name: 'Cold Brew',
      price: 32000,
      costPrice: 8000,
      stock: 100,
      category: 'Iced Coffee',
      createdAt: DateTime.now(),
    ),
    // Non-Coffee
    Product(
      id: '44444444-4444-4444-4444-444444444410',
      tenantId: tenantId,
      name: 'Matcha Latte',
      price: 30000,
      costPrice: 12000,
      stock: 100,
      category: 'Non-Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444411',
      tenantId: tenantId,
      name: 'Chocolate',
      price: 28000,
      costPrice: 9000,
      stock: 100,
      category: 'Non-Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444412',
      tenantId: tenantId,
      name: 'Red Velvet',
      price: 30000,
      costPrice: 11000,
      stock: 100,
      category: 'Non-Coffee',
      createdAt: DateTime.now(),
    ),
    // Food
    Product(
      id: '44444444-4444-4444-4444-444444444413',
      tenantId: tenantId,
      name: 'Croissant',
      price: 25000,
      costPrice: 12000,
      stock: 50,
      category: 'Food',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444414',
      tenantId: tenantId,
      name: 'Sandwich',
      price: 35000,
      costPrice: 18000,
      stock: 30,
      category: 'Food',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444415',
      tenantId: tenantId,
      name: 'Cheesecake',
      price: 38000,
      costPrice: 20000,
      stock: 20,
      category: 'Food',
      createdAt: DateTime.now(),
    ),
    // Tea
    Product(
      id: '44444444-4444-4444-4444-444444444416',
      tenantId: tenantId,
      name: 'Earl Grey Tea',
      price: 20000,
      costPrice: 4000,
      stock: 50,
      category: 'Tea',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444417',
      tenantId: tenantId,
      name: 'Green Tea Latte',
      price: 28000,
      costPrice: 10000,
      stock: 8,
      category: 'Tea',
      createdAt: DateTime.now(),
    ),
    // Signature Drinks
    Product(
      id: '44444444-4444-4444-4444-444444444418',
      tenantId: tenantId,
      name: 'Caramel Macchiato',
      price: 35000,
      costPrice: 13000,
      stock: 5,
      category: 'Signature Drinks',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444419',
      tenantId: tenantId,
      name: 'Hazelnut Latte',
      price: 35000,
      costPrice: 14000,
      stock: 0,
      category: 'Signature Drinks',
      createdAt: DateTime.now(),
    ),
    // Snacks
    Product(
      id: '44444444-4444-4444-4444-444444444420',
      tenantId: tenantId,
      name: 'Cookies',
      price: 15000,
      costPrice: 5000,
      stock: 25,
      category: 'Snacks',
      createdAt: DateTime.now(),
    ),
    // Dessert
    Product(
      id: '44444444-4444-4444-4444-444444444421',
      tenantId: tenantId,
      name: 'Tiramisu',
      price: 42000,
      costPrice: 22000,
      stock: 3,
      category: 'Dessert',
      createdAt: DateTime.now(),
    ),
    Product(
      id: '44444444-4444-4444-4444-444444444422',
      tenantId: tenantId,
      name: 'Brownies',
      price: 28000,
      costPrice: 12000,
      stock: 0,
      category: 'Dessert',
      createdAt: DateTime.now(),
    ),
  ];

  // Materials
  static final List<mat.Material> materials = [
    mat.Material(
      id: '55555555-5555-5555-5555-555555555501',
      tenantId: tenantId,
      name: 'Biji Kopi Arabica',
      stock: 10,
      unit: 'kg',
      minStock: 3,
      category: 'Biji Kopi',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555502',
      tenantId: tenantId,
      name: 'Biji Kopi Robusta',
      stock: 5,
      unit: 'kg',
      minStock: 2,
      category: 'Biji Kopi',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555503',
      tenantId: tenantId,
      name: 'Susu Fresh Milk',
      stock: 20,
      unit: 'liter',
      minStock: 5,
      category: 'Susu & Dairy',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555504',
      tenantId: tenantId,
      name: 'Whipping Cream',
      stock: 3,
      unit: 'liter',
      minStock: 2,
      category: 'Susu & Dairy',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555505',
      tenantId: tenantId,
      name: 'Gula Pasir',
      stock: 15,
      unit: 'kg',
      minStock: 5,
      category: 'Gula & Pemanis',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555506',
      tenantId: tenantId,
      name: 'Simple Syrup',
      stock: 2,
      unit: 'liter',
      minStock: 1,
      category: 'Gula & Pemanis',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555507',
      tenantId: tenantId,
      name: 'Matcha Powder',
      stock: 0.5,
      unit: 'kg',
      minStock: 0.3,
      category: 'Bubuk & Powder',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555508',
      tenantId: tenantId,
      name: 'Coklat Bubuk',
      stock: 1,
      unit: 'kg',
      minStock: 0.5,
      category: 'Bubuk & Powder',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555509',
      tenantId: tenantId,
      name: 'Caramel Sauce',
      stock: 0,
      unit: 'botol',
      minStock: 2,
      category: 'Sirup & Sauce',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555510',
      tenantId: tenantId,
      name: 'Hazelnut Syrup',
      stock: 1,
      unit: 'botol',
      minStock: 2,
      category: 'Sirup & Sauce',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555511',
      tenantId: tenantId,
      name: 'Earl Grey Tea',
      stock: 50,
      unit: 'sachet',
      minStock: 20,
      category: 'Teh & Herbal',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555512',
      tenantId: tenantId,
      name: 'Cup Plastik 16oz',
      stock: 200,
      unit: 'pcs',
      minStock: 100,
      category: 'Kemasan',
      createdAt: DateTime.now(),
    ),
    mat.Material(
      id: '55555555-5555-5555-5555-555555555513',
      tenantId: tenantId,
      name: 'Sedotan',
      stock: 150,
      unit: 'pcs',
      minStock: 100,
      category: 'Kemasan',
      createdAt: DateTime.now(),
    ),
  ];

  // Expenses
  static final List<Expense> expenses = [
    Expense(
        id: '66666666-6666-6666-6666-666666666601',
        tenantId: tenantId,
        category: 'Gaji Karyawan',
        amount: 3500000,
        description: 'Gaji barista dan kasir',
        date: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now()),
    Expense(
        id: '66666666-6666-6666-6666-666666666602',
        tenantId: tenantId,
        category: 'Listrik',
        amount: 750000,
        description: 'Tagihan listrik mesin espresso & AC',
        date: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now()),
    Expense(
        id: '66666666-6666-6666-6666-666666666603',
        tenantId: tenantId,
        category: 'Sewa Tempat',
        amount: 4500000,
        description: 'Sewa lokasi bulan ini',
        date: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now()),
    Expense(
        id: '66666666-6666-6666-6666-666666666604',
        tenantId: tenantId,
        category: 'Pembelian Bahan',
        amount: 1200000,
        description: 'Beli biji kopi arabica',
        date: DateTime.now().subtract(const Duration(days: 4)),
        createdAt: DateTime.now()),
    Expense(
        id: '66666666-6666-6666-6666-666666666605',
        tenantId: tenantId,
        category: 'Pembelian Bahan',
        amount: 350000,
        description: 'Susu fresh milk',
        date: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now()),
  ];

  // Transactions (empty for fresh start)
  static final List<Transaction> transactions = [];

  // Branches
  static final List<Branch> branches = [
    Branch(
      id: branchId1,
      ownerId: '22222222-2222-2222-2222-222222222200', // Super Admin
      name: 'Cabang Pusat',
      code: 'CB-001',
      address: 'Jl. Utama No. 1, Jakarta',
      phone: '081234567890',
      taxRate: 0.11,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    Branch(
      id: branchId2,
      ownerId: '22222222-2222-2222-2222-222222222200', // Super Admin
      name: 'Cabang Kemang',
      code: 'CB-002',
      address: 'Jl. Kemang Raya No. 45, Jakarta Selatan',
      phone: '081234567891',
      taxRate: 0.11,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
    ),
  ];

  // Discounts
  static final List<Discount> discounts = [
    Discount(
      id: '88888888-8888-8888-8888-888888888801',
      tenantId: tenantId,
      name: 'Diskon Member',
      type: DiscountType.percentage,
      value: 10,
      minPurchase: null,
      promoCode: 'MEMBER10',
      validFrom: DateTime.now().subtract(const Duration(days: 60)),
      validUntil: DateTime.now().add(const Duration(days: 300)),
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    Discount(
      id: '88888888-8888-8888-8888-888888888802',
      tenantId: tenantId,
      name: 'Potongan Rp 10.000',
      type: DiscountType.fixed,
      value: 10000,
      minPurchase: 75000,
      promoCode: 'HEMAT10K',
      validFrom: DateTime.now().subtract(const Duration(days: 15)),
      validUntil: DateTime.now().add(const Duration(days: 45)),
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];
}
