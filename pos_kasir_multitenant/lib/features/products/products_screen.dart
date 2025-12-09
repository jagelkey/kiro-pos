import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/offline_indicator.dart';
import '../../data/models/product.dart';
import 'products_provider.dart';

// Coffee shop categories
const List<String> coffeeShopCategories = [
  'Hot Coffee',
  'Iced Coffee',
  'Non-Coffee',
  'Tea',
  'Signature Drinks',
  'Food',
  'Snacks',
  'Dessert',
];

// Search and filter providers
final productSearchProvider = StateProvider<String>((ref) => '');
final productCategoryFilterProvider = StateProvider<String?>((ref) => null);
final productSortProvider = StateProvider<String>((ref) => 'name');
final productStockFilterProvider =
    StateProvider<String>((ref) => 'all'); // all, low, out

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productProvider);
    final searchQuery = ref.watch(productSearchProvider);
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final sortBy = ref.watch(productSortProvider);
    final stockFilter = ref.watch(productStockFilterProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Manajemen Produk'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(productProvider.notifier).loadProducts(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator for Android
          if (!kIsWeb) const OfflineIndicator(),
          // Search and Filter Bar
          _buildSearchFilterBar(context, ref, isWide),
          // Products List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                var filtered = _filterProducts(
                    products, searchQuery, categoryFilter, stockFilter);
                filtered = _sortProducts(filtered, sortBy);
                return _buildProductsList(context, ref, filtered, isWide);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(context, ref, e),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildSearchFilterBar(
      BuildContext context, WidgetRef ref, bool isWide) {
    final categoryFilter = ref.watch(productCategoryFilterProvider);
    final stockFilter = ref.watch(productStockFilterProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) =>
                ref.read(productSearchProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          // Filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Category filter
                _FilterChip(
                  label: categoryFilter ?? 'Semua Kategori',
                  icon: Icons.category,
                  isSelected: categoryFilter != null,
                  onTap: () => _showCategoryPicker(context, ref),
                ),
                const SizedBox(width: 8),
                // Stock filter
                _FilterChip(
                  label: stockFilter == 'all'
                      ? 'Semua Stok'
                      : stockFilter == 'low'
                          ? 'Stok Rendah'
                          : 'Stok Habis',
                  icon: Icons.inventory,
                  isSelected: stockFilter != 'all',
                  onTap: () => _showStockFilterPicker(context, ref),
                ),
                const SizedBox(width: 8),
                // Sort
                _FilterChip(
                  label: 'Urutkan',
                  icon: Icons.sort,
                  isSelected: false,
                  onTap: () => _showSortPicker(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Semua Kategori'),
              onTap: () {
                ref.read(productCategoryFilterProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...coffeeShopCategories.map((cat) => ListTile(
                  leading: Icon(_getCategoryIcon(cat)),
                  title: Text(cat),
                  onTap: () {
                    ref.read(productCategoryFilterProvider.notifier).state =
                        cat;
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showStockFilterPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Semua Stok'),
                onTap: () {
                  ref.read(productStockFilterProvider.notifier).state = 'all';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Stok Rendah (< 10)'),
                onTap: () {
                  ref.read(productStockFilterProvider.notifier).state = 'low';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Stok Habis'),
                onTap: () {
                  ref.read(productStockFilterProvider.notifier).state = 'out';
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
    );
  }

  void _showSortPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Nama (A-Z)'),
                onTap: () {
                  ref.read(productSortProvider.notifier).state = 'name';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Nama (Z-A)'),
                onTap: () {
                  ref.read(productSortProvider.notifier).state = 'name_desc';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Harga Terendah'),
                onTap: () {
                  ref.read(productSortProvider.notifier).state = 'price_asc';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Harga Tertinggi'),
                onTap: () {
                  ref.read(productSortProvider.notifier).state = 'price_desc';
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Stok Terendah'),
                onTap: () {
                  ref.read(productSortProvider.notifier).state = 'stock_asc';
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products, String search,
      String? category, String stockFilter) {
    var result = products;
    if (search.isNotEmpty) {
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(search.toLowerCase()) ||
              (p.barcode?.toLowerCase().contains(search.toLowerCase()) ??
                  false))
          .toList();
    }
    if (category != null) {
      result = result.where((p) => p.category == category).toList();
    }
    if (stockFilter == 'low') {
      result = result.where((p) => p.stock > 0 && p.stock < 10).toList();
    } else if (stockFilter == 'out') {
      result = result.where((p) => p.stock <= 0).toList();
    }
    return result;
  }

  List<Product> _sortProducts(List<Product> products, String sortBy) {
    final sorted = List<Product>.from(products);
    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'price_asc':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'stock_asc':
        sorted.sort((a, b) => a.stock.compareTo(b.stock));
        break;
    }
    return sorted;
  }

  Widget _buildProductsList(BuildContext context, WidgetRef ref,
      List<Product> products, bool isWide) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Tidak ada produk ditemukan',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Coba ubah filter atau tambah produk baru',
                style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    // Summary stats
    final totalProducts = products.length;
    final lowStock = products.where((p) => p.stock > 0 && p.stock < 10).length;
    final outOfStock = products.where((p) => p.stock <= 0).length;

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.backgroundColor,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatBadge(
                    label: 'Total',
                    value: '$totalProducts',
                    color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                _StatBadge(
                    label: 'Stok Rendah',
                    value: '$lowStock',
                    color: Colors.orange),
                const SizedBox(width: 12),
                _StatBadge(
                    label: 'Habis', value: '$outOfStock', color: Colors.red),
              ],
            ),
          ),
        ),
        // List
        Expanded(
          child: isWide
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _ProductCard(product: products[index]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _ProductListTile(product: products[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
    // Parse error message for user-friendly display
    String errorMessage = error.toString();
    bool isNetworkError = errorMessage.contains('SocketException') ||
        errorMessage.contains('TimeoutException') ||
        errorMessage.contains('Connection') ||
        errorMessage.contains('network');
    bool isTenantError =
        errorMessage.contains('Tenant') || errorMessage.contains('tenant');

    String displayMessage;
    IconData errorIcon;
    Color errorColor;

    if (isNetworkError) {
      displayMessage =
          'Tidak dapat terhubung ke server.\nData akan dimuat dari penyimpanan lokal.';
      errorIcon = Icons.cloud_off;
      errorColor = Colors.orange;
    } else if (isTenantError) {
      displayMessage = 'Sesi telah berakhir.\nSilakan login ulang.';
      errorIcon = Icons.lock_outline;
      errorColor = Colors.red;
    } else {
      displayMessage =
          'Terjadi kesalahan:\n${errorMessage.replaceAll('Exception: ', '')}';
      errorIcon = Icons.error_outline;
      errorColor = Colors.red;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(errorIcon, size: 64, color: errorColor),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: errorColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(productProvider.notifier).loadProducts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
            if (isTenantError) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Navigate to login
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text('Login Ulang'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Hot Coffee':
        return Icons.coffee;
      case 'Iced Coffee':
        return Icons.ac_unit;
      case 'Non-Coffee':
        return Icons.local_cafe;
      case 'Tea':
        return Icons.emoji_food_beverage;
      case 'Signature Drinks':
        return Icons.star;
      case 'Food':
        return Icons.restaurant;
      case 'Snacks':
        return Icons.cookie;
      case 'Dessert':
        return Icons.cake;
      default:
        return Icons.category;
    }
  }

  void _showProductDialog(BuildContext context, WidgetRef ref,
      {Product? product}) {
    showDialog(
        context: context,
        builder: (context) => ProductFormDialog(product: product));
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
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// Stat Badge Widget
class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// Product Card for Grid View
class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = product.stock > 0 && product.stock < 10;
    final isOutOfStock = product.stock <= 0;

    return Card(
      child: InkWell(
        onTap: () => _showProductDetail(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image or icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: _getCategoryColor(product.category),
                    borderRadius: BorderRadius.circular(10)),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(product.imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(_getCategoryEmoji(product.category),
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(_getCategoryEmoji(product.category),
                            style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(product.category ?? 'Tanpa Kategori',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  NumberFormat.currency(
                                          locale: 'id',
                                          symbol: 'Rp ',
                                          decimalDigits: 0)
                                      .format(product.price),
                                  style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (product.costPrice > 0)
                                Row(
                                  children: [
                                    Text(
                                      'Modal: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(product.costPrice)}',
                                      style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 10),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: product.profitMargin >= 0
                                            ? Colors.green
                                                .withValues(alpha: 0.1)
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${product.profitMarginPercent.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: product.profitMargin >= 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        _StockBadge(
                            stock: product.stock,
                            isLow: isLowStock,
                            isOut: isOutOfStock),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
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
                      value: 'stock',
                      child: Row(children: [
                        Icon(Icons.inventory, size: 18),
                        SizedBox(width: 8),
                        Text('Update Stok')
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
        ),
      ),
    );
  }

  void _showProductDetail(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (context) => ProductFormDialog(product: product));
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        showDialog(
            context: context,
            builder: (context) => ProductFormDialog(product: product));
        break;
      case 'stock':
        _showStockDialog(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showStockDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: product.stock.toString());
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Update Stok: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok saat ini: ${product.stock}',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Stok Baru',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              // Quick stock adjustment buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.remove, size: 16),
                    label: const Text('-10'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            final newVal = (current - 10).clamp(0, 999999);
                            controller.text = newVal.toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.remove, size: 16),
                    label: const Text('-1'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            final newVal = (current - 1).clamp(0, 999999);
                            controller.text = newVal.toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('+1'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            controller.text = (current + 1).toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('+10'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            controller.text = (current + 10).toString();
                          },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newStock = int.tryParse(controller.text);
                      if (newStock == null || newStock < 0) {
                        setState(() =>
                            errorText = 'Masukkan angka yang valid (≥ 0)');
                        return;
                      }

                      // Validate max stock
                      if (newStock > 999999) {
                        setState(() => errorText = 'Stok maksimal 999.999');
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await ref
                            .read(productProvider.notifier)
                            .updateStock(product.id, newStock);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Stok ${product.name} diperbarui menjadi $newStock'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() {
                            isLoading = false;
                            errorText = 'Gagal update stok: $e';
                          });
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Produk'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yakin ingin menghapus "${product.name}"?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
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
                            .read(productProvider.notifier)
                            .deleteProduct(product.id);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Produk "${product.name}" telah dihapus'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() {
                            isLoading = false;
                            errorText = 'Gagal menghapus: $e';
                          });
                        }
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

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return Colors.brown.shade100;
      case 'Iced Coffee':
        return Colors.blue.shade100;
      case 'Non-Coffee':
        return Colors.green.shade100;
      case 'Tea':
        return Colors.teal.shade100;
      case 'Signature Drinks':
        return Colors.purple.shade100;
      case 'Food':
        return Colors.orange.shade100;
      case 'Snacks':
        return Colors.amber.shade100;
      case 'Dessert':
        return Colors.pink.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return '☕';
      case 'Iced Coffee':
        return '🧊';
      case 'Non-Coffee':
        return '🥛';
      case 'Tea':
        return '🍵';
      case 'Signature Drinks':
        return '⭐';
      case 'Food':
        return '🍽️';
      case 'Snacks':
        return '🍪';
      case 'Dessert':
        return '🍰';
      default:
        return '📦';
    }
  }
}

// Stock Badge Widget
class _StockBadge extends StatelessWidget {
  final int stock;
  final bool isLow;
  final bool isOut;

  const _StockBadge(
      {required this.stock, required this.isLow, required this.isOut});

  @override
  Widget build(BuildContext context) {
    Color color = AppTheme.textMuted;
    String text = 'Stok: $stock';
    if (isOut) {
      color = Colors.red;
      text = 'Habis';
    } else if (isLow) {
      color = Colors.orange;
      text = 'Stok: $stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

// Product List Tile for Mobile
class _ProductListTile extends ConsumerWidget {
  final Product product;
  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = product.stock > 0 && product.stock < 10;
    final isOutOfStock = product.stock <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: _getCategoryColor(product.category),
              borderRadius: BorderRadius.circular(8)),
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(product.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(_getCategoryEmoji(product.category),
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
              : Center(
                  child: Text(_getCategoryEmoji(product.category),
                      style: const TextStyle(fontSize: 22))),
        ),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.category ?? 'Tanpa Kategori',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          NumberFormat.currency(
                                  locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                              .format(product.price),
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      if (product.costPrice > 0)
                        Row(
                          children: [
                            Text(
                              'Modal: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(product.costPrice)}',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 10),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: product.profitMargin >= 0
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${product.profitMarginPercent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: product.profitMargin >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _StockBadge(
                    stock: product.stock,
                    isLow: isLowStock,
                    isOut: isOutOfStock),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
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
                value: 'stock',
                child: Row(children: [
                  Icon(Icons.inventory, size: 18),
                  SizedBox(width: 8),
                  Text('Update Stok')
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
        onTap: () => showDialog(
            context: context,
            builder: (context) => ProductFormDialog(product: product)),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        showDialog(
            context: context,
            builder: (context) => ProductFormDialog(product: product));
        break;
      case 'stock':
        _showStockDialog(context, ref);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showStockDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: product.stock.toString());
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Update Stok: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok saat ini: ${product.stock}',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Stok Baru',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              // Quick stock adjustment buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.remove, size: 16),
                    label: const Text('-10'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            final newVal = (current - 10).clamp(0, 999999);
                            controller.text = newVal.toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.remove, size: 16),
                    label: const Text('-1'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            final newVal = (current - 1).clamp(0, 999999);
                            controller.text = newVal.toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('+1'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            controller.text = (current + 1).toString();
                          },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('+10'),
                    onPressed: isLoading
                        ? null
                        : () {
                            final current = int.tryParse(controller.text) ?? 0;
                            controller.text = (current + 10).toString();
                          },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newStock = int.tryParse(controller.text);
                      if (newStock == null || newStock < 0) {
                        setState(() =>
                            errorText = 'Masukkan angka yang valid (≥ 0)');
                        return;
                      }

                      if (newStock > 999999) {
                        setState(() => errorText = 'Stok maksimal 999.999');
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await ref
                            .read(productProvider.notifier)
                            .updateStock(product.id, newStock);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Stok ${product.name} diperbarui menjadi $newStock'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() {
                            isLoading = false;
                            errorText = 'Gagal update stok: $e';
                          });
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Produk'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yakin ingin menghapus "${product.name}"?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
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
                            .read(productProvider.notifier)
                            .deleteProduct(product.id);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Produk "${product.name}" telah dihapus'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() {
                            isLoading = false;
                            errorText = 'Gagal menghapus: $e';
                          });
                        }
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

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return Colors.brown.shade100;
      case 'Iced Coffee':
        return Colors.blue.shade100;
      case 'Non-Coffee':
        return Colors.green.shade100;
      case 'Tea':
        return Colors.teal.shade100;
      case 'Signature Drinks':
        return Colors.purple.shade100;
      case 'Food':
        return Colors.orange.shade100;
      case 'Snacks':
        return Colors.amber.shade100;
      case 'Dessert':
        return Colors.pink.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case 'Hot Coffee':
        return '☕';
      case 'Iced Coffee':
        return '🧊';
      case 'Non-Coffee':
        return '🥛';
      case 'Tea':
        return '🍵';
      case 'Signature Drinks':
        return '⭐';
      case 'Food':
        return '🍽️';
      case 'Snacks':
        return '🍪';
      case 'Dessert':
        return '🍰';
      default:
        return '📦';
    }
  }
}

// Product Form Dialog
class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  String? _selectedCategory;
  String? _imageBase64;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  bool get isEditing => widget.product != null;

  // Computed margin values
  double get _profitMargin {
    final price = double.tryParse(
            _priceController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0;
    final costPrice = double.tryParse(_costPriceController.text
            .replaceAll('.', '')
            .replaceAll(',', '')) ??
        0;
    return price - costPrice;
  }

  double get _profitMarginPercent {
    final costPrice = double.tryParse(_costPriceController.text
            .replaceAll('.', '')
            .replaceAll(',', '')) ??
        0;
    if (costPrice <= 0) return 0;
    return (_profitMargin / costPrice) * 100;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name);
    _barcodeController = TextEditingController(text: widget.product?.barcode);
    _priceController =
        TextEditingController(text: widget.product?.price.toStringAsFixed(0));
    _costPriceController = TextEditingController(
        text: widget.product?.costPrice.toStringAsFixed(0) ?? '0');
    _stockController =
        TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _minStockController = TextEditingController(text: '10');
    _selectedCategory = widget.product?.category;
    _imageBase64 = widget.product?.imageUrl;
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      try {
        _imageBytes = base64Decode(_imageBase64!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        // Validate image size (max 1MB)
        if (bytes.length > 1024 * 1024) {
          if (mounted) _showError('Ukuran gambar terlalu besar (maks 1MB)');
          return;
        }

        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _imageBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      if (mounted) _showError('Gagal memilih gambar: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageBase64 = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      _showError('Tenant tidak ditemukan. Silakan login ulang.');
      return;
    }

    final tenantId = authState.tenant!.id;
    if (tenantId.isEmpty) {
      _showError('ID Tenant tidak valid');
      return;
    }

    // Validate product name
    final productName = _nameController.text.trim();
    if (productName.isEmpty) {
      _showError('Nama produk wajib diisi');
      return;
    }
    if (productName.length > 100) {
      _showError('Nama produk maksimal 100 karakter');
      return;
    }

    // Validate category
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showError('Kategori wajib dipilih');
      return;
    }

    // Validate price
    final price = double.tryParse(
        _priceController.text.replaceAll('.', '').replaceAll(',', ''));
    if (price == null || price < 0) {
      _showError('Harga jual tidak valid');
      return;
    }
    if (price > 999999999) {
      _showError('Harga jual maksimal Rp 999.999.999');
      return;
    }

    // Validate cost price
    final costPrice = double.tryParse(_costPriceController.text
            .replaceAll('.', '')
            .replaceAll(',', '')) ??
        0;
    if (costPrice < 0) {
      _showError('Harga pokok tidak valid');
      return;
    }
    if (costPrice > 999999999) {
      _showError('Harga pokok maksimal Rp 999.999.999');
      return;
    }

    // Validate stock
    final stock = int.tryParse(_stockController.text);
    if (stock == null || stock < 0) {
      _showError('Stok tidak valid');
      return;
    }
    if (stock > 999999) {
      _showError('Stok maksimal 999.999');
      return;
    }

    // Validate barcode (optional but if provided, should be valid)
    final barcode = _barcodeController.text.trim();
    if (barcode.isNotEmpty && barcode.length > 50) {
      _showError('Barcode maksimal 50 karakter');
      return;
    }

    // Validate image size
    if (_imageBase64 != null && _imageBase64!.length > 1024 * 1024 * 2) {
      _showError('Ukuran gambar terlalu besar (maks 1.5MB encoded)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id ?? const Uuid().v4(),
        tenantId: tenantId,
        name: productName,
        barcode: barcode.isEmpty ? null : barcode,
        price: price,
        costPrice: costPrice,
        stock: stock,
        category: _selectedCategory,
        imageUrl: _imageBase64,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );

      if (isEditing) {
        await ref.read(productProvider.notifier).updateProduct(product);
        if (mounted) _showSuccess('Produk berhasil diperbarui');
      } else {
        await ref.read(productProvider.notifier).addProduct(product);
        if (mounted) _showSuccess('Produk berhasil ditambahkan');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // Parse error for user-friendly message
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        _showError('Gagal menyimpan: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  Widget _buildMarginDisplay() {
    final margin = _profitMargin;
    final marginPercent = _profitMarginPercent;
    final isPositive = margin > 0;
    final isNegative = margin < 0;

    Color marginColor = AppTheme.textMuted;
    IconData marginIcon = Icons.remove;
    if (isPositive) {
      marginColor = Colors.green;
      marginIcon = Icons.trending_up;
    } else if (isNegative) {
      marginColor = Colors.red;
      marginIcon = Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: marginColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: marginColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(marginIcon, color: marginColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Margin Keuntungan',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${NumberFormat('#,###').format(margin.abs())}${isNegative ? ' (Rugi)' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: marginColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: marginColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${marginPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: marginColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.add_box,
              color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit Produk' : 'Tambah Produk'),
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
                // Image Upload
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: _imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_imageBytes!,
                                    fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 40, color: AppTheme.textMuted),
                                  const SizedBox(height: 4),
                                  Text('Tambah Foto',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted)),
                                ],
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_imageBytes != null)
                              InkWell(
                                onTap: _removeImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nama Produk *',
                      prefixIcon: Icon(Icons.label)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama produk wajib diisi'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Kategori *',
                      prefixIcon: Icon(Icons.category)),
                  items: coffeeShopCategories
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) => v == null ? 'Pilih kategori' : null,
                ),
                const SizedBox(height: 16),
                // Cost Price (Harga Pokok)
                TextFormField(
                  controller: _costPriceController,
                  decoration: const InputDecoration(
                      labelText: 'Harga Pokok/Modal',
                      prefixIcon: Icon(Icons.money_off),
                      prefixText: 'Rp ',
                      hintText: '0'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                // Selling Price (Harga Jual)
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                      labelText: 'Harga Jual *',
                      prefixIcon: Icon(Icons.sell),
                      prefixText: 'Rp '),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Harga jual wajib diisi';
                    final price = double.tryParse(v.replaceAll('.', ''));
                    if (price == null || price <= 0) return 'Harga tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Margin Display
                _buildMarginDisplay(),
                const SizedBox(height: 16),
                // Stock
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                            labelText: 'Stok *',
                            prefixIcon: Icon(Icons.inventory)),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Stok wajib diisi';
                          final stock = int.tryParse(v);
                          if (stock == null || stock < 0) {
                            return 'Stok tidak valid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barcode (optional)
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                      labelText: 'Barcode (opsional)',
                      prefixIcon: Icon(Icons.qr_code)),
                ),
                const SizedBox(height: 24),
                // Quick price buttons
                const Text('Harga Cepat:',
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15000, 20000, 25000, 30000, 35000, 40000]
                      .map((price) => ActionChip(
                            label: Text(
                                'Rp ${NumberFormat('#,###').format(price)}'),
                            onPressed: () => setState(
                                () => _priceController.text = price.toString()),
                          ))
                      .toList(),
                ),
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
          onPressed: _isLoading ? null : _save,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(isEditing ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
