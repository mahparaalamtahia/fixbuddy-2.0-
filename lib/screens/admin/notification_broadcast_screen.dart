import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/area_provider.dart';

final _notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

class NotificationBroadcastScreen extends ConsumerStatefulWidget {
  const NotificationBroadcastScreen({super.key});

  @override
  ConsumerState<NotificationBroadcastScreen> createState() =>
      _NotificationBroadcastScreenState();
}

class _NotificationBroadcastScreenState
    extends ConsumerState<NotificationBroadcastScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _target = 'all_users';
  String? _selectedAreaId;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(activeAreasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Target Audience',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _target,
              onChanged: (v) => setState(() {
                _target = v!;
                if (_target != 'by_area') _selectedAreaId = null;
              }),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('All Users'),
                    value: 'all_users',
                  ),
                  RadioListTile<String>(
                    title: Text('All Workers'),
                    value: 'all_workers',
                  ),
                  RadioListTile<String>(
                    title: Text('By Area'),
                    value: 'by_area',
                  ),
                ],
              ),
            ),
            if (_target == 'by_area')
              areas.when(
                data: (areaList) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Area'),
                    initialValue: _selectedAreaId,
                    items: areaList
                        .map((a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAreaId = v),
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading areas'),
              ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Send Broadcast',
              isLoading: _isSending,
              onPressed: _sendBroadcast,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Title and body are required'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      final targetId = _target == 'by_area' ? _selectedAreaId : null;
      if (_target == 'by_area' && targetId == null) {
        throw Exception('Please select an area');
      }
      await ref.read(_notificationServiceProvider).broadcastNotification(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            target: _target,
            targetId: targetId,
            sentBy: user.id,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Broadcast sent!'),
            backgroundColor: AppColors.success),
      );
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
