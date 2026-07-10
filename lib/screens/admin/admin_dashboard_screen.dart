import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

final _supabase = Supabase.instance.client;

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await _supabase.rpc('get_admin_stats');
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Widget _buildGrid(Map<String, dynamic>? data, {bool isLoading = false, bool isError = false}) {
    final defaultVal = isLoading ? '...' : (isError ? '!' : '0');
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatTile(
            title: 'Total Users',
            value: data != null ? '${data['total_users'] ?? 0}' : defaultVal,
            icon: Icons.people,
            color: AppColors.primary),
        _StatTile(
            title: 'Total Workers',
            value: data != null ? '${data['total_workers'] ?? 0}' : defaultVal,
            icon: Icons.construction,
            color: AppColors.secondary),
        _StatTile(
            title: 'Total Bookings',
            value: data != null ? '${data['total_bookings'] ?? 0}' : defaultVal,
            icon: Icons.book,
            color: AppColors.success),
        _StatTile(
            title: "Today's Bookings",
            value: data != null ? '${data['bookings_today'] ?? 0}' : defaultVal,
            icon: Icons.today,
            color: AppColors.info),
        _StatTile(
            title: 'Pending Approvals',
            value: data != null ? '${data['pending_approvals'] ?? 0}' : defaultVal,
            icon: Icons.pending,
            color: AppColors.warning),
        _StatTile(
            title: 'Completed',
            value: data != null ? '${data['completed_bookings'] ?? 0}' : defaultVal,
            icon: Icons.verified,
            color: AppColors.success),
        _StatTile(
            title: 'Active Categories',
            value: data != null ? '${data['active_categories'] ?? 0}' : defaultVal,
            icon: Icons.category,
            color: AppColors.primaryLight),
        _StatTile(
            title: 'Active Areas',
            value: data != null ? '${data['active_areas'] ?? 0}' : defaultVal,
            icon: Icons.location_on,
            color: Colors.teal),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _AdminDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          stats.when(
            data: (data) => _buildGrid(data),
            loading: () => _buildGrid(null, isLoading: true),
            error: (e, _) => Column(
              children: [
                _buildGrid(null, isError: true),
                const SizedBox(height: 16),
                Text('Error loading stats: $e', style: const TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text('Admin Panel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('FixBuddy Management',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          _DrawerItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
              }),
          _DrawerItem(
              icon: Icons.people,
              label: 'User Management',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/users');
              }),
          _DrawerItem(
              icon: Icons.construction,
              label: 'Worker Management',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/workers');
              }),
          _DrawerItem(
              icon: Icons.book,
              label: 'Booking Management',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/bookings');
              }),
          _DrawerItem(
              icon: Icons.category,
              label: 'Categories',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/categories');
              }),
          _DrawerItem(
              icon: Icons.location_on,
              label: 'Areas',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/areas');
              }),
          _DrawerItem(
              icon: Icons.rate_review,
              label: 'Review Moderation',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/reviews');
              }),
          _DrawerItem(
              icon: Icons.campaign,
              label: 'Broadcast',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/broadcast');
              }),
          _DrawerItem(
              icon: Icons.settings,
              label: 'App Config',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/config');
              }),
          _DrawerItem(
              icon: Icons.tune,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/settings');
              }),
          _DrawerItem(
              icon: Icons.bar_chart,
              label: 'Reports',
              onTap: () {
                Navigator.pop(context);
                context.go('/admin-shell/reports');
              }),
          const Divider(),
          _DrawerItem(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              }),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
