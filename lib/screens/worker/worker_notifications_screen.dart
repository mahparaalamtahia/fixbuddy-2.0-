import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';

final _notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

class WorkerNotificationsScreen extends ConsumerWidget {
  const WorkerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userId = authService.currentUser?.id;
    final notifications =
        ref.watch(workerNotificationStreamProvider(userId ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Preferences',
            onPressed: () => context.push('/worker-shell/notifications/prefs'),
          ),
          TextButton(
            onPressed: () {
              if (userId != null) {
                ref.read(_notificationServiceProvider).markAllAsRead(userId);
              }
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: notifications.when(
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'No notifications',
                icon: Icons.notifications_off_outlined)
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: list[i].isRead
                        ? AppColors.divider
                        : AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.notifications,
                        color: list[i].isRead
                            ? AppColors.textSecondary
                            : AppColors.primary),
                  ),
                  title: Text(list[i].title,
                      style: TextStyle(
                          fontWeight: list[i].isRead
                              ? FontWeight.normal
                              : FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list[i].body,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (list[i].createdAt != null)
                        Text(DateFormatter.relativeTime(list[i].createdAt!),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

final workerNotificationStreamProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  final service = ref.watch(_notificationServiceProvider);
  return service.streamNotifications(userId);
});
