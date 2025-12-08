import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/expense.dart';
import 'expenses_provider.dart';
import '../auth/auth_provider.dart';

// Coffee shop expense categories
const List<Map<String, dynamic>> expenseCategories = [
  {'name': 'Gaji Karyawan', 'icon': Icons.people, 'color': Colors.blue},
  {'name': 'Listrik', 'icon': Icons.bolt, 'color': Colors.amber},
  {'name': 'Air PDAM', 'icon': Icons.water_drop, 'color': Colors.cyan},
  {'name': 'Sewa Tempat', 'icon': Icons.home, 'color': Colors.brown},
  {'name': 'Internet & WiFi', 'icon': Icons.wifi, 'color': Colors.indigo},
  {
    'name': 'Gas LPG',
    'icon': Icons.local_fire_department,
    'color': Colors.orange
  },
  {
    'name': 'Pembelian Bahan',
    'icon': Icons.shopping_cart,
    'color': Colors.green
  },
  {'name': 'Perawatan Mesin', 'icon': Icons.build, 'color': Colors.grey},
  {'name': 'Kebersihan', 'icon': Icons.cleaning_services, 'color': Colors.teal},
  {'name': 'Marketing', 'icon': Icons.campaign, 'color': Colors.pink},
  {
    'name': 'Transportasi',
    'icon': Icons.local_shipping,
    'color': Colors.deepPurple
  },
  {'name': 'Pajak', 'icon': Icons.receipt_long, 'color': Colors.red},
  {'name': 'Lainnya', 'icon': Icons.more_horiz, 'color': Colors.blueGrey},
];

// Filter providers
final expenseSearchProvider = StateProvider<String>((ref) => '');
final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);
final expenseDateFilterProvider =
    StateProvider<String>((ref) => 'month'); // week, month, year, all

