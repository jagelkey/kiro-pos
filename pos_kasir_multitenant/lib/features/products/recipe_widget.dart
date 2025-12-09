import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/material.dart' as mat;
import '../recipes/recipes_provider.dart';
import '../materials/materials_provider.dart';

/// Widget to display and edit recipe information for a product
class RecipeDialog extends ConsumerStatefulWidget {
  final Product product;

  const RecipeDialog({super.key, required this.product});

  @override
  ConsumerState<RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends ConsumerState<RecipeDialog> {
  late List<RecipeIngredient> _ingredients;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  void _loadRecipe() {
    final recipeNotifier = ref.read(recipeNotifierProvider.notifier);
    final recipe = recipeNotifier.getRecipe(widget.product.id);
    _ingredients =
        recipe != null ? recipe.map((i) => i.copyWith()).toList() : [];
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsProvider);
    final recipesAsync = ref.watch(recipeNotifierProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (materials) => recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (recipes) => _buildContent(materials, recipes),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<mat.Material> materials,
      Map<String, List<RecipeIngredient>> recipes) {
    final hasRecipe = _ingredients.isNotEmpty;
    final repository = ref.read(recipeRepositoryProvider);
    final maxServings = hasRecipe
        ? repository.calculateMaxServings(
            '', widget.product.id, materials, {widget.product.id: _ingredients})
        : 0;
    final materialStatus = hasRecipe
        ? repository.getMaterialStatus(_ingredients, materials)
        : <MaterialStatus>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasRecipe && !_isEditing) ...[
                  _buildNoRecipeMessage(),
                ] else ...[
                  if (!_isEditing) ...[
                    _buildCapacityCard(maxServings),
                    const SizedBox(height: 20),
                    const Text('📋 Bahan-bahan:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ...materialStatus
                        .map((status) => _buildIngredientItem(status)),
                    const SizedBox(height: 20),
                    if (maxServings == 0) _buildStockWarning(materialStatus),
                    if (maxServings > 0) _buildProductionInfo(maxServings),
                  ] else ...[
                    _buildEditMode(materials),
                  ],
                ],
              ],
            ),
          ),
        ),
        _buildFooter(hasRecipe),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.receipt_long, color: Colors.white, size: 24),
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
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool hasRecipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (!_isEditing) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(hasRecipe ? 'Edit Resep' : 'Buat Resep'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        _loadRecipe();
                        setState(() => _isEditing = false);
                      },
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveRecipe,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Simpan'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditMode(List<mat.Material> materials) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📝 Edit Bahan-bahan:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddIngredientDialog(materials),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ingredients.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Belum ada bahan. Klik "Tambah" untuk menambahkan.'),
            ),
          )
        else
          ..._ingredients.asMap().entries.map((entry) {
            final idx = entry.key;
            final ingredient = entry.value;
            return _buildEditableIngredient(ingredient, idx, materials);
          }),
      ],
    );
  }

  Widget _buildEditableIngredient(
      RecipeIngredient ingredient, int index, List<mat.Material> materials) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${ingredient.quantity} ${ingredient.unit}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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

  void _showAddIngredientDialog(List<mat.Material> materials) {
    final availableMaterials = materials
        .where((m) => !_ingredients.any((i) => i.materialId == m.id))
        .toList();

    if (availableMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua bahan sudah ditambahkan')),
      );
      return;
    }

    mat.Material? selectedMaterial;
    final qtyController = TextEditingController(text: '0.1');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Bahan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<mat.Material>(
                decoration: const InputDecoration(labelText: 'Pilih Bahan'),
                items: availableMaterials
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedMaterial = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: 'Jumlah per Porsi',
                  suffixText: selectedMaterial?.unit ?? '',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selectedMaterial == null
                  ? null
                  : () {
                      final qty = double.tryParse(qtyController.text) ?? 0;
                      if (qty > 0) {
                        setState(() {
                          _ingredients.add(RecipeIngredient(
                            materialId: selectedMaterial!.id,
                            quantity: qty,
                            unit: selectedMaterial!.unit,
                            name: selectedMaterial!.name,
                          ));
                        });
                        Navigator.pop(context);
                      }
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${ingredient.name}'),
        content: TextField(
          controller: qtyController,
          decoration: InputDecoration(
            labelText: 'Jumlah per Porsi',
            suffixText: ingredient.unit,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty > 0) {
                setState(() {
                  _ingredients[index] = ingredient.copyWith(quantity: qty);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecipe() async {
    // Validate ingredients before saving
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal satu bahan untuk resep'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate all ingredients have valid quantities
    for (final ingredient in _ingredients) {
      if (ingredient.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jumlah ${ingredient.name} harus lebih dari 0'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(recipeNotifierProvider.notifier).saveRecipe(
            widget.product.id,
            _ingredients,
          );
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resep ${widget.product.name} berhasil disimpan!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Parse error for user-friendly message
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        bool isNetworkError = errorMsg.contains('network') ||
            errorMsg.contains('Connection') ||
            errorMsg.contains('timeout');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNetworkError
                ? 'Gagal menyimpan: Tidak ada koneksi internet. Resep akan disimpan secara lokal.'
                : 'Gagal menyimpan: $errorMsg'),
            backgroundColor: isNetworkError ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNoRecipeMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 48),
          const SizedBox(height: 12),
          Text('Belum Ada Resep',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Produk ini belum memiliki resep. Klik "Buat Resep" untuk menambahkan bahan-bahan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade700),
          ),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(canProduce ? Icons.check_circle : Icons.warning,
                color: Colors.white, size: 32),
          ),
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

  Widget _buildIngredientItem(MaterialStatus status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.isAvailable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              status.isAvailable ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: status.isAvailable
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(status.isAvailable ? Icons.check : Icons.close,
                  color: status.isAvailable ? Colors.green : Colors.red,
                  size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.materialName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    'Butuh: ${_formatQuantity(status.neededPerServing, status.unit)} per porsi',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Stok: ${_formatQuantity(status.currentStock, status.unit)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: status.isAvailable ? Colors.green : Colors.red)),
              Text('≈ ${status.maxServings} porsi',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockWarning(List<MaterialStatus> materialStatus) {
    final outOfStock = materialStatus.where((s) => !s.isAvailable).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text('Bahan Habis!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Bahan berikut perlu diisi ulang:',
              style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 4),
          ...outOfStock.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('• ${s.materialName}',
                    style: TextStyle(color: Colors.red.shade700)),
              )),
        ],
      ),
    );
  }

  Widget _buildProductionInfo(int maxServings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text('Info Produksi',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dengan stok bahan baku saat ini, Anda dapat membuat maksimal $maxServings porsi ${widget.product.name}.',
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ],
      ),
    );
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

/// Widget to show recipe capacity summary in product list
class RecipeCapacityBadge extends ConsumerWidget {
  final String productId;

  const RecipeCapacityBadge({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeNotifierProvider);
    final materialsAsync = ref.watch(materialsProvider);

    return recipesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recipes) {
        if (!recipes.containsKey(productId)) return const SizedBox.shrink();

        return materialsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (materials) {
            final repository = ref.read(recipeRepositoryProvider);
            final maxServings = repository.calculateMaxServings(
                '', productId, materials, recipes);
            final canProduce = maxServings > 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: canProduce
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canProduce
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science,
                      size: 12, color: canProduce ? Colors.green : Colors.red),
                  const SizedBox(width: 4),
                  Text(canProduce ? '$maxServings' : '0',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: canProduce ? Colors.green : Colors.red)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
