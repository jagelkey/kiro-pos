import '../../data/models/user.dart';
import '../../data/models/tenant.dart';
import '../../features/auth/auth_provider.dart';

/// Authentication guard utilities
/// Prevents null pointer exceptions from auth state
class AuthGuard {
  /// Require authenticated user, throw if null
  static User requireUser(AuthState authState) {
    final user = authState.user;
    if (user == null) {
      throw AuthException('User tidak terautentikasi. Silakan login ulang.');
    }
    return user;
  }

  /// Require tenant, throw if null
  static Tenant requireTenant(AuthState authState) {
    final tenant = authState.tenant;
    if (tenant == null) {
      throw AuthException('Tenant tidak ditemukan. Silakan login ulang.');
    }
    return tenant;
  }

  /// Require both user and tenant
  static AuthContext requireAuth(AuthState authState) {
    final user = requireUser(authState);
    final tenant = requireTenant(authState);
    return AuthContext(user: user, tenant: tenant);
  }

  /// Check if user has required role
  static void requireRole(User user, List<UserRole> allowedRoles) {
    if (!allowedRoles.contains(user.role)) {
      throw AuthException('Anda tidak memiliki akses ke fitur ini. '
          'Diperlukan role: ${allowedRoles.map((r) => r.name).join(", ")}');
    }
  }

  /// Check if user is owner
  static bool isOwner(User user) {
    return user.role == UserRole.owner;
  }

  /// Check if user is manager or owner
  static bool isManagerOrOwner(User user) {
    return user.role == UserRole.manager || user.role == UserRole.owner;
  }

  /// Check if user is active
  static void requireActive(User user) {
    if (!user.isActive) {
      throw AuthException(
          'Akun Anda telah dinonaktifkan. Silakan hubungi administrator.');
    }
  }

  /// Validate tenant ID is not empty
  static void validateTenantId(String tenantId) {
    if (tenantId.isEmpty) {
      throw AuthException('ID Tenant tidak valid');
    }
  }

  /// Validate user ID is not empty
  static void validateUserId(String userId) {
    if (userId.isEmpty) {
      throw AuthException('ID User tidak valid');
    }
  }
}

/// Authentication context with user and tenant
class AuthContext {
  final User user;
  final Tenant tenant;

  AuthContext({required this.user, required this.tenant});

  String get userId => user.id;
  String get tenantId => tenant.id;
  UserRole get userRole => user.role;

  bool get isOwner => user.role == UserRole.owner;
  bool get isManager => user.role == UserRole.manager;
  bool get isCashier => user.role == UserRole.cashier;
  bool get isManagerOrOwner => isManager || isOwner;
}

/// Authentication exception
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
