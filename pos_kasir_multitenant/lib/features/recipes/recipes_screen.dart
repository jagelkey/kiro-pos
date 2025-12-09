import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/offline_indicator.dart';
import '../../data/models/product.dart';
import '../../data/models/material.dart' as mat;
import '../products/products_provider.dart';
import '../materials/materials_provider.dart';
import 'recipes_provider.dart';

// Filter providers
final recipeSearchProvider = StateProvider<String>((ref) => '');
final recipeFilterProvider = StateProvider<String>((ref) => 'all');
final recipeCategoryFilterProvider = StateProvider<String?>((ref) => null);

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productProvider);
    final materialsAsync = ref.watch(materialsProvider);
    final recipesAsync = ref.watch(recipeNotifierProvider);
    final searchQuery = ref.watch(recipeSearchProvider);
    final recipeFilter = ref.watch(recipeFilterProvider);
    final categoryFilter = ref.watch(recipeCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('🧪 Manajemen Resep'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(productProvider.notifier).loadProducts();
              ref.read(recipeNotifierProvider.notifier).loadRecipes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator for Android
          if (!kIsWeb) const OfflineIndicator(),
          Expanded(
            child: productsAsync.when(
              data: (products) => materialsAsync.when(
                data: (materials) => recipesAsync.when(
                  data: (recipes) {
                    var filtered = _filterProducts(products, recipes,
                        searchQuery, recipeFilter, categoryFilter);
                    return _buildContent(
                        context, ref, filtered, materials, recipes);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _buildErrorWidget(context, ref, e, 'resep'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    _buildErrorWidget(context, ref, e, 'bahan baku'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(context, ref, e, 'produk'),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _filterProducts(
    List<Product> products,
    Map<String, List<RecipeIngredient>> recipes,
    String search,
    String recipeFilter,
    String? category,
  ) {
    var result = products;

    if (search.isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    if (category != null) {
      result = result.where((p) => p.category == category).toList();
    }

    if (recipeFilter == 'with_recipe') {
      result = result.where((p) => recipes.containsKey(p.id)).toList();
    } else if (recipeFilter == 'no_recipe') {
      result = result.where((p) => !recipes.containsKey(p.id)).toList();
    }

    return result;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Product> products,
    List<mat.Material> materials,
    Map<String, List<RecipeIngredient>> recipes,
  ) {
    final repository = ref.read(recipeRepositoryProvider);
    final authState = ref.read(authProvider);
    final tenantId = authState.tenant?.id ?? '';

    final capacity =
        repository.calculateAllProductCapacity(tenantId, materials, recipes);
    final withRecipe = products.where((p) => recipes.containsKey(p.id)).length;
    final noRecipe = products.where((p) => !recipes.containsKey(p.id)).length;
    final canProduce = capacity.values.where((v) => v > 0).length;
    final cantProduce = capacity.values.where((v) => v == 0).length;

    return Column(
      children: [
        _buildSearchFilter(context, ref),
        _buildStats(withRecipe, noRecipe, canProduce, cantProduce),
        Expanded(
          child: products.isEmpty
              ? _buildEmptyState(ref)
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(productProvider.notifier).loadProducts();
                    await ref.read(materialsProvider.notifier).loadMaterials();
                    await ref
                        .read(recipeNotifierProvider.notifier)
                        .loadRecipes();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) => _RecipeCard(
                      product: products[index],
                      materials: materials,
                      recipes: recipes,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchFilter(BuildContext context, WidgetRef ref) {
    final recipeFilter = ref.watch(recipeFilterProvider);
    final categoryFilter = ref.watch(recipeCategoryFilterProvider);

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
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => ref.read(recipeSearchProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: recipeFilter == 'all'
                      ? 'Semua'
                      : recipeFilter == 'with_recipe'
                          ? 'Punya Resep'
                          : 'Tanpa Resep',
                  icon: Icons.filter_list,
                  isSelected: recipeFilter != 'all',
                  onTap: () => _showRecipeFilterPicker(context, ref),
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

  void _showRecipeFilterPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Semua Produk'),
              onTap: () {
                ref.read(recipeFilterProvider.notifier).state = 'all';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Punya Resep'),
              onTap: () {
                ref.read(recipeFilterProvider.notifier).state = 'with_recipe';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.orange),
              title: const Text('Tanpa Resep'),
              onTap: () {
                ref.read(recipeFilterProvider.notifier).state = 'no_recipe';
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    final categories = [
      'Hot Coffee',
      'Iced Coffee',
      'Non-Coffee',
      'Tea',
      'Signature Drinks',
      'Food',
      'Snacks',
      'Dessert'
    ];
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
                ref.read(recipeCategoryFilterProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...categories.map((cat) => ListTile(
                  title: Text(cat),
                  onTap: () {
                    ref.read(recipeCategoryFilterProvider.notifier).state = cat;
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(
      int withRecipe, int noRecipe, int canProduce, int cantProduce) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.backgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatBadge(
                label: 'Punya Resep',
                value: '$withRecipe',
                color: Colors.green),
            const SizedBox(width: 12),
            _StatBadge(
                label: 'Tanpa Resep', value: '$noRecipe', color: Colors.orange),
            const SizedBox(width: 12),
            _StatBadge(
                label: 'Bisa Dibuat', value: '$canProduce', color: Colors.blue),
            const SizedBox(width: 12),
            _StatBadge(
                label: 'Bahan Habis', value: '$cantProduce', color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    final searchQuery = ref.watch(recipeSearchProvider);
    final recipeFilter = ref.watch(recipeFilterProvider);
    final categoryFilter = ref.watch(recipeCategoryFilterProvider);
    final hasFilters = searchQuery.isNotEmpty ||
        recipeFilter != 'all' ||
        categoryFilter != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.science_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'Tidak ada hasil' : 'Tidak ada produk ditemukan',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Coba ubah filter atau kata kunci pencarian'
                : 'Tambah produk terlebih dahulu',
            style: TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref.read(recipeSearchProvider.notifier).state = '';
                ref.read(recipeFilterProvider.notifier).state = 'all';
                ref.read(recipeCategoryFilterProvider.notifier).state = null;
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Hapus Filter'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget(
      BuildContext context, WidgetRef ref, Object error, String dataType) {
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
              'Gagal memuat $dataType',
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
              onPressed: () {
                ref.read(productProvider.notifier).loadProducts();
                ref.read(materialsProvider.notifier).loadMaterials();
                ref.read(recipeNotifierProvider.notifier).loadRecipes();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

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

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

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

// Recipe Card Widget with multi-tenant support
class _RecipeCard extends ConsumerWidget {
  final Product product;
  final List<mat.Material> materials;
  final Map<String, List<RecipeIngredient>> recipes;

  const _RecipeCard({
    required this.product,
    required this.materials,
    required this.recipes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRecipe = recipes.containsKey(product.id);
    final recipe = recipes[product.id];
    final repository = ref.read(recipeRepositoryProvider);
    final authState = ref.read(authProvider);
    final tenantId = authState.tenant?.id ?? '';

    final maxServings = hasRecipe
        ? repository.calculateMaxServings(
            tenantId, product.id, materials, recipes)
        : -1;
    final canProduce = maxServings > 0;
    final ingredientCount = recipe?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRecipeDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(product.category),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                        child: Text(_getCategoryEmoji(product.category),
                            style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(product.category ?? 'Tanpa Kategori',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusBadge(hasRecipe, canProduce, maxServings),
                ],
              ),
              if (hasRecipe && recipe != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.restaurant_menu,
                        label: '$ingredientCount bahan'),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: canProduce ? Icons.check_circle : Icons.warning,
                      label: canProduce
                          ? 'Bisa dibuat $maxServings porsi'
                          : 'Bahan habis',
                      color: canProduce ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildIngredientsPreview(recipe),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Belum ada resep. Tap untuk membuat resep.',
                          style: TextStyle(
                              color: Colors.orange.shade700, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.orange.shade700, size: 16),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool hasRecipe, bool canProduce, int maxServings) {
    if (!hasRecipe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined,
                size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text('Tanpa Resep',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: canProduce ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(canProduce ? Icons.check_circle : Icons.error,
              size: 14,
              color: canProduce ? Colors.green.shade700 : Colors.red.shade700),
          const SizedBox(width: 4),
          Text(
            canProduce ? '$maxServings porsi' : 'Bahan habis',
            style: TextStyle(
                fontSize: 11,
                color: canProduce ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsPreview(List<RecipeIngredient> recipe) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: recipe.take(4).map((ing) {
        final material = materials.firstWhere(
          (m) => m.id == ing.materialId,
          orElse: () => mat.Material(
              id: '',
              tenantId: '',
              name: ing.name,
              stock: 0,
              unit: ing.unit,
              createdAt: DateTime.now()),
        );
        final isAvailable = material.stock >= ing.quantity;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    isAvailable ? Colors.green.shade200 : Colors.red.shade200),
          ),
          child: Text(
            ing.name,
            style: TextStyle(
                fontSize: 11,
                color:
                    isAvailable ? Colors.green.shade700 : Colors.red.shade700),
          ),
        );
      }).toList()
        ..addAll(recipe.length > 4
            ? [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+${recipe.length - 4} lagi',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
              ]
            : []),
    );
  }

  void _showRecipeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => RecipeEditDialog(
        product: product,
        materials: materials,
        existingRecipe: recipes[product.id],
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

// Recipe Edit Dialog with multi-tenant support
class RecipeEditDialog extends ConsumerStatefulWidget {
  final Product product;
  final List<mat.Material> materials;
  final List<RecipeIngredient>? existingRecipe;

  const RecipeEditDialog({
    super.key,
    required this.product,
    required this.materials,
    this.existingRecipe,
  });

  @override
  ConsumerState<RecipeEditDialog> createState() => _RecipeEditDialogState();
}

class _RecipeEditDialogState extends ConsumerState<RecipeEditDialog> {
  late List<RecipeIngredient> _ingredients;
  int _preparationTime = 5;
  String _difficulty = 'easy';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  void _loadRecipe() {
    _ingredients = widget.existingRecipe != null
        ? widget.existingRecipe!.map((i) => i.copyWith()).toList()
        : [];
  }

  @override
  Widget build(BuildContext context) {
    final hasRecipe = _ingredients.isNotEmpty;
    final maxServings = hasRecipe ? _calculateMaxServings() : 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasRecipe) _buildCapacityCard(maxServings),
                    const SizedBox(height: 16),
                    _buildIngredientsSection(),
                    const SizedBox(height: 16),
                    _buildSettingsSection(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.science, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resep ${widget.product.name}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(widget.product.category ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildCapacityCard(int maxServings) {
    final canProduce = maxServings > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canProduce
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(canProduce ? Icons.check_circle : Icons.warning,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(canProduce ? 'Bisa Diproduksi' : 'Tidak Bisa Diproduksi',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12)),
                Text(canProduce ? '$maxServings porsi' : 'Bahan habis',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📋 Bahan-bahan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddIngredientDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Bahan'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ingredients.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Belum ada bahan', style: TextStyle(color: Colors.grey)),
                  Text('Klik "Tambah Bahan" untuk memulai',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ..._ingredients
              .asMap()
              .entries
              .map((entry) => _buildIngredientItem(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildIngredientItem(int index, RecipeIngredient ingredient) {
    final material = widget.materials.firstWhere(
      (m) => m.id == ingredient.materialId,
      orElse: () => mat.Material(
          id: '',
          tenantId: '',
          name: ingredient.name,
          stock: 0,
          unit: ingredient.unit,
          createdAt: DateTime.now()),
    );
    final isAvailable = material.stock >= ingredient.quantity;
    final maxServings = ingredient.quantity > 0
        ? (material.stock / ingredient.quantity).floor()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isAvailable ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isAvailable ? Icons.check : Icons.close,
                color: isAvailable ? Colors.green : Colors.red, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_formatQuantity(ingredient.quantity, ingredient.unit)} per porsi • Stok: ${_formatQuantity(material.stock, material.unit)} (≈$maxServings porsi)',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showEditQuantityDialog(index),
            color: AppTheme.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () => setState(() => _ingredients.removeAt(index)),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚙️ Pengaturan Resep',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Waktu Persiapan', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    initialValue: _preparationTime,
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [3, 5, 10, 15, 20, 30]
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text('$m menit')))
                        .toList(),
                    onChanged: (v) => setState(() => _preparationTime = v ?? 5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tingkat Kesulitan',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('🟢 Mudah')),
                      DropdownMenuItem(
                          value: 'medium', child: Text('🟡 Sedang')),
                      DropdownMenuItem(value: 'hard', child: Text('🔴 Sulit')),
                    ],
                    onChanged: (v) => setState(() => _difficulty = v ?? 'easy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (_ingredients.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _confirmDeleteRecipe,
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              label: const Text('Hapus Resep',
                  style: TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Batal')),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRecipe,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, size: 18),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog() {
    final availableMaterials = widget.materials
        .where((m) => !_ingredients.any((i) => i.materialId == m.id))
        .toList();

    if (availableMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Semua bahan sudah ditambahkan'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    mat.Material? selectedMaterial;
    final qtyController = TextEditingController(text: '0.1');
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Tambah Bahan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<mat.Material>(
                decoration: const InputDecoration(
                  labelText: 'Pilih Bahan',
                  prefixIcon: Icon(Icons.inventory),
                ),
                items: availableMaterials
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('${m.name} (stok: ${m.stock} ${m.unit})')))
                    .toList(),
                onChanged: (v) => setDialogState(() {
                  selectedMaterial = v;
                  errorText = null;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: 'Jumlah per Porsi',
                  suffixText: selectedMaterial?.unit ?? '',
                  prefixIcon: const Icon(Icons.scale),
                  errorText: errorText,
                  helperText: selectedMaterial != null
                      ? 'Stok tersedia: ${selectedMaterial!.stock} ${selectedMaterial!.unit}'
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: selectedMaterial == null
                  ? null
                  : () {
                      final qty = double.tryParse(qtyController.text);
                      if (qty == null || qty <= 0) {
                        setDialogState(() =>
                            errorText = 'Masukkan jumlah yang valid (> 0)');
                        return;
                      }
                      setState(() {
                        _ingredients.add(RecipeIngredient(
                          materialId: selectedMaterial!.id,
                          quantity: qty,
                          unit: selectedMaterial!.unit,
                          name: selectedMaterial!.name,
                        ));
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${selectedMaterial!.name} ditambahkan'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuantityDialog(int index) {
    final ingredient = _ingredients[index];
    final qtyController =
        TextEditingController(text: ingredient.quantity.toString());
    String? errorText;

    final material = widget.materials.firstWhere(
      (m) => m.id == ingredient.materialId,
      orElse: () => mat.Material(
          id: '',
          tenantId: '',
          name: ingredient.name,
          stock: 0,
          unit: ingredient.unit,
          createdAt: DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit ${ingredient.name}')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: 'Jumlah per Porsi',
                  suffixText: ingredient.unit,
                  prefixIcon: const Icon(Icons.scale),
                  errorText: errorText,
                  helperText:
                      'Stok tersedia: ${material.stock} ${material.unit}',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.01, 0.05, 0.1, 0.5, 1.0]
                    .map((qty) => ActionChip(
                          label: Text('$qty'),
                          onPressed: () {
                            qtyController.text = qty.toString();
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) {
                  setDialogState(
                      () => errorText = 'Masukkan jumlah yang valid (> 0)');
                  return;
                }
                setState(() =>
                    _ingredients[index] = ingredient.copyWith(quantity: qty));
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecipe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Resep'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yakin ingin menghapus resep ${widget.product.name}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRecipe();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(recipeNotifierProvider.notifier)
          .deleteRecipe(widget.product.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resep ${widget.product.name} dihapus'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Extract clean error message
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus resep: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveRecipe() async {
    // Validate ingredients
    if (_ingredients.isNotEmpty) {
      for (var ingredient in _ingredients) {
        if (ingredient.quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jumlah ${ingredient.name} harus lebih dari 0'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      if (_ingredients.isEmpty) {
        await ref
            .read(recipeNotifierProvider.notifier)
            .deleteRecipe(widget.product.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resep ${widget.product.name} dihapus'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await ref
            .read(recipeNotifierProvider.notifier)
            .saveRecipe(widget.product.id, _ingredients);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resep ${widget.product.name} berhasil disimpan!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Extract clean error message
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan resep: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int _calculateMaxServings() {
    if (_ingredients.isEmpty) return 0;
    int maxServings = 999999;
    for (var ingredient in _ingredients) {
      final material = widget.materials.firstWhere(
        (m) => m.id == ingredient.materialId,
        orElse: () => mat.Material(
            id: '',
            tenantId: '',
            name: '',
            stock: 0,
            unit: '',
            createdAt: DateTime.now()),
      );
      if (material.id.isEmpty || material.stock <= 0) return 0;
      if (ingredient.quantity > 0) {
        final possibleServings = (material.stock / ingredient.quantity).floor();
        if (possibleServings < maxServings) maxServings = possibleServings;
      }
    }
    return maxServings == 999999 ? 0 : maxServings;
  }

  String _formatQuantity(double quantity, String unit) {
    if (quantity >= 1) {
      return '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)} $unit';
    } else if (unit == 'kg') {
      return '${(quantity * 1000).toStringAsFixed(0)} g';
    } else if (unit == 'liter') {
      return '${(quantity * 1000).toStringAsFixed(0)} ml';
    }
    return '${quantity.toStringAsFixed(3)} $unit';
  }
}
