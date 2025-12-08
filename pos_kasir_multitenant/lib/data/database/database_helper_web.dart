import 'package:sqflite_common/sqlite_api.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Check if running on web platform
  bool get isWeb => true;

  Future<Database> get database async {
    throw UnsupportedError(
      'SQLite is not supported on web. Use mock data instead.',
    );
  }

  Future<void> close() async {
    // No-op for web
  }
}
