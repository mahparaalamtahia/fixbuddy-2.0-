import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/worker_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';

final _bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorker = ref.watch(currentWorkerProvider);

    return currentWorker.when(
      data: (worker) => _RequestsList(workerId: worker?.id ?? ''),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final String workerId;
  const _RequestsList({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(workerBookingsProvider(workerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Requests')),
      body: bookings.when(
        data: (list) {
          final pending = list.where((b) => b.status == 'pending').toList();
          return pending.isEmpty
              ? const EmptyState(
                  title: 'No pending requests', icon: Icons.inbox_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pending.length,
                  itemBuilder: (_, i) => _RequestCard(booking: pending[i]),
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final BookingModel booking;
  const _RequestCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(booking.workerName ?? 'Customer',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            if (booking.categoryName != null)
              _InfoLabel(icon: Icons.category, text: booking.categoryName!),
            _InfoLabel(
                icon: Icons.calendar_today,
                text: DateFormatter.formatDate(booking.scheduledDate)),
            _InfoLabel(
                icon: Icons.access_time,
                text: DateFormatter.formatTimeString(booking.scheduledTime)),
            if (booking.notes != null && booking.notes!.isNotEmpty)
              _InfoLabel(icon: Icons.notes, text: booking.notes!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(_bookingServiceProvider)
                          .updateBookingStatus(booking.id, 'confirmed');
                      analyticsService.trackEvent('booking_accepted',
                          parameters: {
                            'booking_id': booking.id,
                            'worker_id': booking.workerId
                          });
                      ref.invalidate(workerBookingsProvider(booking.workerId));
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDeclineDialog(context, ref, booking),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclineDialog(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for declining:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Too busy, unavailable on that date...',
                border: OutlineInputBorder(),
              ),
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
              final reason = reasonController.text.trim();
              await ref.read(_bookingServiceProvider).updateBookingStatus(
                  booking.id, 'declined',
                  declineReason: reason.isNotEmpty ? reason : null);
              analyticsService.trackEvent('booking_declined', parameters: {
                'booking_id': booking.id,
                'worker_id': booking.workerId
              });
              ref.invalidate(workerBookingsProvider(booking.workerId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
