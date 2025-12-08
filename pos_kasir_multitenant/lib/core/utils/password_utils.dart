import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for password hashing and verification
/// Uses SHA-256 with salt for secure password storage
class PasswordUtils {
  /// Salt for password hashing (in production, use unique salt per user)
  static const String _salt = 'pos_kasir_multitenant_2024';

  /// Hash a password using SHA-256 with salt
  /// Returns the hashed password as a hex string
  static String hashPassword(String password) {
    final saltedPassword = '$_salt$password$_salt';
    final bytes = utf8.encode(saltedPassword);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a password against a stored hash
  /// Returns true if the password matches the hash
  static bool verifyPassword(String password, String storedHash) {
    final hashedPassword = hashPassword(password);
    return hashedPassword == storedHash;
  }

  /// Check if a stored password is already hashed (64 char hex string)
  /// This helps with migration from plain text to hashed passwords
  static bool isHashed(String password) {
    // SHA-256 produces 64 character hex string
    if (password.length != 64) return false;
    // Check if it's a valid hex string
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(password);
  }

  /// Verify password with backward compatibility for plain text passwords
  /// This allows gradual migration from plain text to hashed passwords
  static bool verifyPasswordWithMigration(
      String inputPassword, String storedPassword) {
    // If stored password is already hashed, verify against hash
    if (isHashed(storedPassword)) {
      return verifyPassword(inputPassword, storedPassword);
    }

    // Otherwise, compare plain text (for backward compatibility)
    // This handles legacy passwords that haven't been migrated yet
    return inputPassword == storedPassword;
  }
}
