import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import '../../data/models/tenant.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/supabase_service.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/password_utils.dart';
import '../../data/mock/mock_data.dart';

class AuthState {
  final User? user;
  final Tenant? tenant;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.tenant, this.isLoading = false, this.error});

  AuthState copyWith({
    User? user,
    Tenant? tenant,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      tenant: tenant ?? this.tenant,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  static final _mockTenant = Tenant(
    id: '11111111-1111-1111-1111-111111111111',
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

  Future<void> login(String email, String password, String tenantId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (AppConfig.useSupabase) {
        try {
          await _supabaseLogin(email, password, tenantId);
        } catch (e) {
          // Fallback to local database if Supabase fails (offline mode)
          if (!kIsWeb) {
            debugPrint('Supabase login failed, falling back to local: $e');
            await _databaseLogin(email, password, tenantId);
          } else {
            // On web, fallback to mock data
            debugPrint('Supabase login failed, falling back to mock: $e');
            await _mockLogin(email, password, tenantId);
          }
        }
      } else if (kIsWeb) {
        await _mockLogin(email, password, tenantId);
      } else {
        await _databaseLogin(email, password, tenantId);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> _supabaseLogin(
      String email, String password, String tenantId) async {
    final supabase = SupabaseService.instance;

    final tenantData = await supabase.getTenantByIdentifier(tenantId);
    if (tenantData == null) {
      throw Exception('Tenant tidak ditemukan');
    }

    final userData = await supabase.getUserByEmail(email, tenantData['id']);
    if (userData == null) {
      throw Exception('Email tidak ditemukan');
    }

    final storedPassword = userData['password_hash'] as String? ?? '';
    if (!PasswordUtils.verifyPasswordWithMigration(password, storedPassword)) {
      throw Exception('Password salah');
    }

    final isActive = userData['is_active'] == true;
    if (!isActive) {
      throw Exception('Akun Anda telah dinonaktifkan. Hubungi administrator.');
    }

    final user = User(
      id: userData['id'] as String,
      tenantId: userData['tenant_id'] as String,
      branchId: userData['branch_id'] as String?,
      email: userData['email'] as String,
      name: userData['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == userData['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: isActive,
      createdAt: DateTime.parse(userData['created_at'] as String),
    );

    final tenant = Tenant(
      id: tenantData['id'] as String,
      name: tenantData['name'] as String,
      identifier: tenantData['identifier'] as String,
      timezone: tenantData['timezone'] as String? ?? 'Asia/Jakarta',
      currency: tenantData['currency'] as String? ?? 'IDR',
      taxRate: (tenantData['tax_rate'] as num?)?.toDouble() ?? 0.0,
      address: tenantData['address'] as String?,
      phone: tenantData['phone'] as String?,
      email: tenantData['email'] as String?,
      createdAt: DateTime.parse(tenantData['created_at'] as String),
      updatedAt: DateTime.parse(tenantData['updated_at'] as String),
    );

    state = state.copyWith(user: user, tenant: tenant, isLoading: false);
  }

  Future<void> _mockLogin(
      String email, String password, String tenantId) async {
    final mockUsers = MockData.users;

    await Future.delayed(const Duration(milliseconds: 500));

    if (tenantId != 'demo') {
      throw Exception('Tenant tidak ditemukan. Gunakan: demo');
    }

    final user = mockUsers.firstWhere(
      (u) => u.email == email && u.tenantId == MockData.tenantId,
      orElse: () => throw Exception(
        'Email tidak ditemukan.\nGunakan: admin@pos.com',
      ),
    );

    final storedPassword = user.passwordHash ?? '';
    if (storedPassword.isNotEmpty &&
        !PasswordUtils.verifyPasswordWithMigration(password, storedPassword)) {
      throw Exception('Password salah. Gunakan: admin123');
    }

    if (!user.isActive) {
      throw Exception(
        'Akun Anda telah dinonaktifkan. Hubungi administrator.',
      );
    }

    state = state.copyWith(
      user: user,
      tenant: _mockTenant,
      isLoading: false,
    );
  }

  Future<void> _databaseLogin(
      String email, String password, String tenantId) async {
    final db = await DatabaseHelper.instance.database;

    final tenantResult = await db.query(
      'tenants',
      where: 'identifier = ?',
      whereArgs: [tenantId],
    );

    if (tenantResult.isEmpty) {
      throw Exception('Tenant tidak ditemukan');
    }

    final userResult = await db.query(
      'users',
      where: 'email = ? AND tenant_id = ?',
      whereArgs: [email, tenantResult.first['id']],
    );

    if (userResult.isEmpty) {
      throw Exception('Email tidak ditemukan');
    }

    final userMap = userResult.first;

    final storedPassword = userMap['password_hash'] as String? ?? '';
    if (storedPassword.isNotEmpty &&
        !PasswordUtils.verifyPasswordWithMigration(password, storedPassword)) {
      throw Exception('Password salah. Gunakan: admin123');
    }

    final isActive = userMap['is_active'] == 1 || userMap['is_active'] == true;
    if (!isActive) {
      throw Exception(
        'Akun Anda telah dinonaktifkan. Hubungi administrator.',
      );
    }

    final user = User(
      id: userMap['id'] as String,
      tenantId: userMap['tenant_id'] as String,
      branchId: userMap['branch_id'] as String?,
      email: userMap['email'] as String,
      name: userMap['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == userMap['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: isActive,
      createdAt: DateTime.parse(userMap['created_at'] as String),
    );

    final tenantMap = tenantResult.first;
    final tenant = Tenant(
      id: tenantMap['id'] as String,
      name: tenantMap['name'] as String,
      identifier: tenantMap['identifier'] as String,
      timezone: tenantMap['timezone'] as String,
      currency: tenantMap['currency'] as String,
      taxRate: (tenantMap['tax_rate'] as num?)?.toDouble() ?? 0.0,
      address: tenantMap['address'] as String?,
      phone: tenantMap['phone'] as String?,
      email: tenantMap['email'] as String?,
      createdAt: DateTime.parse(tenantMap['created_at'] as String),
      updatedAt: DateTime.parse(tenantMap['updated_at'] as String),
    );

    state = state.copyWith(user: user, tenant: tenant, isLoading: false);
  }

  void logout() {
    state = AuthState();
  }

  void setTenant(Tenant tenant) {
    state = state.copyWith(tenant: tenant);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
