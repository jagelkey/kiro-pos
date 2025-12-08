#!/usr/bin/env dart

import 'dart:io';
import 'package:uuid/uuid.dart';

/// Client Setup Wizard
/// Automates the process of setting up a new client
///
/// Usage:
/// dart tools/client_setup_wizard.dart

void main() async {
  print('╔════════════════════════════════════════════════════════╗');
  print('║     POS KASIR - CLIENT SETUP WIZARD                   ║');
  print('║     Automated Setup for New Cafe Client               ║');
  print('╚════════════════════════════════════════════════════════╝');
  print('');

  // Step 1: Collect client information
  print('📋 STEP 1: Client Information');
  print('─────────────────────────────────────────────────────────');

  final cafeName = _prompt('Cafe Name', example: 'Cafe ABC');
  final cafeAddress = _prompt('Cafe Address', example: 'Jl. Sudirman No. 123');
  final cafePhone = _prompt('Cafe Phone', example: '081234567890');
  final cafeEmail = _prompt('Cafe Email', example: 'info@cafeabc.com');

  print('');
  print('👤 STEP 2: Owner Information');
  print('─────────────────────────────────────────────────────────');

  final ownerName = _prompt('Owner Name', example: 'John Doe');
  final ownerEmail = _prompt('Owner Email', example: 'owner@cafeabc.com');
  final ownerPassword =
      _prompt('Owner Password', example: 'securepass123', isPassword: true);

  print('');
  print('☁️  STEP 3: Supabase Configuration');
  print('─────────────────────────────────────────────────────────');
  print('ℹ️  Client should have created Supabase project first');
  print('');

  final supabaseUrl =
      _prompt('Supabase URL', example: 'https://xxxxx.supabase.co');
  final supabaseAnonKey = _prompt('Supabase Anon Key', example: 'eyJhbGc...');

  print('');
  print('🎨 STEP 4: Branding (Optional)');
  print('─────────────────────────────────────────────────────────');

  final customColor =
      _prompt('Primary Color (hex)', example: '0xFF8B4513', optional: true);
  final customLogo = _prompt('Logo Path',
      example: 'assets/images/cafe_logo.png', optional: true);

  print('');
  print('📦 STEP 5: Package Selection');
  print('─────────────────────────────────────────────────────────');
  print('1. Basic (Rp 5 juta)');
  print('2. Professional (Rp 10 juta)');
  print('3. Enterprise (Rp 20 juta)');

  final package = _prompt('Select Package', example: '1');

  // Generate IDs
  final tenantId = Uuid().v4();
  final userId = Uuid().v4();
  final branchId = Uuid().v4();
  final identifier =
      cafeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Confirmation
  print('');
  print('✅ STEP 6: Confirmation');
  print('─────────────────────────────────────────────────────────');
  print('Cafe Name: $cafeName');
  print('Owner: $ownerName ($ownerEmail)');
  print('Supabase: ${supabaseUrl.substring(0, 30)}...');
  print('Package: ${_getPackageName(package)}');
  print('');

  final confirm = _prompt('Proceed with setup? (yes/no)', example: 'yes');
  if (confirm.toLowerCase() != 'yes') {
    print('❌ Setup cancelled');
    exit(0);
  }

  // Execute setup
  print('');
  print('🚀 Executing Setup...');
  print('─────────────────────────────────────────────────────────');

  try {
    // 1. Generate SQL setup script
    print('📝 Generating SQL setup script...');
    final sql = _generateSQL(
      tenantId: tenantId,
      userId: userId,
      branchId: branchId,
      cafeName: cafeName,
      cafeAddress: cafeAddress,
      cafePhone: cafePhone,
      cafeEmail: cafeEmail,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      ownerPassword: ownerPassword,
      identifier: identifier,
    );

    final sqlFile = File('setup_$identifier.sql');
    await sqlFile.writeAsString(sql);
    print('   ✓ SQL script saved: ${sqlFile.path}');

    // 2. Generate config files
    print('⚙️  Generating config files...');
    await _generateConfig(
      cafeName: cafeName,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      tenantId: tenantId,
      identifier: identifier,
      customColor: customColor,
    );
    print('   ✓ Config files updated');

    // 3. Generate credentials file
    print('🔑 Generating credentials file...');
    final credentials = _generateCredentials(
      cafeName: cafeName,
      ownerEmail: ownerEmail,
      ownerPassword: ownerPassword,
      identifier: identifier,
      supabaseUrl: supabaseUrl,
    );

    final credFile = File('credentials_$identifier.txt');
    await credFile.writeAsString(credentials);
    print('   ✓ Credentials saved: ${credFile.path}');

    // 4. Generate README
    print('📄 Generating README...');
    final readme = _generateReadme(
      cafeName: cafeName,
      package: _getPackageName(package),
    );

    final readmeFile = File('README_$identifier.txt');
    await readmeFile.writeAsString(readme);
    print('   ✓ README saved: ${readmeFile.path}');

    // Success
    print('');
    print('╔════════════════════════════════════════════════════════╗');
    print('║                 ✅ SETUP COMPLETE!                     ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('');
    print('📁 Generated Files:');
    print('   • ${sqlFile.path}');
    print('   • ${credFile.path}');
    print('   • ${readmeFile.path}');
    print('');
    print('📋 Next Steps:');
    print('   1. Run SQL script in client\'s Supabase dashboard');
    print('   2. Build APK: flutter build apk --release --split-per-abi');
    print('   3. Package files and send to client');
    print('   4. Schedule training session');
    print('');
    print('💡 Tip: Keep these files for your records!');
  } catch (e) {
    print('');
    print('❌ Error during setup: $e');
    exit(1);
  }
}

String _prompt(String label,
    {String? example, bool optional = false, bool isPassword = false}) {
  final optionalText = optional ? ' (optional)' : '';
  final exampleText = example != null ? ' [e.g. $example]' : '';
  stdout.write('$label$optionalText$exampleText: ');

  final input = stdin.readLineSync() ?? '';

  if (!optional && input.isEmpty) {
    print('⚠️  This field is required!');
    return _prompt(label,
        example: example, optional: optional, isPassword: isPassword);
  }

  return input;
}

String _getPackageName(String package) {
  switch (package) {
    case '1':
      return 'Basic (Rp 5 juta)';
    case '2':
      return 'Professional (Rp 10 juta)';
    case '3':
      return 'Enterprise (Rp 20 juta)';
    default:
      return 'Basic (Rp 5 juta)';
  }
}

String _generateSQL({
  required String tenantId,
  required String userId,
  required String branchId,
  required String cafeName,
  required String cafeAddress,
  required String cafePhone,
  required String cafeEmail,
  required String ownerName,
  required String ownerEmail,
  required String ownerPassword,
  required String identifier,
}) {
  // Simple hash for demo (use proper hashing in production)
  final passwordHash = ownerPassword.hashCode.toString();

  return '''
-- ============================================
-- POS KASIR - CLIENT SETUP SQL
-- Client: $cafeName
-- Generated: ${DateTime.now()}
-- ============================================

-- 1. Create Tenant
INSERT INTO tenants (id, name, identifier, timezone, currency, tax_rate, address, phone, email, created_at, updated_at) VALUES
('$tenantId', '$cafeName', '$identifier', 'Asia/Jakarta', 'IDR', 0.11, '$cafeAddress', '$cafePhone', '$cafeEmail', NOW(), NOW());

-- 2. Create Owner User
INSERT INTO users (id, tenant_id, branch_id, email, name, password_hash, role, is_active, created_at) VALUES
('$userId', '$tenantId', NULL, '$ownerEmail', '$ownerName', '$passwordHash', 'owner', true, NOW());

-- 3. Create Main Branch
INSERT INTO branches (id, owner_id, name, code, address, phone, tax_rate, is_active, created_at) VALUES
('$branchId', '$userId', '$cafeName - Main', 'MAIN', '$cafeAddress', '$cafePhone', 0.11, true, NOW());

-- 4. Seed Demo Products (Coffee Shop)
INSERT INTO products (id, tenant_id, name, price, cost_price, stock, category, created_at) VALUES
('${Uuid().v4()}', '$tenantId', 'Espresso', 18000, 5000, 100, 'Hot Coffee', NOW()),
('${Uuid().v4()}', '$tenantId', 'Americano', 22000, 6000, 100, 'Hot Coffee', NOW()),
('${Uuid().v4()}', '$tenantId', 'Cappuccino', 28000, 9000, 100, 'Hot Coffee', NOW()),
('${Uuid().v4()}', '$tenantId', 'Cafe Latte', 28000, 8500, 100, 'Hot Coffee', NOW()),
('${Uuid().v4()}', '$tenantId', 'Iced Americano', 25000, 7000, 100, 'Iced Coffee', NOW()),
('${Uuid().v4()}', '$tenantId', 'Iced Latte', 30000, 10000, 100, 'Iced Coffee', NOW());

-- 5. Seed Demo Materials
INSERT INTO materials (id, tenant_id, name, stock, unit, min_stock, category, created_at) VALUES
('${Uuid().v4()}', '$tenantId', 'Coffee Beans', 10, 'kg', 2, 'Ingredients', NOW()),
('${Uuid().v4()}', '$tenantId', 'Milk', 20, 'liter', 5, 'Ingredients', NOW()),
('${Uuid().v4()}', '$tenantId', 'Sugar', 5, 'kg', 1, 'Ingredients', NOW()),
('${Uuid().v4()}', '$tenantId', 'Paper Cup', 500, 'pcs', 100, 'Packaging', NOW());

-- ============================================
-- SETUP COMPLETE!
-- 
-- Login Credentials:
-- Email: $ownerEmail
-- Password: $ownerPassword
-- Tenant ID: $identifier
-- ============================================
''';
}

Future<void> _generateConfig({
  required String cafeName,
  required String supabaseUrl,
  required String supabaseAnonKey,
  required String tenantId,
  required String identifier,
  String? customColor,
}) async {
  final config = '''
// AUTO-GENERATED CONFIG FOR: $cafeName
// Generated: ${DateTime.now()}
// DO NOT EDIT MANUALLY

class SupabaseConfig {
  static const String supabaseUrl = '$supabaseUrl';
  static const String supabaseAnonKey = '$supabaseAnonKey';
  
  // Client Info
  static const String clientName = '$cafeName';
  static const String tenantId = '$tenantId';
  static const String identifier = '$identifier';
}
''';

  final configFile = File('lib/core/config/supabase_config_$identifier.dart');
  await configFile.writeAsString(config);
}

String _generateCredentials({
  required String cafeName,
  required String ownerEmail,
  required String ownerPassword,
  required String identifier,
  required String supabaseUrl,
}) {
  return '''
═══════════════════════════════════════════════════════
  $cafeName - POS KASIR LOGIN CREDENTIALS
═══════════════════════════════════════════════════════

📱 MOBILE APP LOGIN
───────────────────────────────────────────────────────
Email: $ownerEmail
Password: $ownerPassword
Tenant ID: $identifier

☁️  SUPABASE DASHBOARD
───────────────────────────────────────────────────────
URL: https://app.supabase.com
Project URL: $supabaseUrl

📞 SUPPORT
───────────────────────────────────────────────────────
WhatsApp: +62 812-3456-7890
Email: support@yourcompany.com

⚠️  IMPORTANT NOTES
───────────────────────────────────────────────────────
1. Keep these credentials SECURE
2. Change password after first login
3. Backup your Supabase database regularly
4. Contact support for any issues

═══════════════════════════════════════════════════════
Generated: ${DateTime.now()}
═══════════════════════════════════════════════════════
''';
}

String _generateReadme({
  required String cafeName,
  required String package,
}) {
  return '''
═══════════════════════════════════════════════════════
  $cafeName - POS KASIR SETUP GUIDE
═══════════════════════════════════════════════════════

Package: $package
Setup Date: ${DateTime.now()}

📋 SETUP CHECKLIST
───────────────────────────────────────────────────────
□ Run SQL script in Supabase dashboard
□ Build APK (flutter build apk --release)
□ Test APK on device
□ Send APK to client
□ Send credentials to client
□ Schedule training session
□ Follow up after 1 week

📁 FILES INCLUDED
───────────────────────────────────────────────────────
• setup_*.sql - Database setup script
• credentials_*.txt - Login credentials
• README_*.txt - This file
• APK file (after build)

🚀 QUICK START FOR CLIENT
───────────────────────────────────────────────────────
1. Install APK on Android device
2. Open app
3. Login with provided credentials
4. Start using POS system!

📞 SUPPORT
───────────────────────────────────────────────────────
For any issues, contact:
WhatsApp: +62 812-3456-7890
Email: support@yourcompany.com

═══════════════════════════════════════════════════════
''';
}
