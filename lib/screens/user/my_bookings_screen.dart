import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/app_error_widget.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';
import '../../services/chat_service.dart';

final _bookingSvcProvider = Provider<BookingService>((ref) => BookingService());

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(userBookingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: bookings.when(
        data: (list) {
          final ongoing = list
              .where((b) =>
                  b.status == 'pending' ||
                  b.status == 'confirmed' ||
                  b.status == 'in_progress')
              .toList();
          final completed = list.where((b) => b.status == 'completed').toList();

          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabContent(ongoing, isOngoing: true),
                    _buildTabContent(completed, isOngoing: false),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/shell/workers'),
                  icon: const Icon(Icons.construction),
                  label: const Text('Browse Workers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e),
      ),
    );
  }

  Widget _buildTabContent(List<BookingModel> items, {required bool isOngoing}) {
    if (items.isEmpty) {
      return EmptyState(
        title: isOngoing ? 'No ongoing bookings' : 'No completed bookings',
        description: isOngoing
            ? 'Browse workers and book a service'
            : 'Completed bookings will appear here',
        icon: isOngoing ? Icons.pending_actions : Icons.history,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: items[i],
        isOngoing: isOngoing,
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final BookingModel booking;
  final bool isOngoing;
  const _BookingCard({required this.booking, required this.isOngoing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/shell/bookings/${booking.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: booking.workerAvatar != null
                        ? CachedNetworkImageProvider(booking.workerAvatar!)
                        : null,
                    child: booking.workerAvatar == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.workerName ?? 'Worker',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        if (booking.categoryName != null)
                          Text(booking.categoryName!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                                DateFormatter.formatDate(booking.scheduledDate),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                                DateFormatter.formatTimeString(
                                    booking.scheduledTime),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: booking.status),
                ],
              ),
              if (isOngoing) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (booking.status == 'confirmed')
                      TextButton.icon(
                        onPressed: () async {
                          final chatId = await ChatService().getOrCreateChat(
                            userId: booking.userId,
                            workerId: booking.workerId,
                            bookingId: booking.id,
                          );
                          if (context.mounted) {
                            context.go('/shell/chat/$chatId');
                          }
                        },
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('Chat'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.info,
                        ),
                      ),
                    if (booking.status == 'pending' ||
                        booking.status == 'confirmed')
                      TextButton.icon(
                        onPressed: () => _cancelBooking(context, ref),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                if (!booking.isReviewed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context
                          .go('/shell/rate/${booking.id}/${booking.workerId}'),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Rate'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _cancelBooking(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(_bookingSvcProvider).cancelBooking(booking.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
