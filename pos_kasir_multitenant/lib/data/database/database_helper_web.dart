/// Web implementation of DatabaseHelper
/// On web, we use mock data instead of SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  /// Check if running on web platform
  bool get isWeb => true;

  /// Database getter - throws on web since SQLite is not supported
  Future<dynamic> get database async {
    throw UnsupportedError(
      'SQLite is not supported on web. Use mock data or Supabase instead.',
    );
  }

  Future<void> close() async {
    // No-op for web
  }
}
