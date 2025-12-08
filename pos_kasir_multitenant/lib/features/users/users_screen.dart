import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_provider.dart';
import '../branches/branch_provider.dart';
import 'users_provider.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cek akses halaman - Requirements 7.3
    final canAccess = ref.watch(canAccessUsersPageProvider);

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('👥 Manajemen Pengguna'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                'Akses Ditolak',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda tidak memiliki izin untuk mengakses halaman ini.\nHubungi Owner atau Manager.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return const _UsersScreenContent();
  }
}

class _UsersScreenContent extends ConsumerStatefulWidget {
  const _UsersScreenContent();

  @override
  ConsumerState<_UsersScreenContent> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<_UsersScreenContent> {
  String _searchQuery = '';
  UserRole? _selectedRole;

  List<User> _filterUsers(List<User> users) {
    return users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == null || user.role == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('👥 Manajemen Pengguna'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(usersProvider.notifier).loadUsers(),
          ),
        ],
      ),
      body: usersAsync.when(
        data: (allUsers) {
          final users = _filterUsers(allUsers);
          final screenWidth = MediaQuery.of(context).size.width;
          final isCompact = screenWidth < 400;

          return Column(
            children: [
              // Search & Filter
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                color: Colors.white,
                child: Column(
                  children: [
                    // Search
                    SizedBox(
                      height: isCompact ? 40 : 44,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari pengguna...',
                          hintStyle: TextStyle(fontSize: isCompact ? 12 : 13),
                          prefixIcon:
                              Icon(Icons.search, size: isCompact ? 18 : 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.borderColor),
                          ),
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 10 : 12),
                        ),
                        style: TextStyle(fontSize: isCompact ? 12 : 13),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Semua',
                            isSelected: _selectedRole == null,
                            onTap: () => setState(() => _selectedRole = null),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: '👑 Owner',
                            isSelected: _selectedRole == UserRole.owner,
                            onTap: () =>
                                setState(() => _selectedRole = UserRole.owner),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: '👨‍💼 Manager',
                            isSelected: _selectedRole == UserRole.manager,
                            onTap: () => setState(
                                () => _selectedRole = UserRole.manager),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: '💰 Kasir',
                            isSelected: _selectedRole == UserRole.cashier,
                            onTap: () => setState(
                                () => _selectedRole = UserRole.cashier),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 8 : 10,
                ),
                child: _UsersSummaryCard(users: allUsers),
              ),

              // Users List
              Expanded(
                child: users.isEmpty
                    ? _EmptyState(
                        onAddUser: () => _showUserForm(context),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 12,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _UserCard(
                            user: user,
                            onEdit: () => _showUserForm(context, user: user),
                            onDelete: () => _confirmDelete(context, user),
                            onToggleStatus: () => _toggleUserStatus(user),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(usersProvider.notifier).loadUsers(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ref.watch(canManageUsersProvider)
          ? FloatingActionButton.extended(
              onPressed: () => _showUserForm(context),
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah User'),
            )
          : null,
    );
  }

  void _showUserForm(BuildContext context, {User? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserFormSheet(
        user: user,
        onSave: (newUser) async {
          try {
            if (user != null) {
              await ref.read(usersProvider.notifier).updateUser(newUser);
            } else {
              await ref.read(usersProvider.notifier).addUser(newUser);
            }
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(user != null
                      ? 'User berhasil diupdate'
                      : 'User berhasil ditambahkan'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal menyimpan: $e'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, User user) {
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Hapus Pengguna'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yakin ingin menghapus "${user.name}"?'),
              const SizedBox(height: 8),
              Text(
                'Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await ref
                            .read(usersProvider.notifier)
                            .deleteUser(user.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User berhasil dihapus'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menghapus: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(User user) async {
    final newStatus = !user.isActive;
    try {
      await ref
          .read(usersProvider.notifier)
          .toggleUserStatus(user.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'User diaktifkan' : 'User dinonaktifkan'),
            backgroundColor:
                newStatus ? AppTheme.successColor : AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 11 : 12,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// Action Button Widget for compact user card
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isCompact;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 10,
          vertical: isCompact ? 4 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isCompact ? 14 : 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Users Summary Card
class _UsersSummaryCard extends StatelessWidget {
  final List<User> users;

  const _UsersSummaryCard({required this.users});

  @override
  Widget build(BuildContext context) {
    final ownerCount = users.where((u) => u.role == UserRole.owner).length;
    final managerCount = users.where((u) => u.role == UserRole.manager).length;
    final cashierCount = users.where((u) => u.role == UserRole.cashier).length;
    final activeCount = users.where((u) => u.isActive).length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side - Total count
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Pengguna',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${users.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 22 : 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Right side - Role breakdown
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryItem(
                    icon: '👑',
                    label: 'Owner',
                    count: ownerCount,
                    isCompact: isCompact),
                _SummaryItem(
                    icon: '👨‍💼',
                    label: 'Manager',
                    count: managerCount,
                    isCompact: isCompact),
                _SummaryItem(
                    icon: '💰',
                    label: 'Kasir',
                    count: cashierCount,
                    isCompact: isCompact),
                _SummaryItem(
                    icon: '✅',
                    label: 'Aktif',
                    count: activeCount,
                    isCompact: isCompact),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final bool isCompact;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: isCompact ? 14 : 16)),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isCompact ? 9 : 10,
          ),
        ),
      ],
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddUser;

  const _EmptyState({required this.onAddUser});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: isCompact ? 48 : 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum ada pengguna',
              style: TextStyle(
                  fontSize: isCompact ? 15 : 16, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan pengguna baru untuk mengelola toko',
              style: TextStyle(
                  fontSize: isCompact ? 12 : 13, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddUser,
              icon: Icon(Icons.person_add, size: isCompact ? 16 : 18),
              label: Text('Tambah User',
                  style: TextStyle(fontSize: isCompact ? 12 : 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 20,
                  vertical: isCompact ? 8 : 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// User Card
class _UserCard extends ConsumerWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canManageUsersProvider);
    final currentUser = ref.watch(authProvider).user;
    final isCurrentUser = currentUser?.id == user.id;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Avatar - smaller
              Container(
                width: isCompact ? 40 : 44,
                height: isCompact ? 40 : 44,
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _getRoleIcon(user.role),
                    style: TextStyle(fontSize: isCompact ? 18 : 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isCompact ? 13 : 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Anda',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppTheme.successColor.withValues(alpha: 0.1)
                                : AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              fontSize: isCompact ? 9 : 10,
                              color: user.isActive
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: isCompact ? 11 : 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                _getRoleColor(user.role).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getRoleLabel(user.role),
                            style: TextStyle(
                              fontSize: isCompact ? 9 : 10,
                              color: _getRoleColor(user.role),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user.branchId != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.store,
                                    size: 10, color: AppTheme.textMuted),
                                const SizedBox(width: 2),
                                Text(
                                  'Branch',
                                  style: TextStyle(
                                    fontSize: isCompact ? 9 : 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Actions - compact version
          if (canManage) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: user.isActive ? Icons.block : Icons.check_circle,
                  label: user.isActive ? 'Nonaktif' : 'Aktif',
                  color: isCurrentUser
                      ? AppTheme.textMuted
                      : (user.isActive
                          ? AppTheme.warningColor
                          : AppTheme.successColor),
                  onPressed: isCurrentUser ? null : onToggleStatus,
                  isCompact: isCompact,
                ),
                _ActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  color: AppTheme.primaryColor,
                  onPressed: onEdit,
                  isCompact: isCompact,
                ),
                _ActionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color:
                      isCurrentUser ? AppTheme.textMuted : AppTheme.errorColor,
                  onPressed: isCurrentUser ? null : onDelete,
                  isCompact: isCompact,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return '🔐';
      case UserRole.owner:
        return '👑';
      case UserRole.manager:
        return '👨‍💼';
      case UserRole.cashier:
        return '💰';
    }
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.owner:
        return 'Owner';
      case UserRole.manager:
        return 'Manager';
      case UserRole.cashier:
        return 'Kasir';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple.shade700;
      case UserRole.owner:
        return Colors.amber.shade700;
      case UserRole.manager:
        return Colors.blue.shade700;
      case UserRole.cashier:
        return AppTheme.primaryColor;
    }
  }
}

// User Form Sheet
class _UserFormSheet extends ConsumerStatefulWidget {
  final User? user;
  final Future<void> Function(User) onSave;

  const _UserFormSheet({
    this.user,
    required this.onSave,
  });

  @override
  ConsumerState<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  UserRole _selectedRole = UserRole.cashier;
  String? _selectedBranchId;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    if (widget.user != null) {
      _selectedRole = widget.user!.role;
      _selectedBranchId = widget.user!.branchId;
      _isActive = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Simple password hash untuk demo (gunakan bcrypt di production)
  String _hashPassword(String password) {
    // Untuk demo, kita gunakan simple hash
    // Di production, gunakan package seperti bcrypt atau crypto
    return password.hashCode.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 14 : 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? '✏️ Edit Pengguna' : '➕ Tambah Pengguna',
                    style: TextStyle(
                      fontSize: isCompact ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: isCompact ? 20 : 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 18),

              // Role Selection
              Text(
                'Role',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: isCompact ? 12 : 13),
              ),
              SizedBox(height: isCompact ? 8 : 10),
              Row(
                children: [
                  Expanded(
                    child: _RoleOption(
                      icon: '👑',
                      label: 'Owner',
                      isSelected: _selectedRole == UserRole.owner,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.owner),
                      color: Colors.amber.shade700,
                      isCompact: isCompact,
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : 8),
                  Expanded(
                    child: _RoleOption(
                      icon: '👨‍💼',
                      label: 'Manager',
                      isSelected: _selectedRole == UserRole.manager,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.manager),
                      color: Colors.blue.shade700,
                      isCompact: isCompact,
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : 8),
                  Expanded(
                    child: _RoleOption(
                      icon: '💰',
                      label: 'Kasir',
                      isSelected: _selectedRole == UserRole.cashier,
                      onTap: () =>
                          setState(() => _selectedRole = UserRole.cashier),
                      color: AppTheme.primaryColor,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 12 : 16),

              // Branch Selection (only for Manager and Cashier)
              if (_selectedRole != UserRole.owner) ...[
                Text(
                  'Cabang',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isCompact ? 12 : 13),
                ),
                SizedBox(height: isCompact ? 8 : 10),
                Consumer(
                  builder: (context, ref, child) {
                    final branchesAsync = ref.watch(branchListProvider);
                    return branchesAsync.when(
                      data: (branches) {
                        if (branches.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(isCompact ? 8 : 10),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.warningColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppTheme.warningColor,
                                    size: isCompact ? 16 : 18),
                                SizedBox(width: isCompact ? 6 : 8),
                                Expanded(
                                  child: Text(
                                    'Belum ada cabang. Buat cabang terlebih dahulu.',
                                    style: TextStyle(
                                        fontSize: isCompact ? 10 : 11),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedBranchId,
                          decoration: InputDecoration(
                            labelText: 'Pilih Cabang',
                            labelStyle:
                                TextStyle(fontSize: isCompact ? 12 : 13),
                            prefixIcon:
                                Icon(Icons.store, size: isCompact ? 18 : 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 10 : 12,
                              vertical: isCompact ? 10 : 12,
                            ),
                          ),
                          style: TextStyle(
                              fontSize: isCompact ? 12 : 13,
                              color: AppTheme.textPrimary),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('Tidak ada cabang (Semua cabang)',
                                  style:
                                      TextStyle(fontSize: isCompact ? 12 : 13)),
                            ),
                            ...branches.map((branch) {
                              return DropdownMenuItem<String>(
                                value: branch.id,
                                child: Text('${branch.code} - ${branch.name}',
                                    style: TextStyle(
                                        fontSize: isCompact ? 12 : 13)),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedBranchId = value);
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Text('Error: $e'),
                    );
                  },
                ),
                SizedBox(height: isCompact ? 10 : 12),
              ],

              // Name Field
              TextFormField(
                controller: _nameController,
                style: TextStyle(fontSize: isCompact ? 13 : 14),
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  labelStyle: TextStyle(fontSize: isCompact ? 12 : 13),
                  prefixIcon: Icon(Icons.person, size: isCompact ? 18 : 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 10 : 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              SizedBox(height: isCompact ? 10 : 12),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: isCompact ? 13 : 14),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(fontSize: isCompact ? 12 : 13),
                  prefixIcon: Icon(Icons.email, size: isCompact ? 18 : 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 10 : 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!value.contains('@')) {
                    return 'Email tidak valid';
                  }
                  return null;
                },
              ),
              SizedBox(height: isCompact ? 10 : 12),

              // Password Field (only for new user)
              if (!isEditing) ...[
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(fontSize: isCompact ? 13 : 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: isCompact ? 12 : 13),
                    prefixIcon: Icon(Icons.lock, size: isCompact ? 18 : 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: isCompact ? 18 : 20),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 10 : 12,
                      vertical: isCompact ? 10 : 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                SizedBox(height: isCompact ? 10 : 12),
              ],

              // Active Status
              SwitchListTile(
                title: Text('Status Aktif',
                    style: TextStyle(fontSize: isCompact ? 13 : 14)),
                subtitle: Text(
                    _isActive ? 'User dapat login' : 'User tidak dapat login',
                    style: TextStyle(fontSize: isCompact ? 11 : 12)),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                activeThumbColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
                dense: isCompact,
              ),
              SizedBox(height: isCompact ? 14 : 18),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: isCompact ? 42 : 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: isCompact ? 16 : 18,
                          height: isCompact ? 16 : 18,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Pengguna' : 'Tambah Pengguna',
                          style: TextStyle(
                              fontSize: isCompact ? 13 : 14,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Ambil tenantId dari auth state
      final authState = ref.read(authProvider);
      final tenantId = authState.tenant?.id ??
          widget.user?.tenantId ??
          '11111111-1111-1111-1111-111111111111';

      // Hash password jika ada (untuk user baru)
      String? passwordHash;
      if (_passwordController.text.isNotEmpty) {
        passwordHash = _hashPassword(_passwordController.text);
      } else if (widget.user != null) {
        // Pertahankan password lama jika edit dan tidak diubah
        passwordHash = widget.user!.passwordHash;
      }

      final user = User(
        id: widget.user?.id ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
        tenantId: tenantId,
        branchId: _selectedRole == UserRole.owner ? null : _selectedBranchId,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        passwordHash: passwordHash,
        role: _selectedRole,
        isActive: _isActive,
        createdAt: widget.user?.createdAt ?? DateTime.now(),
      );

      try {
        await widget.onSave(user);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}

// Role Option Widget
class _RoleOption extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isCompact;

  const _RoleOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isCompact ? 1.5 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: isCompact ? 18 : 20)),
            SizedBox(height: isCompact ? 2 : 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
