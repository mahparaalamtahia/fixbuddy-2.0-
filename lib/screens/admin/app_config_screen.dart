import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/config_provider.dart';
import '../../services/config_service.dart';
import '../../models/app_config_model.dart';

final _configServiceProvider =
    Provider<ConfigService>((ref) => ConfigService());

class AppConfigScreen extends ConsumerWidget {
  const AppConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(allConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App Configuration')),
      body: configs.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final config = list[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  config.boolValue
                      ? Icons.toggle_on
                      : Icons.toggle_off_outlined,
                  color:
                      config.boolValue ? AppColors.success : AppColors.textHint,
                ),
                title: Text(config.key),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Value: ${config.value}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (config.description != null)
                      Text(config.description!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () => _editConfig(context, ref, config),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _editConfig(BuildContext context, WidgetRef ref, AppConfigModel config) {
    final controller = TextEditingController(text: config.value);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${config.key}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(config.description ?? '',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(_configServiceProvider)
                  .setConfig(config.key, controller.text.trim());
              ref.invalidate(allConfigProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
