/// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
/// **Validates: Requirements 7.3**
///
/// Property: For any user with cashier role, access to owner-only features
/// SHALL be denied.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/user.dart';

/// Generator for valid User instances with specific role
extension UserGenerator on Any {
  Generator<User> userWithRole(UserRole role) {
    return any.lowercaseLetters.bind((name) {
      return any.lowercaseLetters.bind((email) {
        return any.choose([true, false]).map((isActive) {
          return User(
            id: 'user-${name.hashCode.abs()}',
            tenantId: 'tenant-test',
            email: email.isEmpty ? 'test@test.com' : '$email@test.com',
            name: name.isEmpty ? 'Test User' : name,
            role: role,
            isActive: isActive,
            createdAt: DateTime(2024, 1, 1),
          );
        });
      });
    });
  }

  Generator<User> get ownerUser => userWithRole(UserRole.owner);
  Generator<User> get managerUser => userWithRole(UserRole.manager);
  Generator<User> get cashierUser => userWithRole(UserRole.cashier);

  Generator<User> get anyUser {
    return any
        .choose([UserRole.owner, UserRole.manager, UserRole.cashier]).bind(
      (role) => userWithRole(role),
    );
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Cashier users SHALL NOT have owner access
  Glados(any.cashierUser).test(
    'Cashier users do not have owner access',
    (user) {
      if (user.hasOwnerAccess) {
        throw Exception(
          'Cashier user ${user.name} should not have owner access',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Cashier users SHALL NOT have manager access
  Glados(any.cashierUser).test(
    'Cashier users do not have manager access',
    (user) {
      if (user.hasManagerAccess) {
        throw Exception(
          'Cashier user ${user.name} should not have manager access',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Cashier users SHALL NOT be able to access owner-level features
  Glados(any.cashierUser).test(
    'Cashier users cannot access owner-level features',
    (user) {
      if (user.canAccess(UserRole.owner)) {
        throw Exception(
          'Cashier user ${user.name} should not be able to access owner-level features',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Cashier users SHALL NOT be able to access manager-level features
  Glados(any.cashierUser).test(
    'Cashier users cannot access manager-level features',
    (user) {
      if (user.canAccess(UserRole.manager)) {
        throw Exception(
          'Cashier user ${user.name} should not be able to access manager-level features',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: All users (including cashiers) SHALL be able to access cashier-level features
  Glados(any.anyUser).test(
    'All users can access cashier-level features',
    (user) {
      if (!user.canAccess(UserRole.cashier)) {
        throw Exception(
          'User ${user.name} with role ${user.role} should be able to access cashier-level features',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Owner users SHALL have owner access
  Glados(any.ownerUser).test(
    'Owner users have owner access',
    (user) {
      if (!user.hasOwnerAccess) {
        throw Exception(
          'Owner user ${user.name} should have owner access',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Owner users SHALL have manager access
  Glados(any.ownerUser).test(
    'Owner users have manager access',
    (user) {
      if (!user.hasManagerAccess) {
        throw Exception(
          'Owner user ${user.name} should have manager access',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Manager users SHALL have manager access but NOT owner access
  Glados(any.managerUser).test(
    'Manager users have manager access but not owner access',
    (user) {
      if (!user.hasManagerAccess) {
        throw Exception(
          'Manager user ${user.name} should have manager access',
        );
      }
      if (user.hasOwnerAccess) {
        throw Exception(
          'Manager user ${user.name} should not have owner access',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Owner users SHALL be able to access all feature levels
  Glados(any.ownerUser).test(
    'Owner users can access all feature levels',
    (user) {
      if (!user.canAccess(UserRole.owner)) {
        throw Exception(
          'Owner user ${user.name} should be able to access owner-level features',
        );
      }
      if (!user.canAccess(UserRole.manager)) {
        throw Exception(
          'Owner user ${user.name} should be able to access manager-level features',
        );
      }
      if (!user.canAccess(UserRole.cashier)) {
        throw Exception(
          'Owner user ${user.name} should be able to access cashier-level features',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Manager users SHALL be able to access manager and cashier levels only
  Glados(any.managerUser).test(
    'Manager users can access manager and cashier levels only',
    (user) {
      if (user.canAccess(UserRole.owner)) {
        throw Exception(
          'Manager user ${user.name} should not be able to access owner-level features',
        );
      }
      if (!user.canAccess(UserRole.manager)) {
        throw Exception(
          'Manager user ${user.name} should be able to access manager-level features',
        );
      }
      if (!user.canAccess(UserRole.cashier)) {
        throw Exception(
          'Manager user ${user.name} should be able to access cashier-level features',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 8: User Role Authorization**
  /// **Validates: Requirements 7.3**
  ///
  /// Property: Role helper properties are consistent with role enum
  Glados(any.anyUser).test(
    'Role helper properties are consistent with role enum',
    (user) {
      // isOwner should be true iff role is owner
      if (user.isOwner != (user.role == UserRole.owner)) {
        throw Exception(
          'isOwner property inconsistent for user ${user.name} with role ${user.role}',
        );
      }
      // isManager should be true iff role is manager
      if (user.isManager != (user.role == UserRole.manager)) {
        throw Exception(
          'isManager property inconsistent for user ${user.name} with role ${user.role}',
        );
      }
      // isCashier should be true iff role is cashier
      if (user.isCashier != (user.role == UserRole.cashier)) {
        throw Exception(
          'isCashier property inconsistent for user ${user.name} with role ${user.role}',
        );
      }
    },
  );
}
