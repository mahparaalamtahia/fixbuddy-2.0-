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

class UserNotificationsScreen extends ConsumerWidget {
  const UserNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userId = authService.currentUser?.id;
    final notifications = ref.watch(notificationStreamProvider(userId ?? ''));
    final unreadCount = ref.watch(_unreadCountProvider(userId ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            unreadCount.when(
              data: (count) => count > 0
                  ? Text('$count unread',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary))
                  : const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Preferences',
            onPressed: () => context.push('/shell/notifications/prefs'),
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
                itemBuilder: (_, i) => _NotificationTile(notification: list[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

final notificationStreamProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
  final service = ref.watch(_notificationServiceProvider);
  return service.streamNotifications(userId);
});

final _unreadCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.watch(_notificationServiceProvider);
  return service.getUnreadCount(userId);
});

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.type) {
      case 'booking_new':
        return Icons.book_online;
      case 'booking_confirmed':
        return Icons.check_circle;
      case 'booking_completed':
        return Icons.verified;
      case 'booking_cancelled':
        return Icons.cancel;
      case 'booking_declined':
        return Icons.block;
      case 'chat_message':
        return Icons.chat;
      case 'admin_broadcast':
        return Icons.campaign;
      case 'review_received':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  String? _routePath() {
    switch (notification.type) {
      case 'booking_new':
      case 'booking_confirmed':
      case 'booking_completed':
      case 'booking_cancelled':
      case 'booking_declined':
      case 'review_received':
        return '/shell/bookings/${notification.referenceId}';
      case 'chat_message':
        return '/shell/chat/${notification.referenceId}';
      case 'admin_broadcast':
        return null;
      default:
        return null;
    }
  }

  void _onTap(BuildContext context, WidgetRef ref) {
    if (!notification.isRead) {
      ref.read(_notificationServiceProvider).markAsRead(notification.id);
    }
    final route = _routePath();
    if (route != null && notification.referenceId != null) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => _onTap(context, ref),
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? AppColors.divider
            : AppColors.primary.withValues(alpha: 0.1),
        child: Icon(_icon,
            color: notification.isRead
                ? AppColors.textSecondary
                : AppColors.primary,
            size: 20),
      ),
      title: Text(notification.title,
          style: TextStyle(
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (notification.createdAt != null)
            Text(DateFormatter.relativeTime(notification.createdAt!),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
    );
  }
}
