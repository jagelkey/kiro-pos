import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_config.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/products/products_screen.dart';
import 'features/materials/materials_screen.dart';
import 'features/recipes/recipes_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/shift/shift_screen.dart';
import 'features/discounts/discount_screen.dart';
import 'features/branches/branch_screen.dart';
import 'features/users/users_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/more/more_menu_screen.dart';
import 'shared/widgets/main_layout.dart';
import 'data/database/demo_seeder.dart';
import 'data/services/supabase_service.dart';
import 'data/services/demo_seeder_service.dart';
import 'core/services/sync_manager.dart';

/// Production mode flag - set to true for production release
const bool kProductionMode = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase for cloud sync
  try {
    await SupabaseService.initialize();
    AppConfig.useSupabase = true;
    debugPrint('✅ Supabase initialized successfully');

    // Initialize Sync Manager for offline-first sync
    await SyncManager.instance.initialize();
    debugPrint('✅ Sync Manager initialized successfully');

    // Seed cloud demo data if needed
    if (AppConfig.useSupabase) {
      await DemoSeederService.instance.seedDemoData();
    }
  } catch (e) {
    debugPrint('⚠️ Supabase initialization failed: $e');
    debugPrint('📱 Falling back to local SQLite database');
    AppConfig.useSupabase = false;
  }

  // Seed demo data on first run (for mobile/Android) - only if not using Supabase
  if (!kIsWeb && !AppConfig.useSupabase) {
    await DemoSeeder.seedDemoData();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenant;

    return MaterialApp(
      title: 'POS Kasir Multi-Tenant',
      theme: AppTheme.getTheme(
        customPrimary: tenant?.settings?['primary_color'] != null
            ? Color(tenant!.settings!['primary_color'])
            : null,
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainScreen(),
      },
      home: authState.user == null ? const LoginScreen() : const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen();
      case 1:
        return const PosScreen();
      case 2:
        return const ProductsScreen();
      case 3:
        return const MaterialsScreen();
      case 4:
        return const RecipesScreen();
      case 5:
        return const ExpensesScreen();
      case 6:
        return const ReportsScreen();
      case 7:
        return const ShiftScreen();
      case 8:
        return const DiscountScreen();
      case 9:
        return const BranchScreen();
      case 10:
        return const UsersScreen();
      case 11:
        return const SettingsScreen();
      case 12:
        // More menu screen for mobile navigation
        return MoreMenuScreen(
            onNavigate: (idx) => setState(() => _currentIndex = idx));
      default:
        return HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: _currentIndex,
      onNavigate: (index) => setState(() => _currentIndex = index),
      child: _getScreen(_currentIndex),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              '$title - Coming Soon',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
