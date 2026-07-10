import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final unreadCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final service = ref.watch(notificationServiceProvider);
  return service.streamNotifications(userId).map(
        (notifications) => notifications.where((n) => !n.isRead).length,
      );
});
