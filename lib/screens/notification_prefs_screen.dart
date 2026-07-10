import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  Map<String, bool> _prefs = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('notification_prefs')
        .eq('id', user.id)
        .single();
    final raw = data['notification_prefs'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _prefs = raw.map((k, v) => MapEntry(k, v as bool));
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    await Supabase.instance.client
        .from('profiles')
        .update({'notification_prefs': _prefs}).eq('id', user.id);
    setState(() => _isSaving = false);
  }

  static const _prefLabels = {
    'booking_alerts': 'Booking Alerts',
    'registration_alerts': 'Registration Alerts',
    'review_alerts': 'Review Alerts',
  };

  static const _prefIcons = {
    'booking_alerts': Icons.event,
    'registration_alerts': Icons.person_add,
    'review_alerts': Icons.star_rate,
  };

  static const _prefDescriptions = {
    'booking_alerts':
        'Get notified when someone books your service or when a booking status changes',
    'registration_alerts':
        'Receive alerts when new workers register on the platform',
    'review_alerts': 'Be notified when you receive a new review or rating',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: _prefLabels.keys.map((key) {
                      final enabled = _prefs[key] ?? true;
                      return Column(
                        children: [
                          if (key != _prefLabels.keys.first)
                            const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(
                              _prefIcons[key],
                              color: enabled
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                            title: Text(_prefLabels[key] ?? key),
                            subtitle: Text(
                              _prefDescriptions[key] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: enabled,
                            onChanged:
                                _isSaving ? null : (val) => _toggle(key, val),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
