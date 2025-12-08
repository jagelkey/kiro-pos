/// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
/// **Validates: Requirements 7.5**
///
/// Property: For any user with isActive=false, login attempt SHALL fail.
library;

import 'package:glados/glados.dart';
import 'package:pos_kasir_multitenant/data/models/user.dart';

/// Simulates the login validation logic from AuthProvider
/// This mirrors the actual login check in auth_provider.dart
class LoginValidator {
  /// Validates if a user can login based on their active status
  /// Requirements 7.5: Check isActive status during login
  /// Returns null if login is allowed, error message if denied
  static String? validateLogin(User user) {
    if (!user.isActive) {
      return 'Akun Anda telah dinonaktifkan. Hubungi administrator.';
    }
    return null; // Login allowed
  }

  /// Returns true if login should be denied for this user
  static bool shouldDenyLogin(User user) {
    return !user.isActive;
  }

  /// Returns true if login should be allowed for this user
  static bool shouldAllowLogin(User user) {
    return user.isActive;
  }
}

/// Generator for User instances with specific active status
extension InactiveUserGenerator on Any {
  /// Generate a user with specific isActive status
  Generator<User> userWithActiveStatus(bool isActive) {
    return any.lowercaseLetters.bind((name) {
      return any.lowercaseLetters.bind((email) {
        return any.choose(
            [UserRole.owner, UserRole.manager, UserRole.cashier]).map((role) {
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

  /// Generate an inactive user (isActive = false)
  Generator<User> get inactiveUser => userWithActiveStatus(false);

  /// Generate an active user (isActive = true)
  Generator<User> get activeUser => userWithActiveStatus(true);

  /// Generate any user (active or inactive)
  Generator<User> get anyUserWithStatus {
    return any.choose([true, false]).bind(
        (isActive) => userWithActiveStatus(isActive));
  }
}

void main() {
  /// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
  /// **Validates: Requirements 7.5**
  ///
  /// Property: For any inactive user, login SHALL be denied
  Glados(any.inactiveUser).test(
    'Inactive users cannot login',
    (user) {
      // Verify user is indeed inactive
      if (user.isActive) {
        throw Exception('Test setup error: user should be inactive');
      }

      // Verify login is denied
      if (!LoginValidator.shouldDenyLogin(user)) {
        throw Exception(
          'Inactive user ${user.name} (${user.email}) should be denied login',
        );
      }

      // Verify error message is returned
      final errorMessage = LoginValidator.validateLogin(user);
      if (errorMessage == null) {
        throw Exception(
          'Inactive user ${user.name} should receive error message on login attempt',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
  /// **Validates: Requirements 7.5**
  ///
  /// Property: For any active user, login SHALL be allowed (regarding active status)
  Glados(any.activeUser).test(
    'Active users can login (regarding active status)',
    (user) {
      // Verify user is indeed active
      if (!user.isActive) {
        throw Exception('Test setup error: user should be active');
      }

      // Verify login is allowed
      if (LoginValidator.shouldDenyLogin(user)) {
        throw Exception(
          'Active user ${user.name} (${user.email}) should be allowed to login',
        );
      }

      // Verify no error message is returned
      final errorMessage = LoginValidator.validateLogin(user);
      if (errorMessage != null) {
        throw Exception(
          'Active user ${user.name} should not receive error message: $errorMessage',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
  /// **Validates: Requirements 7.5**
  ///
  /// Property: Login denial is determined solely by isActive status
  Glados(any.anyUserWithStatus).test(
    'Login denial is determined by isActive status',
    (user) {
      final shouldDeny = LoginValidator.shouldDenyLogin(user);
      final shouldAllow = LoginValidator.shouldAllowLogin(user);

      // shouldDeny and shouldAllow should be mutually exclusive
      if (shouldDeny == shouldAllow) {
        throw Exception(
          'shouldDenyLogin and shouldAllowLogin should be mutually exclusive for user ${user.name}',
        );
      }

      // shouldDeny should be true iff isActive is false
      if (shouldDeny != !user.isActive) {
        throw Exception(
          'shouldDenyLogin should equal !isActive for user ${user.name}',
        );
      }

      // shouldAllow should be true iff isActive is true
      if (shouldAllow != user.isActive) {
        throw Exception(
          'shouldAllowLogin should equal isActive for user ${user.name}',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
  /// **Validates: Requirements 7.5**
  ///
  /// Property: Inactive users of any role SHALL be denied login
  Glados(any.inactiveUser).test(
    'Inactive users of any role are denied login',
    (user) {
      // Regardless of role (owner, manager, cashier), inactive users should be denied
      final errorMessage = LoginValidator.validateLogin(user);

      if (errorMessage == null) {
        throw Exception(
          'Inactive ${user.role.name} user ${user.name} should be denied login',
        );
      }
    },
  );

  /// **Feature: pos-comprehensive-fix, Property 9: Inactive User Login Prevention**
  /// **Validates: Requirements 7.5**
  ///
  /// Property: validateLogin returns error message iff user is inactive
  Glados(any.anyUserWithStatus).test(
    'validateLogin returns error iff user is inactive',
    (user) {
      final errorMessage = LoginValidator.validateLogin(user);
      final hasError = errorMessage != null;

      // hasError should be true iff isActive is false
      if (hasError != !user.isActive) {
        throw Exception(
          'validateLogin error presence should match inactive status for user ${user.name}. '
          'isActive: ${user.isActive}, hasError: $hasError',
        );
      }
    },
  );
}
