import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/offline_indicator.dart';
import '../../data/models/branch.dart';
import '../../data/models/user.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_provider.dart';
import 'branch_provider.dart';

/// Branch management screen
/// Requirements 11.1, 11.2, 11.3, 11.5: Branch management UI
/// Supports offline-first architecture for Android
class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(branchListProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Check if user is logged in
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Silakan login untuk mengakses cabang',
                  style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    // Check role - only owner can manage branches
    final canManage = user.role == UserRole.owner;

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('🏪 Manajemen Cabang'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings,
                  size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Akses Terbatas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Hanya Owner yang dapat mengelola cabang',
                  style: TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            const Text('🏪 Manajemen Cabang'),
            const SizedBox(width: 8),
            // Offline indicator
            if (!kIsWeb)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_bolt,
                        size: 12, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style:
                          TextStyle(fontSize: 10, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(branchListProvider.notifier).loadBranches(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Cabang'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _buildBody(context, ref, branchState),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, AsyncValue<List<Branch>> state) {
    return state.when(
      data: (branches) => Column(
        children: [
          if (!kIsWeb) const OfflineIndicator(),
          Expanded(child: _BranchList(branches: branches)),
        ],
      ),
      loading: () => Column(
        children: [
          if (!kIsWeb) const OfflineIndicator(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Column(
        children: [
          if (!kIsWeb) const OfflineIndicator(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal Memuat Cabang',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: TextStyle(color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(branchListProvider.notifier).loadBranches(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBranchDialog(BuildContext context, WidgetRef ref,
      {Branch? branch}) {
    showDialog(
      context: context,
      builder: (context) => _BranchFormDialog(branch: branch),
    ).then((result) {
      if (result == true) {
        ref.read(branchListProvider.notifier).loadBranches();
      }
    });
  }
}

/// Branch list widget
class _BranchList extends ConsumerWidget {
  final List<Branch> branches;

  const _BranchList({required this.branches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (branches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(branchListProvider.notifier).loadBranches(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined,
                        size: 64, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada cabang',
                      style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tambahkan cabang untuk mengelola bisnis Anda',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(branchListProvider.notifier).loadBranches(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Calculate stats
    final activeCount = branches.where((b) => b.isActive).length;
    final inactiveCount = branches.length - activeCount;

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  label: 'Total',
                  value: '${branches.length}',
                  color: Colors.blue),
              _buildStatItem(
                  label: 'Aktif', value: '$activeCount', color: Colors.green),
              _buildStatItem(
                  label: 'Nonaktif',
                  value: '$inactiveCount',
                  color: Colors.grey),
            ],
          ),
        ),
        // List with RefreshIndicator
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(branchListProvider.notifier).loadBranches(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: branches.length,
              itemBuilder: (context, index) => _BranchCard(
                branch: branches[index],
                onEdit: () => _showEditDialog(context, ref, branches[index]),
                onDelete: () => _confirmDelete(context, ref, branches[index]),
                onToggle: () => _toggleStatus(context, ref, branches[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Stat item widget
  Widget _buildStatItem(
      {required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Branch branch) {
    showDialog(
      context: context,
      builder: (context) => _BranchFormDialog(branch: branch),
    ).then((result) {
      if (result == true) {
        ref.read(branchListProvider.notifier).loadBranches();
      }
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Branch branch) {
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Cabang'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yakin ingin menghapus cabang "${branch.name}"?'),
              const SizedBox(height: 8),
              Text(
                'Semua data terkait cabang ini akan dihapus permanen.',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        final authState = ref.read(authProvider);
                        // Use BranchListNotifier method with offline support
                        final result = await ref
                            .read(branchListProvider.notifier)
                            .deleteBranch(
                              branch.id,
                              ownerId: authState.user?.id,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (result.success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cabang berhasil dihapus'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(result.error ?? 'Gagal menghapus'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
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

  void _toggleStatus(BuildContext context, WidgetRef ref, Branch branch) async {
    try {
      // Use BranchListNotifier method with offline support
      final result = await ref
          .read(branchListProvider.notifier)
          .toggleStatus(branch.id, !branch.isActive);

      if (result.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(branch.isActive
                  ? 'Cabang dinonaktifkan'
                  : 'Cabang diaktifkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Gagal mengubah status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Branch card widget
class _BranchCard extends StatelessWidget {
  final Branch branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _BranchCard({
    required this.branch,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: branch.isActive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.store,
                  color: branch.isActive ? Colors.green : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Kode: ${branch.code}',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: branch.isActive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  branch.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    color: branch.isActive ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details
          if (branch.address != null || branch.phone != null)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (branch.address != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          branch.address!,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (branch.phone != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        branch.phone!,
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Pajak: ${(branch.taxRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  branch.isActive ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(branch.isActive ? 'Nonaktifkan' : 'Aktifkan'),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                label: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Branch form dialog
class _BranchFormDialog extends ConsumerStatefulWidget {
  final Branch? branch;

  const _BranchFormDialog({this.branch});

  @override
  ConsumerState<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends ConsumerState<_BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _taxRateController;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameController = TextEditingController(text: b?.name ?? '');
    _codeController = TextEditingController(text: b?.code ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _phoneController = TextEditingController(text: b?.phone ?? '');
    _taxRateController = TextEditingController(
        text: b != null ? (b.taxRate * 100).toStringAsFixed(0) : '11');
    _isActive = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.branch != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit : Icons.add_business,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Cabang' : 'Tambah Cabang'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Cabang *',
                    prefixIcon: Icon(Icons.store),
                    hintText: 'Contoh: Cabang Jakarta Pusat',
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Cabang *',
                    prefixIcon: Icon(Icons.qr_code),
                    hintText: 'Contoh: JKT-001',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !isEdit, // Code cannot be changed after creation
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Kode wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telepon',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taxRateController,
                  decoration: const InputDecoration(
                    labelText: 'Tarif Pajak (%)',
                    prefixIcon: Icon(Icons.percent),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val < 0 || val > 100) {
                      return 'Tarif pajak tidak valid (0-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  subtitle: const Text('Cabang dapat beroperasi'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate branch code format (alphanumeric with dashes)
    final codeRegex = RegExp(r'^[A-Z0-9\-]+$');
    final code = _codeController.text.trim().toUpperCase();
    if (!codeRegex.hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kode cabang hanya boleh berisi huruf, angka, dan tanda hubung'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) throw Exception('User tidak terautentikasi');

      // Validate role - only owner can create/edit branches
      if (user.role != UserRole.owner) {
        throw Exception('Hanya Owner yang dapat mengelola cabang');
      }

      final branch = Branch(
        id: widget.branch?.id ?? const Uuid().v4(),
        ownerId: user.id,
        name: _nameController.text.trim(),
        code: code,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        taxRate: (double.tryParse(_taxRateController.text) ?? 11) / 100,
        isActive: _isActive,
        createdAt: widget.branch?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Use BranchListNotifier methods with offline support
      final notifier = ref.read(branchListProvider.notifier);
      final result = widget.branch != null
          ? await notifier.updateBranch(branch)
          : await notifier.createBranch(branch);

      if (mounted) {
        if (result.success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.branch != null
                  ? 'Cabang berhasil diperbarui'
                  : 'Cabang berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Gagal menyimpan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
