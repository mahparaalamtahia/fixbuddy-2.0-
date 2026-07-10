import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/worker_model.dart';
import '../../models/booking_model.dart';
import '../../providers/worker_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/worker_service.dart';
import '../../services/booking_service.dart';

final _workerServiceProvider =
    Provider<WorkerService>((ref) => WorkerService());
final _bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

Future<void> _switchMode(BuildContext context, WidgetRef ref, WorkerModel worker, String newMode) async {
  try {
    await ref.read(_workerServiceProvider).updateWorker(worker.id, {'mode': newMode});
    ref.invalidate(currentWorkerProvider);
    if (context.mounted) {
      if (newMode == 'seeking') {
        context.go('/shell');
      } else {
        context.go('/worker-shell');
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to switch: $e')));
    }
  }
}

class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorker = ref.watch(currentWorkerProvider);
    final workerId = currentWorker.whenOrNull(data: (w) => w?.id);
    final unreadCount = workerId != null
        ? ref.watch(unreadCountProvider(workerId))
        : const AsyncValue.data(0);
    final docsAsync = workerId != null
        ? ref.watch(workerDocumentsProvider(workerId))
        : const AsyncValue.data(<dynamic>[]);

    return currentWorker.when(
      data: (worker) {
        if (worker == null) {
          return const Scaffold(body: Center(child: Text('Worker not found')));
        }
        return Scaffold(
          drawer: _WorkerDrawer(worker: worker),
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, ${worker.fullName?.split(' ').first ?? 'Provider'}!',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const Text('FixBuddy Pro',
                    style: TextStyle(fontSize: 20, color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ],
            ),
            actions: [
              Badge(
                isLabelVisible: (unreadCount.valueOrNull ?? 0) > 0,
                label: Text('${unreadCount.valueOrNull ?? 0}'),
                child: IconButton(
                  icon: const Icon(Icons.notifications, color: AppColors.textSecondary),
                  onPressed: () => context.go('/worker-shell/notifications'),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                if (!worker.isVerified)
                  SliverToBoxAdapter(
                    child: docsAsync.when(
                      data: (docs) {
                        final hasDocs = docs.isNotEmpty;
                        final hasRejected = docs.any((d) => d.status == 'rejected');
                        final isPending = hasDocs && !hasRejected && docs.any((d) => d.status == 'pending');
                        
                        String title = 'Account Unverified';
                        String message = 'Upload documents to get verified and start receiving bookings.';
                        Color color = Colors.orange;
                        
                        if (hasRejected) {
                          title = 'Document Rejected';
                          message = 'One or more of your documents were rejected. Please check and upload again.';
                          color = Colors.red;
                        } else if (isPending) {
                          title = 'Verification Pending';
                          message = 'Your documents are currently under review by our team. Please check back later.';
                          color = Colors.blue;
                        }
                        
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: color),
                                  const SizedBox(width: 8),
                                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 12),
                              if (!isPending)
                          ElevatedButton(
                            onPressed: () => context.push('/worker-shell/verification'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            child: const Text('Upload Documents'),
                          ),
                        ],
                      ),
                    );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading status: $e')),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _switchMode(context, ref, worker, 'seeking'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Hiring Client Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: const Text('Service Provider Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 2),
                                image: worker.avatarUrl != null
                                    ? DecorationImage(image: CachedNetworkImageProvider(worker.avatarUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: worker.avatarUrl == null ? const Icon(Icons.person, size: 32) : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: worker.isVerified ? AppColors.success : Colors.grey, // Verified green or grey
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(worker.fullName ?? 'Worker', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  if (worker.isVerified)
                                    const Icon(Icons.verified, color: AppColors.primary, size: 18),
                                ],
                              ),
                              Text(
                                worker.serviceAreas?.isNotEmpty == true ? worker.serviceAreas!.map((a) => a.name).join(', ') : (worker.areaName ?? 'No area set'),
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ONLINE AVAILABILITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 0.5)),
                                  Switch(
                                    value: worker.isAvailable,
                                    onChanged: (v) => ref.read(_workerServiceProvider).toggleAvailability(worker.id, v),
                                    activeThumbColor: AppColors.primary,
                                    activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StatsSection(worker: worker),
                ),
                SliverToBoxAdapter(
                  child: _JobStatesSection(workerId: worker.id),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.divider)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(icon: Icons.dashboard, label: 'Dashboard', isActive: true, onTap: () {}),
                    _BottomNavItem(icon: Icons.pending_actions, label: 'Requests', isActive: false, onTap: () => context.go('/worker-shell/requests')),
                    _BottomNavItem(icon: Icons.calendar_month, label: 'Schedule', isActive: false, onTap: () => context.go('/worker-shell/history')),
                    _BottomNavItem(icon: Icons.person, label: 'Profile', isActive: false, onTap: () => context.go('/worker-shell/profile')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your dashboard...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                const Text('Failed to load dashboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkerDrawer extends ConsumerWidget {
  final WorkerModel worker;
  const _WorkerDrawer({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header: Deep blue backdrop with profile
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 32, left: 24, right: 24),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -48,
                  right: -48,
                  child: Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
                            image: worker.avatarUrl != null
                                ? DecorationImage(image: CachedNetworkImageProvider(worker.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: worker.avatarUrl == null ? const Icon(Icons.person, size: 48, color: Colors.white) : null,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: worker.isVerified ? AppColors.success : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      worker.fullName ?? 'Worker',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.email ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 24, bottom: 24, left: 16, right: 16),
              children: [
                const _DrawerNavTile(icon: Icons.pending_actions, label: 'Requests', route: '/worker-shell/requests'),
                const _DrawerNavTile(icon: Icons.history, label: 'Booking History', route: '/worker-shell/history'),
                const _DrawerNavTile(icon: Icons.payments, label: 'Financial Earnings', route: '/worker-shell/earnings'),
                const _DrawerNavTile(icon: Icons.chat_bubble_outline, label: 'Conversations & Chats', route: '/worker-shell/chats'),
                const _DrawerNavTile(icon: Icons.star_outline, label: 'Customer Reviews', route: '/worker-shell/reviews'),
                const _DrawerNavTile(icon: Icons.person_outline, label: 'Account Profile', route: '/worker-shell/profile'),
                const _DrawerNavTile(icon: Icons.notifications_none, label: 'System Notifications', route: '/worker-shell/notifications'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                  child: Divider(color: AppColors.divider, height: 1),
                ),
                InkWell(
                  onTap: () => _switchMode(context, ref, worker, 'seeking'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.swap_horiz, color: AppColors.primary, weight: 700),
                        SizedBox(width: 16),
                        Text('Switch to Seeker Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Footer / Logout
          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16, left: 16, right: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: InkWell(
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout Platform Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _DrawerNavTile({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? AppColors.primary : AppColors.textSecondary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  final WorkerModel worker;
  const _StatsSection({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(workerBookingsProvider(worker.id));

    return bookingsAsync.when(
      data: (bookings) {
        final completed = bookings.where((b) => b.status == 'completed').toList();
        final totalEarnings = completed.fold<double>(0, (sum, b) => sum + (b.totalAmount ?? 0));
        final now = DateTime.now();
        final thisMonthCompleted = completed
            .where((b) => b.createdAt != null && b.createdAt!.month == now.month && b.createdAt!.year == now.year)
            .toList();
        final monthlyEarnings = thisMonthCompleted.fold<double>(0, (sum, b) => sum + (b.totalAmount ?? 0));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _DarkStatCard(
                icon: Icons.star,
                iconColor: AppColors.secondary,
                label: 'RATING',
                value: worker.avgRating.toStringAsFixed(1),
                topRightAction: 'Reviews',
              ),
              _DarkStatCard(
                icon: Icons.work,
                iconColor: AppColors.primary,
                label: 'JOBS MANAGED',
                value: '${worker.totalBookings}',
              ),
              _DarkStatCard(
                icon: Icons.payments,
                iconColor: AppColors.success,
                label: 'MONTHLY EARNINGS',
                value: '৳${monthlyEarnings.toStringAsFixed(0)}',
              ),
              _DarkStatCard(
                icon: Icons.account_balance_wallet,
                iconColor: AppColors.warning,
                label: 'LIFETIME METRICS',
                value: '৳${totalEarnings.toStringAsFixed(0)}',
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Unable to load stats', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _DarkStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? topRightAction;

  const _DarkStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.topRightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // slate-gray
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              if (topRightAction != null)
                Text(
                  topRightAction!,
                  style: const TextStyle(fontSize: 10, color: AppColors.primary, decoration: TextDecoration.underline),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobStatesSection extends ConsumerStatefulWidget {
  final String workerId;
  const _JobStatesSection({required this.workerId});

  @override
  ConsumerState<_JobStatesSection> createState() => _JobStatesSectionState();
}

class _JobStatesSectionState extends ConsumerState<_JobStatesSection> {
  String? _selectedFilter;
  final List<String> _filters = ['Requests', 'Pending', 'In Progress', 'Completed'];
  RealtimeChannel? _bookingsChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
    // Defensive initialization block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Any explicit state assignment logic goes here
    });
  }

  void _setupRealtime() {
    _bookingsChannel = Supabase.instance.client
        .channel('public:bookings_${widget.workerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'worker_id',
            value: widget.workerId,
          ),
          callback: (payload) {
            ref.invalidate(workerBookingsProvider(widget.workerId));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _bookingsChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(workerBookingsProvider(widget.workerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = (_selectedFilter ?? 'Requests') == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (!mounted) return;
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        bookingsAsync.when(
          data: (bookings) {
            if (_selectedFilter == null) {
              // Auto-select first non-empty filter to avoid empty state on launch
              String initialFilter = 'Requests';
              if (bookings.any((b) => b.status == 'pending')) {
                initialFilter = 'Requests';
              } else if (bookings.any((b) => b.status == 'confirmed' || b.status == 'scheduled')) {
                initialFilter = 'Pending';
              } else if (bookings.any((b) => b.status == 'in_progress')) {
                initialFilter = 'In Progress';
              } else if (bookings.any((b) => b.status == 'completed')) {
                initialFilter = 'Completed';
              }
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedFilter = initialFilter);
              });
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }

            final filteredBookings = bookings.where((b) {
              switch (_selectedFilter) {
                case 'Requests':
                  return b.status == 'pending';
                case 'Pending':
                  return b.status == 'confirmed' || b.status == 'scheduled';
                case 'In Progress':
                  return b.status == 'in_progress';
                case 'Completed':
                  return b.status == 'completed';
                default:
                  return false;
              }
            }).toList();

            if (filteredBookings.isEmpty) {
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                alignment: Alignment.center,
                child: const Text('No jobs found for this state.', style: TextStyle(color: AppColors.textSecondary)),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: filteredBookings.map((b) => _JobCard(booking: b, filterState: _selectedFilter ?? 'Requests')).toList(),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading jobs: $e', style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ],
    );
  }
}

class _JobCard extends ConsumerWidget {
  final BookingModel booking;
  final String filterState;
  const _JobCard({required this.booking, required this.filterState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.categoryName ?? 'Service Job', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    if (booking.userName != null)
                      Text('Client: ${booking.userName}', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    Text(booking.areaName ?? 'Address', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text('Date: ${booking.scheduledDate.toIso8601String().split('T')[0]} at ${booking.scheduledTime}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Notes: ${booking.notes}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filterState.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          if (filterState == 'Requests') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(_bookingServiceProvider).updateBookingStatus(booking.id, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref.read(_bookingServiceProvider).updateBookingStatus(booking.id, 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ] else if (filterState == 'Pending') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => ref.read(_bookingServiceProvider).updateBookingStatus(booking.id, 'in_progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Job'),
              ),
            ),
          ] else if (filterState == 'In Progress') ...[
            const SizedBox(height: 16),
            SliderTheme(
              data: const SliderThemeData(
                thumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
                trackHeight: 6,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: 0.5,
                onChanged: (v) {},
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => ref.read(_bookingServiceProvider).updateBookingStatus(booking.id, 'completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark Completed'),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
