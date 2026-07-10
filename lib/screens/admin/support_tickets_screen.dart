import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';

final _supabase = Supabase.instance.client;

final supportTicketsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sub = _supabase.channel('admin_all_tickets').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'support_tickets',
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    sub.unsubscribe();
  });

  final data = await _supabase
      .from('support_tickets')
      .select('*, profiles(full_name, email)')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

const _statusColors = {
  'open': AppColors.warning,
  'in_progress': AppColors.info,
  'resolved': AppColors.success,
  'closed': AppColors.textHint,
};

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: tickets.when(
        data: (list) {
          final display = _filter == 'all'
              ? list
              : list.where((t) => t['status'] == _filter).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilter('all', 'All', list.length),
                      const SizedBox(width: 8),
                      _buildFilter('open', 'Open',
                          list.where((t) => t['status'] == 'open').length),
                      const SizedBox(width: 8),
                      _buildFilter(
                          'in_progress',
                          'In Progress',
                          list
                              .where((t) => t['status'] == 'in_progress')
                              .length),
                      const SizedBox(width: 8),
                      _buildFilter('resolved', 'Resolved',
                          list.where((t) => t['status'] == 'resolved').length),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: display.isEmpty
                    ? const Center(child: Text('No tickets found'))
                    : ListView.builder(
                        itemCount: display.length,
                        itemBuilder: (_, i) => _buildTicketCard(display[i]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildFilter(String status, String label, int count) {
    final selected = _filter == status;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final profile = ticket['profiles'] as Map<String, dynamic>?;
    final userName = profile?['full_name'] ?? 'Unknown';
    final userEmail = profile?['email'] ?? '';
    final status = ticket['status'] as String;
    final statusColor = _statusColors[status] ?? AppColors.textHint;
    final createdAt = ticket['created_at'] != null
        ? DateTime.parse(ticket['created_at'] as String)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            status == 'resolved' || status == 'closed'
                ? Icons.check_circle
                : Icons.help_outline,
            color: statusColor,
          ),
        ),
        title: Text(ticket['subject'] as String? ?? 'No subject',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$userName  \u2022  ${createdAt != null ? DateFormatter.relativeTime(createdAt) : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket['message'] as String? ?? '',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(userEmail,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statusBadge(status),
                    const Spacer(),
                    if (status == 'open')
                      _actionButton('Accept', AppColors.info, 'in_progress',
                          ticket['id']),
                    if (status == 'in_progress')
                      _actionButton('Resolve', AppColors.success, 'resolved',
                          ticket['id']),
                    if (status == 'resolved')
                      _actionButton(
                          'Close', AppColors.textHint, 'closed', ticket['id']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColors[status] ?? AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _actionButton(
      String label, Color color, String newStatus, String ticketId) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () async {
          await _supabase
              .from('support_tickets')
              .update({'status': newStatus}).eq('id', ticketId);
          ref.invalidate(supportTicketsProvider);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
