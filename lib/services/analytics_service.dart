import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  AnalyticsService();

  static const _eventsTable = 'analytics_events';

  static const String bookingCreated = 'booking_created';
  static const String bookingCancelled = 'booking_cancelled';
  static const String reviewSubmitted = 'review_submitted';
  static const String userRegistered = 'user_registered';
  static const String workerRegistered = 'worker_registered';
  static const String chatMessageSent = 'chat_message_sent';
  static const String notificationTapped = 'notification_tapped';

  void trackScreenView(String screenName) {
    _logEvent('screen_view', {
      'screen_name': screenName,
      'timestamp': DateTime.now().toUtc().toIso8601String()
    });
  }

  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    _logEvent(eventName, parameters);
  }

  void _logEvent(String eventName, Map<String, dynamic>? parameters) {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      Supabase.instance.client.from(_eventsTable).insert({
        'event_name': eventName,
        'parameters': parameters,
        'user_id': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
