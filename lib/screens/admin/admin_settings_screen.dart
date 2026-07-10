import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: AppColors.primary),
                  title: const Text('Admin Profile'),
                  subtitle: const Text('View and edit admin details'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/shell/profile/edit'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.notifications, color: AppColors.primary),
                  title: const Text('Notification Preferences'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotificationPrefs(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: AppColors.primary),
                  title: const Text('Security Settings'),
                  subtitle: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSecurityDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette, color: AppColors.primary),
                  title: const Text('Theme'),
                  subtitle: Text(_themeModeLabel(ref)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('About FixBuddy'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.support_agent, color: AppColors.primary),
                  title: const Text('Manage Support Tickets'),
                  subtitle: const Text('View and resolve user tickets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin-shell/tickets'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.help_outline, color: AppColors.primary),
                  title: const Text('Submit Issue'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSupportDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text(
                        'Are you sure you want to logout from admin panel?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Logout',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(WidgetRef ref) {
    switch (ref.watch(themeModeProvider)) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showNotificationPrefs(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _NotificationPrefsDialog(),
    );
  }

  void _showSecurityDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;
    final emailController = TextEditingController(text: user?.email ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                await ref.read(authServiceProvider).resetPassword(email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Password reset link sent to your email.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(value);
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              final label = mode == ThemeMode.light
                  ? 'Light'
                  : mode == ThemeMode.dark
                      ? 'Dark'
                      : 'System';
              final icon = mode == ThemeMode.light
                  ? Icons.light_mode
                  : mode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.settings_brightness;
              return RadioListTile<ThemeMode>(
                title: Row(
                  children: [
                    Icon(icon, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(label),
                  ],
                ),
                value: mode,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About FixBuddy'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle, color: AppColors.primary, size: 48),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FixBuddy',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Your Friendly Local Service Helper'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            _InfoRow(label: 'Version', value: '1.0.0'),
            _InfoRow(label: 'Build', value: '1'),
            _InfoRow(label: 'Platform', value: 'Mobile'),
            SizedBox(height: 12),
            Text(
              'FixBuddy connects you with trusted local service professionals for all your home maintenance and repair needs.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context, WidgetRef ref) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Describe your issue or question below. We\'ll get back to you.'),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.subject),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.message),
                  ),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final subject = subjectController.text.trim();
              final message = messageController.text.trim();
              if (subject.isEmpty || message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields.')),
                );
                return;
              }
              try {
                final userId = ref.read(authServiceProvider).currentUser?.id;
                await Supabase.instance.client.from('support_tickets').insert({
                  'user_id': userId,
                  'subject': subject,
                  'message': message,
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Support ticket submitted successfully.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _NotificationPrefsDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotificationPrefsDialog> createState() =>
      _NotificationPrefsDialogState();
}

class _NotificationPrefsDialogState
    extends ConsumerState<_NotificationPrefsDialog> {
  bool _loading = true;
  bool _bookingAlerts = true;
  bool _registrationAlerts = true;
  bool _reviewAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('notification_prefs')
          .eq('id', userId)
          .single();
      final prefs = data['notification_prefs'] as Map? ?? {};
      setState(() {
        _bookingAlerts = (prefs['booking_alerts'] as bool?) ?? true;
        _registrationAlerts = (prefs['registration_alerts'] as bool?) ?? true;
        _reviewAlerts = (prefs['review_alerts'] as bool?) ?? true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePrefs() async {
    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('profiles').update({
        'notification_prefs': {
          'booking_alerts': _bookingAlerts,
          'registration_alerts': _registrationAlerts,
          'review_alerts': _reviewAlerts,
        }
      }).eq('id', userId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notification Preferences'),
      content: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Booking Alerts'),
                    subtitle: const Text('Receive new booking notifications'),
                    value: _bookingAlerts,
                    onChanged: (v) {
                      setState(() => _bookingAlerts = v);
                      _savePrefs();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Registration Alerts'),
                    subtitle:
                        const Text('Receive new user registration alerts'),
                    value: _registrationAlerts,
                    onChanged: (v) {
                      setState(() => _registrationAlerts = v);
                      _savePrefs();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Review Alerts'),
                    subtitle: const Text('Receive new review alerts'),
                    value: _reviewAlerts,
                    onChanged: (v) {
                      setState(() => _reviewAlerts = v);
                      _savePrefs();
                    },
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
