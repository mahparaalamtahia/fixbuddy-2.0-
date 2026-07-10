import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/worker_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';
import '../../services/chat_service.dart';

final _bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

final workerHistoryTabProvider = StateProvider<String>((ref) => 'all');

class WorkerBookingHistoryScreen extends ConsumerWidget {
  final String? initialStatus;
  const WorkerBookingHistoryScreen({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorker = ref.watch(currentWorkerProvider);

    return currentWorker.when(
      data: (worker) => _HistoryList(
        workerId: worker?.id ?? '',
        initialStatus: initialStatus,
      ),
      loading: () => const Scaffold(
        body: ShimmerList(itemCount: 5, itemHeight: 140),
      ),
      error: (e, _) => Scaffold(
        body: EmptyState(
          title: 'Error loading profile',
          description: e.toString(),
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  final String workerId;
  final String? initialStatus;
  const _HistoryList({required this.workerId, this.initialStatus});

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null && _tabs.contains(widget.initialStatus)) {
      ref.read(workerHistoryTabProvider.notifier).state = widget.initialStatus!;
    }
  }

  static const _tabs = [
    'all',
    'pending',
    'confirmed',
    'in_progress',
    'completed',
  ];

  static const _tabLabels = [
    'All',
    'Pending',
    'Confirmed',
    'In Progress',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(workerBookingsStreamProvider(widget.workerId));
    final selectedTab = ref.watch(workerHistoryTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking History')),
      body: bookings.when(
        data: (list) {
          final filtered = selectedTab == 'all'
              ? list
              : list.where((b) => b.status == selectedTab).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final isSelected = selectedTab == _tabs[i];
                      final count = _tabs[i] == 'all'
                          ? list.length
                          : list.where((b) => b.status == _tabs[i]).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_tabLabels[i]),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black
                                              .withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) => _onTabSelected(_tabs[i]),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(selectedTab)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _BookingCard(
                            booking: filtered[i], workerId: widget.workerId),
                      ),
              ),
            ],
          );
        },
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 140),
        error: (e, _) => EmptyState(
          title: 'Error loading bookings',
          description: e.toString(),
          icon: Icons.error_outline,
        ),
      ),
    );
  }

  void _onTabSelected(String tab) {
    ref.read(workerHistoryTabProvider.notifier).state = tab;
    if (tab == 'all') {
      context.replace('/worker-shell/history');
    } else {
      context.replace('/worker-shell/history?status=$tab');
    }
  }

  Widget _buildEmptyState(String selectedTab) {
    if (selectedTab == 'all') {
      return const EmptyState(
        title: 'No bookings yet',
        description:
            'When customers book your services, they will appear here.',
        icon: Icons.history,
      );
    }
    return EmptyState(
      title: 'No ${_tabLabels[_tabs.indexOf(selectedTab)]} bookings',
      icon: Icons.inbox_outlined,
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final BookingModel booking;
  final String workerId;
  const _BookingCard({required this.booking, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled =
        booking.status == 'cancelled' || booking.status == 'declined';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/worker-shell/bookings/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: booking.workerAvatar != null
                        ? NetworkImage(booking.workerAvatar!)
                        : null,
                    child: booking.workerAvatar == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.workerName ?? 'Customer',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.categoryName ?? 'Service',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey[400]
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormatter.formatDate(booking.scheduledDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    booking.scheduledTime,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (booking.totalAmount != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.payments,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '৳${booking.totalAmount!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
              if (!isCancelled) ...[
                const SizedBox(height: 12),
                _buildActions(context, ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final isConfirmed = booking.status == 'confirmed';
    final isInProgress = booking.status == 'in_progress';
    final isPending = booking.status == 'pending';

    return Row(
      children: [
        if (isPending) ...[
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'confirmed'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'declined'),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (isConfirmed) ...[
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'in_progress'),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bookingInProgress,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ChatButton(booking: booking),
        ],
        if (isInProgress) ...[
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'completed'),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Mark Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bookingCompleted,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ChatButton(booking: booking),
        ],
      ],
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref
          .read(_bookingServiceProvider)
          .updateBookingStatus(booking.id, status);
      ref.invalidate(workerBookingsStreamProvider(workerId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Booking ${status == 'confirmed' ? 'accepted' : status == 'declined' ? 'declined' : status == 'in_progress' ? 'started' : 'completed'}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ChatButton extends ConsumerWidget {
  final BookingModel booking;
  const _ChatButton({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: () async {
          final chatId = await ChatService().getOrCreateChat(
            userId: booking.userId,
            workerId: booking.workerId,
            bookingId: booking.id,
          );
          if (context.mounted) {
            context.push('/worker-shell/chat/$chatId');
          }
        },
        icon: const Icon(Icons.chat, size: 18),
        label: const Text('Chat'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
