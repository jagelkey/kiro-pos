import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../auth/auth_provider.dart';

class MoreMenuScreen extends ConsumerWidget {
  final Function(int) onNavigate;

  const MoreMenuScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userRole = user?.role;

    final isOwnerOrManager = userRole == UserRole.superAdmin ||
        userRole == UserRole.owner ||
        userRole == UserRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Lainnya'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _getRoleLabel(userRole),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu items
          const Text(
            'Manajemen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Shift - accessible by all
          _MenuTile(
            icon: Icons.access_time,
            title: 'Shift',
            subtitle: 'Kelola shift kasir',
            onTap: () => onNavigate(7),
          ),

          // Manager+ only features
          if (isOwnerOrManager) ...[
            _MenuTile(
              icon: Icons.category,
              title: 'Bahan Baku',
              subtitle: 'Kelola stok bahan',
              onTap: () => onNavigate(3),
            ),
            _MenuTile(
              icon: Icons.science,
              title: 'Resep',
              subtitle: 'Kelola resep produk',
              onTap: () => onNavigate(4),
            ),
            _MenuTile(
              icon: Icons.receipt_long,
              title: 'Biaya Operasional',
              subtitle: 'Catat pengeluaran',
              onTap: () => onNavigate(5),
            ),
            _MenuTile(
              icon: Icons.local_offer,
              title: 'Diskon',
              subtitle: 'Kelola promo & diskon',
              onTap: () => onNavigate(8),
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            'Pengaturan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Owner only features
          if (userRole == UserRole.superAdmin ||
              userRole == UserRole.owner) ...[
            _MenuTile(
              icon: Icons.store,
              title: 'Cabang',
              subtitle: 'Kelola cabang toko',
              onTap: () => onNavigate(9),
            ),
            _MenuTile(
              icon: Icons.people,
              title: 'Pengguna',
              subtitle: 'Kelola akun karyawan',
              onTap: () => onNavigate(10),
            ),
          ],

          _MenuTile(
            icon: Icons.settings,
            title: 'Pengaturan',
            subtitle: 'Konfigurasi aplikasi',
            onTap: () => onNavigate(11),
          ),

          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(authProvider.notifier).logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(UserRole? role) {
    switch (role) {
      case UserRole.owner:
        return '👑 Owner';
      case UserRole.manager:
        return '📊 Manager';
      case UserRole.cashier:
        return '💰 Kasir';
      default:
        return 'User';
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
