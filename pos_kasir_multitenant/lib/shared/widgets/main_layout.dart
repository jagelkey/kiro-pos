import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../../features/auth/auth_provider.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onNavigate;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final tenant = authState.tenant;
    final user = authState.user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Breakpoints.isTabletOrLarger(constraints.maxWidth);

        if (isTablet) {
          return Row(
            children: [
              _Sidebar(
                currentIndex: currentIndex,
                onNavigate: onNavigate,
                tenantName: tenant?.name ?? 'Store',
                userRole: user?.role,
              ),
              Expanded(child: child),
            ],
          );
        } else {
          return Scaffold(
            body: child,
            bottomNavigationBar: _BottomNav(
              currentIndex: currentIndex,
              onNavigate: onNavigate,
              userRole: user?.role,
            ),
          );
        }
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final String tenantName;
  final UserRole? userRole;

  const _Sidebar({
    required this.currentIndex,
    required this.onNavigate,
    required this.tenantName,
    this.userRole,
  });

  /// Check if user can access a menu item based on role
  /// Requirements 7.3: Restrict owner-only features for cashier role
  bool _canAccess(int index) {
    if (userRole == null) return true;

    // Super Admin has access to everything
    if (userRole == UserRole.superAdmin) return true;

    // Owner-only features: Users (10), Settings (11), Discounts (8), Branches (9)
    if (index == 10 || index == 11 || index == 8 || index == 9) {
      return userRole == UserRole.owner || userRole == UserRole.manager;
    }

    // Manager+ features: Reports (6), Expenses (5), Materials (3), Recipes (4)
    if (index == 6 || index == 5 || index == 3 || index == 4) {
      return userRole == UserRole.owner || userRole == UserRole.manager;
    }

    // All roles can access: Dashboard (0), POS (1), Products (2), Shift (7)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppTheme.cardColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.store, color: AppTheme.primaryColor, size: 32),
                const SizedBox(width: AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'POS System',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacing3),
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isSelected: currentIndex == 0,
                  onTap: () => onNavigate(0),
                ),
                _NavItem(
                  icon: Icons.point_of_sale,
                  label: 'POS Kasir',
                  isSelected: currentIndex == 1,
                  onTap: () => onNavigate(1),
                ),
                _NavItem(
                  icon: Icons.inventory,
                  label: 'Produk',
                  isSelected: currentIndex == 2,
                  onTap: () => onNavigate(2),
                ),
                // Manager+ only features
                if (_canAccess(3))
                  _NavItem(
                    icon: Icons.category,
                    label: 'Bahan Baku',
                    isSelected: currentIndex == 3,
                    onTap: () => onNavigate(3),
                  ),
                if (_canAccess(4))
                  _NavItem(
                    icon: Icons.science,
                    label: 'Resep',
                    isSelected: currentIndex == 4,
                    onTap: () => onNavigate(4),
                  ),
                if (_canAccess(5))
                  _NavItem(
                    icon: Icons.receipt_long,
                    label: 'Biaya Operasional',
                    isSelected: currentIndex == 5,
                    onTap: () => onNavigate(5),
                  ),
                if (_canAccess(6))
                  _NavItem(
                    icon: Icons.assessment,
                    label: 'Laporan',
                    isSelected: currentIndex == 6,
                    onTap: () => onNavigate(6),
                  ),
                // Shift - accessible by all roles
                _NavItem(
                  icon: Icons.access_time,
                  label: 'Shift',
                  isSelected: currentIndex == 7,
                  onTap: () => onNavigate(7),
                ),
                // Owner/Manager only features
                if (_canAccess(8))
                  _NavItem(
                    icon: Icons.local_offer,
                    label: 'Diskon',
                    isSelected: currentIndex == 8,
                    onTap: () => onNavigate(8),
                  ),
                if (_canAccess(9))
                  _NavItem(
                    icon: Icons.store,
                    label: 'Cabang',
                    isSelected: currentIndex == 9,
                    onTap: () => onNavigate(9),
                  ),
                if (_canAccess(10))
                  _NavItem(
                    icon: Icons.people,
                    label: 'Pengguna',
                    isSelected: currentIndex == 10,
                    onTap: () => onNavigate(10),
                  ),
                if (_canAccess(11))
                  _NavItem(
                    icon: Icons.settings,
                    label: 'Pengaturan',
                    isSelected: currentIndex == 11,
                    onTap: () => onNavigate(11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Material(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing3,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacing3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final UserRole? userRole;

  const _BottomNav({
    required this.currentIndex,
    required this.onNavigate,
    this.userRole,
  });

  /// Check if user has manager+ access
  /// Requirements 7.3: Restrict owner-only features for cashier role
  bool get _hasManagerAccess =>
      userRole == null ||
      userRole == UserRole.superAdmin ||
      userRole == UserRole.owner ||
      userRole == UserRole.manager;

  @override
  Widget build(BuildContext context) {
    // For cashiers, show simplified navigation
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale), label: 'POS'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.inventory), label: 'Produk'),
    ];

    // Add Reports for manager+ only
    if (_hasManagerAccess) {
      items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.assessment), label: 'Laporan'));
    }

    // Always add "More" menu
    items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz), label: 'Lainnya'));

    // Adjust current index for cashiers (they don't have Reports)
    int adjustedIndex = currentIndex;
    if (!_hasManagerAccess && currentIndex >= 3) {
      // For cashiers, index 3 is "More" instead of "Reports"
      if (currentIndex == 6) {
        // Reports - not accessible, redirect to More
        adjustedIndex = 3;
      } else if (currentIndex > 3) {
        adjustedIndex = 3; // More menu
      }
    } else if (_hasManagerAccess && currentIndex > 6) {
      adjustedIndex = 4; // More menu
    }

    // Clamp to valid range
    adjustedIndex = adjustedIndex.clamp(0, items.length - 1);

    return BottomNavigationBar(
      currentIndex: adjustedIndex,
      onTap: (index) {
        // Map bottom nav index to actual screen index
        if (!_hasManagerAccess) {
          // Cashier mapping: 0=Dashboard, 1=POS, 2=Products, 3=More
          if (index == 3) {
            onNavigate(12); // More -> MoreMenuScreen
          } else {
            onNavigate(index);
          }
        } else {
          // Manager+ mapping: 0=Dashboard, 1=POS, 2=Products, 3=Reports, 4=More
          if (index == 4) {
            onNavigate(12); // More -> MoreMenuScreen
          } else if (index == 3) {
            onNavigate(6); // Reports
          } else {
            onNavigate(index);
          }
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondary,
      items: items,
    );
  }
}
