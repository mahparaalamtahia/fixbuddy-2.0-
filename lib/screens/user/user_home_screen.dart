import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/worker_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/category_model.dart';
import '../../models/worker_model.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  RealtimeChannel? _workersChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }

  void _setupRealtime() {
    _workersChannel = Supabase.instance.client
        .channel('public:workers:home')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'workers',
          callback: (payload) {
            ref.invalidate(featuredWorkersProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_workersChannel != null) {
      Supabase.instance.client.removeChannel(_workersChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final configMapAsync = ref.watch(configMapProvider);
    final featuredWorkersAsync = ref.watch(featuredWorkersProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final unreadCountAsync = userId != null
        ? ref.watch(unreadCountProvider(userId))
        : const AsyncValue.data(0);

    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildTopAppBar(profileAsync, unreadCount),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner (from Config)
            _buildBanner(configMapAsync),

            // Search Bar Row
            _buildSearchBar(),
            const SizedBox(height: 40),

            // Explore Services
            _buildCategories(categoriesAsync),
            const SizedBox(height: 40),

            // Top Verified Workers Nearby
            _buildFeaturedWorkers(featuredWorkersAsync),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => context.go('/shell/workers'),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        onDestinationSelected: (i) {
          if (i == 1) {
            context.go('/shell/bookings');
          } else if (i == 2) {
            context.go('/shell/profile');
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
              label: 'Bookings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Account'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(AsyncValue profile, int unreadCount) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(84),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 20,
          right: 20,
          bottom: 8,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                profile.when(
                  data: (p) => Text(
                    'Hello, ${p?.fullName?.split(' ').first ?? 'User'}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                  loading: () => const Text('Hello, User',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5)),
                  error: (_, __) => const Text('Hello, User',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Your Location',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
            InkWell(
              onTap: () => context.go('/shell/notifications'),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: AppColors.textPrimary),
                    if (unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(AsyncValue<Map<String, dynamic>> configMapAsync) {
    return configMapAsync.when(
      data: (config) {
        final banner = config['banner_message'] ?? '';
        if (banner.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(banner,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    context.go('/shell/workers?search=${val.trim()}');
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Search plumbers...',
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => context.go('/shell/workers'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.tune, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Explore Services',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              InkWell(
                onTap: () => context.go('/shell/workers'),
                child: const Text('See All',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          categoriesAsync.when(
            data: (cats) {
              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.8,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 8,
                ),
                itemCount: cats.length > 8 ? 8 : cats.length,
                itemBuilder: (context, index) {
                  if (index == 7 && cats.length > 8) {
                    return _buildCategoryItem(
                      icon: Icons.grid_view,
                      name: 'More',
                      color: AppColors.primary,
                      onTap: () => context.go('/shell/workers'),
                    );
                  }
                  final cat = cats[index];
                  return _buildCategoryItem(
                    icon: cat.icon,
                    name: cat.name,
                    color: cat.color,
                    onTap: () =>
                        context.go('/shell/workers?category=${cat.id}'),
                  );
                },
              );
            },
            loading: () => const ShimmerGrid(
                itemCount: 8, itemHeight: 80),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
      {required IconData icon,
      required String name,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedWorkers(AsyncValue<List<WorkerModel>> workersAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Service Providers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          workersAsync.when(
            data: (workers) {
              if (workers.isEmpty) {
                return const Text('No providers found',
                    style: TextStyle(color: AppColors.textSecondary));
              }
              return ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return _buildWorkerCard(worker);
                },
              );
            },
            loading: () => const ShimmerList(itemCount: 3),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerModel worker) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final chipBgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final chipTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);

    return InkWell(
      onTap: () => context.go('/shell/workers/${worker.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    image: worker.avatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(worker.avatarUrl!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: worker.avatarUrl == null
                      ? Icon(
                          Icons.person,
                          size: 36,
                          color: AppColors.primary.withValues(alpha: 0.8))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              worker.fullName ?? 'Service Professional',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '৳${worker.hourlyRate.toStringAsFixed(0)}/hr',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.work_outline, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${worker.experienceYears} years experience',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            worker.avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (worker.categories != null && worker.categories!.isNotEmpty)
                    ...worker.categories!.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              (c.name ?? '').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ))
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'VERIFIED PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  if (worker.serviceAreas != null && worker.serviceAreas!.isNotEmpty)
                    ...worker.serviceAreas!.map((a) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: chipBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 11, color: chipTextColor),
                                const SizedBox(width: 3),
                                Text(
                                  a.name ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: chipTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                  else if (worker.areaName != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: chipBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 11, color: chipTextColor),
                            const SizedBox(width: 3),
                            Text(
                              worker.areaName!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: chipTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
