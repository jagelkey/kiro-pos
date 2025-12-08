import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';

/// Helper untuk menjalankan operasi database dalam transaction
/// Memastikan atomicity - semua operasi sukses atau semua rollback
class TransactionHelper {
  /// Execute multiple database operations in a single transaction
  /// All operations succeed together or fail together (rollback)
  static Future<T> executeInTransaction<T>(
    Future<T> Function(DatabaseExecutor txn) action,
  ) async {
    final db = await DatabaseHelper.instance.database;
    return await db.transaction((txn) async {
      return await action(txn);
    });
  }

  /// Execute with retry logic for deadlock scenarios
  static Future<T> executeWithRetry<T>(
    Future<T> Function(DatabaseExecutor txn) action, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await executeInTransaction(action);
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 100 * attempts));
      }
    }
    throw Exception('Transaction failed after $maxRetries attempts');
  }
}
