import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final data = await _supabase
        .from('notifications')
        .select('*')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  Future<int> getUnreadCount(String userId) async {
    final data = await _supabase
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => NotificationModel.fromJson(e)).toList());
  }

  Future<void> broadcastNotification({
    required String title,
    required String body,
    required String target,
    String? targetId,
    required String sentBy,
  }) async {
    // Broadcast notifications via Supabase
    // This stores notifications in the database for users to pull
    List<String> recipientIds = [];
    if (target == 'all_users') {
      final res = await _supabase.from('profiles').select('id').eq('role', 'user');
      recipientIds = (res as List).map((e) => e['id'] as String).toList();
    } else if (target == 'all_workers') {
      final res = await _supabase.from('profiles').select('id').eq('role', 'worker');
      recipientIds = (res as List).map((e) => e['id'] as String).toList();
    } else if (target == 'by_area' && targetId != null) {
      final res = await _supabase.from('profiles').select('id').eq('area_id', targetId);
      recipientIds = (res as List).map((e) => e['id'] as String).toList();
    } else if (targetId != null) {
      recipientIds = [targetId];
    }

    if (recipientIds.isNotEmpty) {
      final notifications = recipientIds.map((id) => {
        'recipient_id': id,
        'title': title,
        'body': body,
        'type': 'admin_broadcast',
        'is_read': false,
      }).toList();
      await _supabase.from('notifications').insert(notifications);
    }
  }
}
