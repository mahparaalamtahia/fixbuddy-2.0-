import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/booking_model.dart';

final _supabase = Supabase.instance.client;

final allBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final sub = _supabase.channel('admin_all_bookings').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'bookings',
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    sub.unsubscribe();
  });

  final data = await _supabase.from('bookings').select('''
        *,
        workers!inner(profiles(full_name, avatar_url, phone)),
        categories(name, icon_name),
        areas(name)
      ''').order('created_at', ascending: false);
  return (data as List).map((e) => BookingModel.fromJson(e)).toList();
});

class BookingManagementScreen extends ConsumerStatefulWidget {
  const BookingManagementScreen({super.key});

  @override
  ConsumerState<BookingManagementScreen> createState() =>
      _BookingManagementScreenState();
}

class _BookingManagementScreenState
    extends ConsumerState<BookingManagementScreen> {
  String _selectedStatus = 'All';

  static const _statuses = [
    'All',
    'pending',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled',
    'declined'
  ];

  static String _statusLabel(String s) {
    if (s == 'All') return 'All';
    return s
        .split('_')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(allBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Management')),
      body: bookings.when(
        data: (list) {
          final filtered = _selectedStatus == 'All'
              ? list
              : list.where((b) => b.status == _selectedStatus).toList();

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: _statuses.map((s) {
                    final selected = _selectedStatus == s;
                    final count = s == 'All'
                        ? list.length
                        : list.where((b) => b.status == s).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('${_statusLabel(s)} ($count)'),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedStatus = s),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final b = filtered[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.workerName ?? 'Worker',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(b.categoryName ?? 'N/A',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 12, color: AppColors.textHint),
                                      const SizedBox(width: 4),
                                      Text(
                                          DateFormatter.formatDate(
                                              b.scheduledDate),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.access_time,
                                          size: 12, color: AppColors.textHint),
                                      const SizedBox(width: 4),
                                      Text(
                                          DateFormatter.formatTimeString(
                                              b.scheduledTime),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  if (b.totalAmount != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                        '${b.totalAmount!.toStringAsFixed(0)} BDT',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success)),
                                  ],
                                ],
                              ),
                            ),
                            StatusBadge(status: b.status),
                          ],
                        ),
                      ),
                    );
                  },
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
}
