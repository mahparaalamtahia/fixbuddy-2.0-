import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/area_provider.dart';
import '../../services/area_service.dart';
import '../../models/area_model.dart';

final _areaServiceProvider = Provider<AreaService>((ref) => AreaService());

class AreaManagementScreen extends ConsumerWidget {
  const AreaManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(allAreasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Areas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAreaDialog(context, ref, null),
          ),
        ],
      ),
      body: areas.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final area = list[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.location_on, color: AppColors.primary),
              ),
              title: Text(area.name),
              subtitle: Text(
                  '${area.city} | Sort: ${area.sortOrder} | ${area.isActive ? 'Active' : 'Inactive'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showAreaDialog(context, ref, area),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        size: 20, color: AppColors.error),
                    onPressed: () async {
                      await ref.read(_areaServiceProvider).deleteArea(area.id);
                      ref.invalidate(allAreasProvider);
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

  void _showAreaDialog(
      BuildContext context, WidgetRef ref, AreaModel? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final cityController =
        TextEditingController(text: existing?.city ?? 'Dhaka');
    final sortController =
        TextEditingController(text: existing?.sortOrder.toString() ?? '0');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Area' : 'Edit Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City')),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameController.text.trim(),
                  'city': cityController.text.trim(),
                  'sort_order': int.tryParse(sortController.text.trim()) ?? 0,
                  'is_active': isActive,
                };
                try {
                  if (existing == null) {
                    await ref.read(_areaServiceProvider).createArea(data);
                  } else {
                    await ref
                        .read(_areaServiceProvider)
                        .updateArea(existing.id, data);
                  }
                  ref.invalidate(allAreasProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to save area. Please ensure the name is unique.')),
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
