// Supabase Configuration
// IMPORTANT: In production, use environment variables or secure storage

class SupabaseConfig {
  static const String supabaseUrl = 'https://kpruoenqrnrgktpthxdb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwcnVvZW5xcm5yZ2t0cHRoeGRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5OTYyMDksImV4cCI6MjA4MDU3MjIwOX0.lkb2DX3M4eGGL-Dk4lCjPULSRHZ2bxdoVTRjMiigeyk';

  // Tables
  static const String tenantsTable = 'tenants';
  static const String usersTable = 'users';
  static const String productsTable = 'products';
  static const String materialsTable = 'materials';
  static const String transactionsTable = 'transactions';
  static const String expensesTable = 'expenses';
  static const String stockMovementsTable = 'stock_movements';
  static const String shiftsTable = 'shifts';
  static const String discountsTable = 'discounts';
  static const String branchesTable = 'branches';
  static const String recipesTable = 'recipes';
}
