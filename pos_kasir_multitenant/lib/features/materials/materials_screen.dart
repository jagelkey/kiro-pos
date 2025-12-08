import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/material.dart' as mat;
import '../../data/repositories/material_repository.dart' show StockMovement;
import 'materials_provider.dart';
import '../products/products_provider.dart';
import '../recipes/recipes_provider.dart';

// Coffee shop material categories
const List<String> materialCategories = [
  'Biji Kopi',
  'Susu & Dairy',
  'Sirup & Sauce',
  'Bubuk & Powder',
  'Teh & Herbal',
  'Gula & Pemanis',
  'Topping',
  'Kemasan',
  'Lainnya',
];

// Common units for coffee shop
const List<String> materialUnits = [
  'kg',
  'gram',
  'liter',
  'ml',
  'pcs',
  'pack',
  'botol',
  'sachet',
];

// Search and filter providers
final materialSearchProvider = StateProvider<String>((ref) => '');
final materialCategoryFilterProvider = StateProvider<String?>((ref) => null);
final materialStockFilterProvider = StateProvider<String>((ref) => 'all');

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsProvider);
    final searchQuery = ref.watch(materialSearchProvider);
    final categoryFilter = ref.watch(materialCategoryFilterProvider);
    final stockFilter = ref.watch(materialStockFilterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('🧪 Bahan Baku'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(materialsProvider.notifier).loadMaterials(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchFilterBar(context, ref),
          Expanded(
            child: materialsAsync.when(
              data: (materials) {
                var filtered = _filterMaterials(
                    materials, searchQuery, categoryFilter, stockFilter);
                return _buildMaterialsList(context, ref, filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(context, ref, e),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMaterialDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bahan'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildSearchFilterBar(BuildContext context, WidgetRef ref) {
    final categoryFilter = ref.watch(materialCategoryFilterProvider);
    final stockFilter = ref.watch(materialStockFilterProvider);

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
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari bahan baku...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) =>
                ref.read(materialSearchProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: categoryFilter ?? 'Semua Kategori',
                  icon: Icons.category,
                  isSelected: categoryFilter != null,
                  onTap: () => _showCategoryPicker(context, ref),
                ),
                const SizedBox(width: 8),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Semua Kategori'),
                onTap: () {
                  ref.read(materialCategoryFilterProvider.notifier).state =
                      null;
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...materialCategories.map((cat) => ListTile(
                    leading: Icon(_getCategoryIcon(cat)),
                    title: Text(cat),
                    onTap: () {
                      ref.read(materialCategoryFilterProvider.notifier).state =
                          cat;
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
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
                ref.read(materialStockFilterProvider.notifier).state = 'all';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Stok Rendah'),
              onTap: () {
                ref.read(materialStockFilterProvider.notifier).state = 'low';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Stok Habis'),
              onTap: () {
                ref.read(materialStockFilterProvider.notifier).state = 'out';
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<mat.Material> _filterMaterials(List<mat.Material> materials,
      String search, String? category, String stockFilter) {
    var result = materials;
    if (search.isNotEmpty) {
      result = result
          .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    if (category != null) {
      result = result.where((m) => m.category == category).toList();
    }
    // Use Material model's built-in properties for filtering (Requirements 3.4)
    if (stockFilter == 'low') {
      result = result.where((m) => m.isLowStock).toList();
    } else if (stockFilter == 'out') {
      result = result.where((m) => m.isOutOfStock).toList();
    }
    return result;
  }

  Widget _buildMaterialsList(
      BuildContext context, WidgetRef ref, List<mat.Material> materials) {
    final searchQuery = ref.watch(materialSearchProvider);
    final categoryFilter = ref.watch(materialCategoryFilterProvider);
    final stockFilter = ref.watch(materialStockFilterProvider);
    final hasFilters = searchQuery.isNotEmpty ||
        categoryFilter != null ||
        stockFilter != 'all';

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'Tidak ada hasil' : 'Tidak ada bahan baku',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Coba ubah filter atau kata kunci pencarian'
                  : 'Tambah bahan baku untuk memulai',
              style: TextStyle(color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(materialSearchProvider.notifier).state = '';
                  ref.read(materialCategoryFilterProvider.notifier).state =
                      null;
                  ref.read(materialStockFilterProvider.notifier).state = 'all';
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Hapus Filter'),
              ),
            ],
          ],
        ),
      );
    }

    // Stats - using Material model's built-in properties (Requirements 3.4)
    final totalMaterials = materials.length;
    final lowStock = materials.where((m) => m.isLowStock).length;
    final outOfStock = materials.where((m) => m.isOutOfStock).length;

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.backgroundColor,
          child: Row(
            children: [
              _StatBadge(
                  label: 'Total',
                  value: '$totalMaterials',
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(materialsProvider.notifier).loadMaterials(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: materials.length,
              itemBuilder: (context, index) =>
                  _MaterialCard(material: materials[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
    // Extract clean error message
    String errorMessage = error.toString();
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring(11);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(materialsProvider.notifier).loadMaterials(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Biji Kopi':
        return Icons.coffee;
      case 'Susu & Dairy':
        return Icons.water_drop;
      case 'Sirup & Sauce':
        return Icons.local_drink;
      case 'Bubuk & Powder':
        return Icons.grain;
      case 'Teh & Herbal':
        return Icons.eco;
      case 'Gula & Pemanis':
        return Icons.cake;
      case 'Topping':
        return Icons.stars;
      case 'Kemasan':
        return Icons.inventory_2;
      default:
        return Icons.category;
    }
  }

  void _showMaterialDialog(BuildContext context, WidgetRef ref,
      {mat.Material? material}) {
    showDialog(
        context: context,
        builder: (context) => MaterialFormDialog(material: material));
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

// Material Card Widget
class _MaterialCard extends ConsumerWidget {
  final mat.Material material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Material model's built-in low stock detection (Requirements 3.4)
    final isLowStock = material.isLowStock;
    final isOutOfStock = material.isOutOfStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showDialog(
            context: context,
            builder: (context) => MaterialFormDialog(material: material)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getCategoryColor(material.category),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(_getCategoryEmoji(material.category),
                        style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(material.category ?? 'Tanpa Kategori',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${_formatStock(material.stock)} ${material.unit}',
                            style: TextStyle(
                              color: isOutOfStock
                                  ? Colors.red
                                  : isLowStock
                                      ? Colors.orange
                                      : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            )),
                        if (material.minStock != null) ...[
                          const SizedBox(width: 8),
                          Text('(min: ${_formatStock(material.minStock!)})',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                        const Spacer(),
                        _StockBadge(isLow: isLowStock, isOut: isOutOfStock),
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
                      value: 'products',
                      child: Row(children: [
                        Icon(Icons.coffee, size: 18, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Lihat Produk',
                            style: TextStyle(color: Colors.purple))
                      ])),
                  const PopupMenuItem(
                      value: 'history',
                      child: Row(children: [
                        Icon(Icons.history, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Riwayat Stok',
                            style: TextStyle(color: Colors.blue))
                      ])),
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
                        Icon(Icons.add_circle, size: 18),
                        SizedBox(width: 8),
                        Text('Tambah Stok')
                      ])),
                  const PopupMenuItem(
                      value: 'use',
                      child: Row(children: [
                        Icon(Icons.remove_circle, size: 18),
                        SizedBox(width: 8),
                        Text('Gunakan Stok')
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

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'products':
        _showProductsUsingMaterial(context, ref);
        break;
      case 'history':
        _showStockHistory(context, ref);
        break;
      case 'edit':
        showDialog(
            context: context,
            builder: (context) => MaterialFormDialog(material: material));
        break;
      case 'stock':
        _showStockAdjustDialog(context, ref, true);
        break;
      case 'use':
        _showStockAdjustDialog(context, ref, false);
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showProductsUsingMaterial(BuildContext context, WidgetRef ref) {
    // Find products that use this material (multi-tenant)
    final productsUsingMaterial = <String, double>{};
    final recipes = ref.read(recipeNotifierProvider).valueOrNull ?? {};
    final products = ref.read(productProvider).valueOrNull ?? [];

    for (var entry in recipes.entries) {
      for (var ingredient in entry.value) {
        if (ingredient.materialId == material.id) {
          try {
            final product = products.firstWhere((p) => p.id == entry.key);
            productsUsingMaterial[product.name] = ingredient.quantity;
          } catch (_) {
            // Product not found, skip
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.coffee, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Produk yang Menggunakan'),
                  Text(material.name,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: productsUsingMaterial.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('Tidak ada produk yang menggunakan bahan ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory,
                              color: Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                              'Stok: ${_formatStock(material.stock)} ${material.unit}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${productsUsingMaterial.length} produk',
                              style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...productsUsingMaterial.entries.map((entry) {
                      final maxServings = material.stock > 0
                          ? (material.stock / entry.value).floor()
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Text('☕', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${_formatStock(entry.value)} ${material.unit}/porsi',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: maxServings > 0
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  maxServings > 0
                                      ? '≈$maxServings porsi'
                                      : 'Habis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: maxServings > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  /// Show stock movement history dialog
  /// Requirements 3.2: Record stock movement with timestamp and reason
  void _showStockHistory(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<StockMovement> movements = [];
    try {
      movements = await ref
          .read(materialsProvider.notifier)
          .getStockMovements(material.id);
    } catch (e) {
      debugPrint('Error loading stock movements: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Riwayat Stok'),
                  Text(material.name,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: movements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('Belum ada riwayat perubahan stok',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: movements.length,
                  itemBuilder: (context, index) {
                    final movement = movements[index];
                    final isIncrease = movement.change > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isIncrease
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isIncrease
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isIncrease ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${isIncrease ? '+' : ''}${_formatStock(movement.change)} ${material.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isIncrease ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  _getReasonLabel(movement.reason),
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.textMuted),
                                ),
                                if (movement.note != null &&
                                    movement.note!.isNotEmpty)
                                  Text(
                                    movement.note!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_formatStock(movement.previousStock)} → ${_formatStock(movement.newStock)}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _formatDateTime(movement.timestamp),
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _getReasonLabel(String reason) {
    switch (reason) {
      case 'initial':
        return 'Stok Awal';
      case 'purchase':
        return 'Pembelian';
      case 'sale':
        return 'Penjualan';
      case 'adjustment':
        return 'Penyesuaian';
      case 'waste':
        return 'Terbuang';
      default:
        return reason;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showStockAdjustDialog(BuildContext context, WidgetRef ref, bool isAdd) {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    String? errorText;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(isAdd ? Icons.add_circle : Icons.remove_circle,
                  color: isAdd ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(isAdd ? 'Tambah Stok' : 'Gunakan Stok'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(material.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                  'Stok saat ini: ${_formatStock(material.stock)} ${material.unit}',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Jumlah (${material.unit})',
                  prefixIcon: Icon(isAdd ? Icons.add : Icons.remove),
                  errorText: errorText,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    prefixIcon: Icon(Icons.note)),
              ),
              const SizedBox(height: 12),
              // Quick amount buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.5, 1, 5, 10]
                    .map((amount) => ActionChip(
                          label: Text('+$amount'),
                          onPressed: () {
                            final current =
                                double.tryParse(controller.text) ?? 0;
                            controller.text = (current + amount).toString();
                          },
                        ))
                    .toList(),
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
                  backgroundColor: isAdd ? Colors.green : Colors.orange),
              onPressed: isLoading
                  ? null
                  : () async {
                      final amount = double.tryParse(controller.text);
                      if (amount == null || amount <= 0) {
                        setState(() =>
                            errorText = 'Masukkan jumlah yang valid (> 0)');
                        return;
                      }

                      final newStock = isAdd
                          ? material.stock + amount
                          : material.stock - amount;
                      if (newStock < 0) {
                        setState(() => errorText =
                            'Stok tidak mencukupi (tersedia: ${_formatStock(material.stock)})');
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Use updateStock with reason for proper stock movement recording
                        await ref.read(materialsProvider.notifier).updateStock(
                              material.id,
                              newStock,
                              reason: isAdd ? 'purchase' : 'adjustment',
                              note: noteController.text.trim().isEmpty
                                  ? (isAdd
                                      ? 'Penambahan stok manual'
                                      : 'Penggunaan stok manual')
                                  : noteController.text.trim(),
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${isAdd ? "Ditambahkan" : "Digunakan"} ${_formatStock(amount)} ${material.unit}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        // Extract clean error message
                        String errorMessage = e.toString();
                        if (errorMessage.startsWith('Exception: ')) {
                          errorMessage = errorMessage.substring(11);
                        }
                        setState(() {
                          isLoading = false;
                          errorText = errorMessage;
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
                  : Text(isAdd ? 'Tambah' : 'Gunakan'),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Bahan Baku'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yakin ingin menghapus "${material.name}"?',
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
                            .read(materialsProvider.notifier)
                            .deleteMaterial(material.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Bahan baku "${material.name}" telah dihapus'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          // Extract clean error message
                          String errorMessage = e.toString();
                          if (errorMessage.startsWith('Exception: ')) {
                            errorMessage = errorMessage.substring(11);
                          }
                          errorText = errorMessage;
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

  String _formatStock(double stock) {
    return stock == stock.roundToDouble()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(1);
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Biji Kopi':
        return Colors.brown.shade100;
      case 'Susu & Dairy':
        return Colors.blue.shade100;
      case 'Sirup & Sauce':
        return Colors.purple.shade100;
      case 'Bubuk & Powder':
        return Colors.orange.shade100;
      case 'Teh & Herbal':
        return Colors.green.shade100;
      case 'Gula & Pemanis':
        return Colors.pink.shade100;
      case 'Topping':
        return Colors.amber.shade100;
      case 'Kemasan':
        return Colors.grey.shade200;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case 'Biji Kopi':
        return '☕';
      case 'Susu & Dairy':
        return '🥛';
      case 'Sirup & Sauce':
        return '🍯';
      case 'Bubuk & Powder':
        return '🧂';
      case 'Teh & Herbal':
        return '🍵';
      case 'Gula & Pemanis':
        return '🍬';
      case 'Topping':
        return '⭐';
      case 'Kemasan':
        return '📦';
      default:
        return '🧪';
    }
  }
}

// Stock Badge Widget
class _StockBadge extends StatelessWidget {
  final bool isLow;
  final bool isOut;

  const _StockBadge({required this.isLow, required this.isOut});

  @override
  Widget build(BuildContext context) {
    if (!isLow && !isOut) return const SizedBox.shrink();

    final color = isOut ? Colors.red : Colors.orange;
    final text = isOut ? 'Habis' : 'Rendah';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// Material Form Dialog
class MaterialFormDialog extends ConsumerStatefulWidget {
  final mat.Material? material;
  const MaterialFormDialog({super.key, this.material});

  @override
  ConsumerState<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends ConsumerState<MaterialFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  String? _selectedCategory;
  String _selectedUnit = 'kg';
  bool _isLoading = false;

  bool get isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material?.name);
    _stockController =
        TextEditingController(text: widget.material?.stock.toString() ?? '0');
    _minStockController = TextEditingController(
        text: widget.material?.minStock?.toString() ?? '');
    _selectedCategory = widget.material?.category;
    _selectedUnit = widget.material?.unit ?? 'kg';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (authState.tenant == null) {
      _showError('Tenant tidak ditemukan');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final material = mat.Material(
        id: widget.material?.id ?? const Uuid().v4(),
        tenantId: authState.tenant!.id,
        name: _nameController.text.trim(),
        stock: double.tryParse(_stockController.text) ?? 0,
        unit: _selectedUnit,
        minStock: _minStockController.text.isEmpty
            ? null
            : double.tryParse(_minStockController.text),
        category: _selectedCategory,
        createdAt: widget.material?.createdAt ?? DateTime.now(),
      );

      if (isEditing) {
        await ref.read(materialsProvider.notifier).updateMaterial(material);
        _showSuccess('Bahan baku berhasil diperbarui');
      } else {
        await ref.read(materialsProvider.notifier).addMaterial(material);
        _showSuccess('Bahan baku berhasil ditambahkan');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Extract clean error message
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      _showError(errorMessage);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.add_box,
              color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit Bahan Baku' : 'Tambah Bahan Baku'),
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
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nama Bahan *', prefixIcon: Icon(Icons.label)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama bahan wajib diisi'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                // Category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Kategori', prefixIcon: Icon(Icons.category)),
                  items: materialCategories
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
                const SizedBox(height: 16),
                // Stock and Unit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                            labelText: 'Stok *',
                            prefixIcon: Icon(Icons.inventory)),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Stok wajib diisi';
                          final stock = double.tryParse(v);
                          if (stock == null) {
                            return 'Angka tidak valid';
                          }
                          if (stock < 0) {
                            return 'Stok tidak boleh negatif';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUnit,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: materialUnits
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedUnit = v ?? 'kg'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Min Stock
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Stok Minimum (opsional)',
                    prefixIcon: Icon(Icons.warning_amber),
                    helperText:
                        'Alert akan muncul jika stok di bawah nilai ini',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null; // Optional field
                    final minStock = double.tryParse(v);
                    if (minStock == null) {
                      return 'Angka tidak valid';
                    }
                    if (minStock < 0) {
                      return 'Stok minimum tidak boleh negatif';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Quick stock buttons
                const Text('Stok Cepat:',
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 5, 10, 20, 50, 100]
                      .map((stock) => ActionChip(
                            label: Text('$stock'),
                            onPressed: () => setState(
                                () => _stockController.text = stock.toString()),
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
