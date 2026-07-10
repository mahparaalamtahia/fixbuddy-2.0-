import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/router/app_router.dart';
import '../../providers/booking_provider.dart';
import '../../services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/review_submission_modal.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  int _statusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'in_progress':
        return 2;
      case 'completed':
        return 3;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // bookingByIdProvider refreshes on invalidation for realtime-like updates
    final booking = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: booking.when(
        data: (b) {
          final step = _statusStep(b.status);
          final showChat = b.status == 'pending' ||
              b.status == 'confirmed' ||
              b.status == 'in_progress';
          final showCancel = b.status == 'pending' || b.status == 'confirmed';
          final showRate = b.status == 'completed' && !b.isReviewed;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusTimeline(currentStep: step),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              context.push('/shell/workers/${b.workerId}'),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundImage: b.workerAvatar != null
                                    ? CachedNetworkImageProvider(
                                        b.workerAvatar!)
                                    : null,
                                child: b.workerAvatar == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.workerName ?? 'Worker',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    if (b.workerPhone != null)
                                      Text(b.workerPhone!,
                                          style: const TextStyle(
                                              color: AppColors.primary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Status',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            StatusBadge(status: b.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                            icon: Icons.category,
                            label: 'Category',
                            value: b.categoryName ?? 'N/A'),
                        _DetailRow(
                            icon: Icons.location_on,
                            label: 'Area',
                            value: b.areaName ?? 'N/A'),
                        _DetailRow(
                            icon: Icons.calendar_today,
                            label: 'Date',
                            value: DateFormatter.formatDate(b.scheduledDate)),
                        _DetailRow(
                            icon: Icons.access_time,
                            label: 'Time',
                            value: DateFormatter.formatTimeString(
                                b.scheduledTime)),
                        if (b.totalAmount != null)
                          _DetailRow(
                              icon: Icons.attach_money,
                              label: 'Amount',
                              value:
                                  '\u09F3${b.totalAmount!.toStringAsFixed(2)}'),
                        if (b.notes != null && b.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Notes',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(b.notes!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                        if (b.status == 'declined' &&
                            b.declineReason != null &&
                            b.declineReason!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Decline Reason',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(b.declineReason!,
                                style: const TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Method',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                _paymentStatusText(b),
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: b.status == 'completed'
                                        ? AppColors.success
                                        : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showChat) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final currentUser = Supabase.instance.client.auth.currentUser;
                        if (currentUser != null) {
                          final chatId = await ChatService().getOrCreateChat(
                            userId: b.userId,
                            workerId: b.workerId,
                            bookingId: b.id,
                          );
                          if (context.mounted) {
                            context.push('/shell/chat/$chatId');
                          }
                        }
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat with Worker'),
                    ),
                  ),
                ],
                if (showRate) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(ctx).viewInsets.bottom,
                            ),
                            child: ReviewSubmissionModal(
                              bookingId: b.id,
                              userId: b.userId,
                              workerId: b.workerId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rate),
                      label: const Text('Rate This Service'),
                    ),
                  ),
                ],
                if (showCancel) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelBooking(context, ref),
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.error),
                      label: const Text('Cancel Booking',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _paymentStatusText(dynamic b) {
    final method = b.paymentMethod ?? 'cash';
    final methodLabel = switch (method) {
      'bkash' => 'bKash',
      'nagad' => 'Nagad',
      'rocket' => 'Rocket',
      _ => 'Cash',
    };
    return b.status == 'completed'
        ? 'Paid via $methodLabel'
        : '$methodLabel on Service';
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(bookingServiceProvider).cancelBooking(bookingId);
        analyticsService.trackEvent(AnalyticsService.bookingCancelled,
            parameters: {'booking_id': bookingId});
        ref.invalidate(bookingByIdProvider(bookingId));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Booking cancelled')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }
}

class _StatusTimeline extends StatelessWidget {
  final int currentStep;
  const _StatusTimeline({required this.currentStep});

  static const _steps = ['Requested', 'Confirmed', 'In Progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIdx = i ~/ 2;
              final active = stepIdx < currentStep;
              return Expanded(
                child: Container(
                  height: 2,
                  color: active ? AppColors.primary : AppColors.divider,
                ),
              );
            }
            final stepIdx = i ~/ 2;
            final active = stepIdx <= currentStep;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.primary : AppColors.divider,
                  ),
                  child: active && stepIdx < currentStep
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  _steps[stepIdx],
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? AppColors.primary : AppColors.textHint,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label:',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
