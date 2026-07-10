import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

final _supabase = Supabase.instance.client;

final adminUserSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(adminUserSearchQueryProvider);

  var request = _supabase.from('admin_user_directory_view').select();
  
  if (query.isNotEmpty) {
    request = request.ilike('search_text', '%$query%');
  }

  final data = await request;
  return List<Map<String, dynamic>>.from(data);
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(filteredUsersProvider);
    final searchQuery = ref.watch(adminUserSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User Directory Dashboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users by name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ref.read(adminUserSearchQueryProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (value) => ref.read(adminUserSearchQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: users.when(
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('No users found.'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final user = list[i];
                    final String name = user['full_name'] ?? 'Unknown';
                    final String email = user['email'] ?? '';
                    final String avatarUrl = user['avatar_url'] ?? '';
                    final bool isActive = user['is_active'] == true;
                    final activeReqs = (user['active_requests_count'] as num?)?.toInt() ?? 0;
                    final pendingReqs = (user['pending_requests_count'] as num?)?.toInt() ?? 0;
                    final completedReqs = (user['completed_requests_count'] as num?)?.toInt() ?? 0;
                    final totalSpent = (user['total_spent'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: InkWell(
                        onTap: () => _showUserProfile(context, user),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                    child: avatarUrl.isEmpty ? Text(name.isNotEmpty ? name[0] : 'U') : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(email, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                                      ],
                                    ),
                                  ),
                                  if (!isActive)
                                    Chip(
                                      label: const Text('Inactive', style: TextStyle(fontSize: 10)),
                                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMetricBadge('Active: $activeReqs', Colors.blue),
                                  _buildMetricBadge('Pending: $pendingReqs', Colors.amber),
                                  _buildMetricBadge('Done: $completedReqs', Colors.green),
                                  _buildMetricBadge('Spent: ৳${totalSpent.toStringAsFixed(0)}', Colors.purple),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserProfileSheet(user: user),
    );
  }
}

class _UserProfileSheet extends StatefulWidget {
  final Map<String, dynamic> user;

  const _UserProfileSheet({required this.user});

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  bool _isLoading = true;
  int _totalBookings = 0;
  double _totalSpent = 0.0;
  List<Map<String, dynamic>> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _supabase.from('bookings').select('*, workers(profiles(full_name))').eq('user_id', widget.user['profile_id']).order('created_at', ascending: false);

      final bookings = res as List<dynamic>;
      int count = bookings.length;
      double spent = 0.0;
      for (var b in bookings) {
        if (b['status'] == 'completed' && b['total_amount'] != null) {
          spent += (b['total_amount'] as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _totalBookings = count;
          _totalSpent = spent;
          _recentBookings = bookings.take(3).cast<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('User Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user['avatar_url'] != null && (user['avatar_url'] as String).isNotEmpty ? CachedNetworkImageProvider(user['avatar_url']) : null,
                    child: user['avatar_url'] == null || (user['avatar_url'] as String).isEmpty ? Text((user['full_name'] as String).isNotEmpty ? (user['full_name'] as String)[0] : 'U', style: const TextStyle(fontSize: 32)) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(user['full_name'] ?? '', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(user['email'] ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  if (user['phone'] != null && (user['phone'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user['phone'], style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 24),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(title: 'Requested Bookings', value: _totalBookings.toString()),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(title: 'Total Spent', value: '৳${_totalSpent.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Recent Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    if (_recentBookings.isEmpty)
                      const Text('No bookings found.', style: TextStyle(color: Colors.grey))
                    else
                      ..._recentBookings.map((b) {
                        final workerName = b['workers']['profiles']['full_name'] ?? 'Unknown Worker';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(workerName),
                            subtitle: Text('Status: ${b['status']}'),
                          ),
                        );
                      }),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