/// Maximum allowed expense amount (prevent overflow)
const double maxExpenseAmount = 999999999999;

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final searchQuery = ref.watch(expenseSearchProvider);
    final categoryFilter = ref.watch(expenseCategoryFilterProvider);
    final dateFilter = ref.watch(expenseDateFilterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('💰 Biaya Operasional'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(expensesProvider.notifier).loadExpenses(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context, ref),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                var filtered = _filterExpenses(
                    expenses, searchQuery, categoryFilter, dateFilter);
                return _buildExpensesList(context, ref, filtered, expenses);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(context, ref, e),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Biaya'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref) {
    final categoryFilter = ref.watch(expenseCategoryFilterProvider);
    final dateFilter = ref.watch(expenseDateFilterProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari biaya...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) =>
                ref.read(expenseSearchProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: _getDateFilterLabel(dateFilter),
                  icon: Icons.calendar_today,
                  isSelected: dateFilter != 'all',
                  onTap: () => _showDateFilterPicker(context, ref),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: categoryFilter ?? 'Semua Kategori',
                  icon: Icons.category,
                  isSelected: categoryFilter != null,
                  onTap: () => _showCategoryPicker(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDateFilterLabel(String filter) {
    switch (filter) {
      case 'week':
        return 'Minggu Ini';
      case 'month':
        return 'Bulan Ini';
      case 'year':
        return 'Tahun Ini';
      default:
        return 'Semua Waktu';
    }
  }

  void _showDateFilterPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Minggu Ini'),
                onTap: () {
                  ref.read(expenseDateFilterProvider.notifier).state = 'week';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Bulan Ini'),
                onTap: () {
                  ref.read(expenseDateFilterProvider.notifier).state = 'month';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Tahun Ini'),
                onTap: () {
                  ref.read(expenseDateFilterProvider.notifier).state = 'year';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Semua Waktu'),
                onTap: () {
                  ref.read(expenseDateFilterProvider.notifier).state = 'all';
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('Semua Kategori'),
                  onTap: () {
                    ref.read(expenseCategoryFilterProvider.notifier).state =
                        null;
                    Navigator.pop(context);
                  }),
              const Divider(),
              ...expenseCategories.map((cat) => ListTile(
                    leading: Icon(cat['icon'] as IconData,
                        color: cat['color'] as Color),
                    title: Text(cat['name'] as String),
                    onTap: () {
                      ref.read(expenseCategoryFilterProvider.notifier).state =
                          cat['name'] as String;
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  List<Expense> _filterExpenses(List<Expense> expenses, String search,
      String? category, String dateFilter) {
    var result = expenses;

    // Date filter
    final now = DateTime.now();
    DateTime? startDate;
    switch (dateFilter) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
    }
    if (startDate != null) {
      result = result
          .where((e) =>
              e.date.isAfter(startDate!.subtract(const Duration(days: 1))))
          .toList();
    }

    // Search
    if (search.isNotEmpty) {
      result = result
          .where((e) =>
              e.category.toLowerCase().contains(search.toLowerCase()) ||
              (e.description?.toLowerCase().contains(search.toLowerCase()) ??
                  false))
          .toList();
    }

    // Category
    if (category != null) {
      result = result.where((e) => e.category == category).toList();
    }

    return result;
  }

  Widget _buildExpensesList(BuildContext context, WidgetRef ref,
      List<Expense> filtered, List<Expense> all) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Tidak ada biaya',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
    }

    // Calculate stats
    final totalFiltered = filtered.fold<double>(0, (sum, e) => sum + e.amount);
    final categoryBreakdown = <String, double>{};
    for (var e in filtered) {
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0) + e.amount;
    }

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [AppTheme.warningColor, Colors.orange.shade600]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pengeluaran',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(_formatCurrency(totalFiltered),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                      ]),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Text('${filtered.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('transaksi',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _ExpenseCard(expense: filtered[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          ElevatedButton(
              onPressed: () =>
                  ref.read(expensesProvider.notifier).loadExpenses(),
              child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref,
      {Expense? expense}) {
    showDialog(
        context: context,
        builder: (context) => ExpenseFormDialog(expense: expense));
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.warningColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.warningColor : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppTheme.warningColor
                    : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppTheme.warningColor
                        : AppTheme.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: isSelected
                    ? AppTheme.warningColor
                    : AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// Expense Card Widget
class _ExpenseCard extends ConsumerWidget {
  final Expense expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catData = expenseCategories.firstWhere(
      (c) => c['name'] == expense.category,
      orElse: () => expenseCategories.last,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showDialog(
            context: context,
            builder: (context) => ExpenseFormDialog(expense: expense)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (catData['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(catData['icon'] as IconData,
                    color: catData['color'] as Color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.category,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (expense.description != null &&
                        expense.description!.isNotEmpty)
                      Text(expense.description!,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Text(DateFormat('dd MMM yyyy').format(expense.date),
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(
                            locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                        .format(expense.amount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                        fontSize: 15),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    onSelected: (value) => _handleAction(context, ref, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.red))
                          ])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'edit') {
      showDialog(
          context: context,
          builder: (context) => ExpenseFormDialog(expense: expense));
    } else if (action == 'delete') {
      bool isLoading = false;
      String? errorText;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Hapus Biaya'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yakin ingin menghapus "${expense.category}"?',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (expense.description != null &&
                    expense.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.description!,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Tindakan ini tidak dapat dibatalkan.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        setState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        try {
                          await ref
                              .read(expensesProvider.notifier)
                              .deleteExpense(expense.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Biaya "${expense.category}" telah dihapus'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            errorText = 'Gagal menghapus: $e';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
  }
}

// Expense Form Dialog
class ExpenseFormDialog extends ConsumerStatefulWidget {
  final Expense? expense;
  const ExpenseFormDialog({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  String? _selectedBranchId;
  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.expense?.amount.toStringAsFixed(0) ?? '');
    _descriptionController =
        TextEditingController(text: widget.expense?.description ?? '');
    _selectedCategory = widget.expense?.category;
    _selectedBranchId = widget.expense?.branchId;
    _selectedDate = widget.expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Pilih kategori terlebih dahulu');
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      setState(() => _errorMessage = 'Sesi tidak valid. Silakan login ulang.');
      return;
    }

    // Parse and validate amount
    final amountText =
        _amountController.text.replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Jumlah harus lebih dari 0');
      return;
    }
    if (amount > maxExpenseAmount) {
      setState(() => _errorMessage = 'Jumlah terlalu besar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        id: widget.expense?.id ?? const Uuid().v4(),
        tenantId: authState.tenant!.id,
        branchId: _selectedBranchId ?? authState.user?.branchId,
        category: _selectedCategory!,
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: _selectedDate,
        createdBy: authState.user?.id,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        updatedAt: isEditing ? DateTime.now() : null,
      );

      // Validate using model validation
      final validationError = expense.validate();
      if (validationError != null) {
        setState(() {
          _errorMessage = validationError;
          _isLoading = false;
        });
        return;
      }

      if (isEditing) {
        await ref.read(expensesProvider.notifier).updateExpense(expense);
      } else {
        await ref.read(expensesProvider.notifier).addExpense(expense);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Biaya berhasil diperbarui'
                : 'Biaya berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.add_box,
              color: AppTheme.warningColor),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit Biaya' : 'Tambah Biaya'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Grid
                const Text('Kategori *',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenseCategories.map((cat) {
                    final isSelected = _selectedCategory == cat['name'];
                    return InkWell(
                      onTap: () => setState(
                          () => _selectedCategory = cat['name'] as String),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (cat['color'] as Color).withValues(alpha: 0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isSelected
                                  ? cat['color'] as Color
                                  : Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? cat['color'] as Color
                                    : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(cat['name'] as String,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? cat['color'] as Color
                                        : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                      labelText: 'Jumlah *',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: 'Rp '),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Jumlah wajib diisi';
                    if (double.tryParse(v.replaceAll('.', '')) == null) {
                      return 'Angka tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Quick amount buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [50000, 100000, 250000, 500000, 1000000]
                      .map((amount) => ActionChip(
                            label: Text(NumberFormat.compact(locale: 'id')
                                .format(amount)),
                            onPressed: () => setState(() =>
                                _amountController.text = amount.toString()),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                // Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Tanggal'),
                  subtitle:
                      Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                const SizedBox(height: 16),
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Keterangan (opsional)',
                      prefixIcon: Icon(Icons.note)),
                  maxLines: 2,
                  maxLength: 500,
                ),
                // Error message display
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton.icon(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
          onPressed: _isLoading ? null : _save,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ))
              : const Icon(Icons.save),
          label: Text(isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
