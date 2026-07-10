import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';

final _bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

class WorkerBookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const WorkerBookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: booking.when(
        data: (b) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          StatusBadge(status: b.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Row(
                          icon: Icons.category,
                          label: 'Category',
                          value: b.categoryName ?? 'N/A'),
                      _Row(
                          icon: Icons.location_on,
                          label: 'Area',
                          value: b.areaName ?? 'N/A'),
                      _Row(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          value: DateFormatter.formatDate(b.scheduledDate)),
                      _Row(
                          icon: Icons.access_time,
                          label: 'Time',
                          value:
                              DateFormatter.formatTimeString(b.scheduledTime)),
                      if (b.totalAmount != null)
                        _Row(
                            icon: Icons.attach_money,
                            label: 'Amount',
                            value: '৳${b.totalAmount!.toStringAsFixed(2)}'),
                      if (b.notes != null && b.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Notes',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(b.notes!,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ),
              if (b.status == 'confirmed') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(_bookingServiceProvider)
                          .updateBookingStatus(bookingId, 'in_progress');
                      analyticsService.trackEvent('booking_started',
                          parameters: {'booking_id': bookingId});
                      ref.invalidate(bookingByIdProvider(bookingId));
                    },
                    icon: const Icon(Icons.engineering),
                    label: const Text('Start Job'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bookingInProgress),
                  ),
                ),
              ],
              if (b.status == 'in_progress') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(_bookingServiceProvider)
                          .updateBookingStatus(bookingId, 'completed');
                      analyticsService.trackEvent('booking_completed',
                          parameters: {'booking_id': bookingId});
                      ref.invalidate(bookingByIdProvider(bookingId));
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                ),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
