import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';

final _categoryServiceProvider =
    Provider<CategoryService>((ref) => CategoryService());

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCategoryDialog(context, ref, null),
          ),
        ],
      ),
      body: categories.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final cat = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: cat.color.withValues(alpha: 0.2),
                child: Icon(cat.icon, color: cat.color),
              ),
              title: Text(cat.name),
              subtitle: Text(
                  'Sort: ${cat.sortOrder} | ${cat.isActive ? 'Active' : 'Inactive'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showCategoryDialog(context, ref, cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        size: 20, color: AppColors.error),
                    onPressed: () async {
                      await ref
                          .read(_categoryServiceProvider)
                          .deleteCategory(cat.id);
                      ref.invalidate(allCategoriesProvider);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCategoryDialog(
      BuildContext context, WidgetRef ref, CategoryModel? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final iconController =
        TextEditingController(text: existing?.iconName ?? '');
    final colorController =
        TextEditingController(text: existing?.colorHex ?? '#');
    final descController =
        TextEditingController(text: existing?.description ?? '');
    final sortController =
        TextEditingController(text: existing?.sortOrder.toString() ?? '0');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: iconController,
                    decoration: const InputDecoration(
                        labelText: 'Icon Name (flutter constant)')),
                TextField(
                    controller: colorController,
                    decoration: const InputDecoration(
                        labelText: 'Color Hex (e.g. #1565C0)')),
                TextField(
                    controller: descController,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                TextField(
                    controller: sortController,
                    decoration: const InputDecoration(labelText: 'Sort Order'),
                    keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'icon_name': iconController.text.trim(),
                  'color_hex': colorController.text.trim(),
                  'description': descController.text.trim(),
                  'sort_order': int.tryParse(sortController.text.trim()) ?? 0,
                  'is_active': isActive,
                };
                try {
                  if (existing == null) {
                    await ref.read(_categoryServiceProvider).createCategory(data);
                  } else {
                    await ref
                        .read(_categoryServiceProvider)
                        .updateCategory(existing.id, data);
                  }
                  ref.invalidate(allCategoriesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to save category. Please ensure the name is unique.')),
                    );
                  }
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
