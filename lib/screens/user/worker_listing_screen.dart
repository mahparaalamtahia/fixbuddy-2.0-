import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../core/widgets/app_error_widget.dart';
import 'dart:async';
import '../../providers/worker_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/worker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';

class WorkerListingScreen extends ConsumerStatefulWidget {
  final String? categoryId;
  final String? searchQuery;
  const WorkerListingScreen({super.key, this.categoryId, this.searchQuery});

  @override
  ConsumerState<WorkerListingScreen> createState() =>
      _WorkerListingScreenState();
}

class _WorkerListingScreenState extends ConsumerState<WorkerListingScreen> {
  String? _selectedCategoryId;
  String? _selectedAreaId;
  String _sortBy = 'top_rated';
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _debouncedSearchQuery;
  RealtimeChannel? _workersChannel;
  bool _showSearch = false; // toggle search bar

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchController.text = widget.searchQuery!;
      _debouncedSearchQuery = widget.searchQuery;
      _showSearch = true;
    }
    _setupRealtime();
  }

  void _setupRealtime() {
    _workersChannel = Supabase.instance.client
        .channel('public:workers:listing')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'workers',
          callback: (payload) {
            ref.invalidate(availableWorkersProvider);
          },
        )
        .subscribe();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _debouncedSearchQuery = query.trim().isNotEmpty ? query.trim() : null;
      });
    });
  }

  @override
  void dispose() {
    _workersChannel?.unsubscribe();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _getCategoryName(List<dynamic> categories) {
    if (_selectedCategoryId == null) return 'All Professionals';
    try {
      final cat = categories.firstWhere((c) => c.id == _selectedCategoryId);
      return cat.name;
    } catch (_) {
      return 'Professionals';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = WorkerSearchFilters(
      categoryId: _selectedCategoryId,
      areaId: _selectedAreaId,
      searchQuery: _debouncedSearchQuery,
      sortBy: _sortBy,
    );
    final workers = ref.watch(availableWorkersProvider(filters));
    final categoriesState = ref.watch(activeCategoriesProvider);

    String headerTitle = 'Professionals';
    if (categoriesState.hasValue) {
      headerTitle = _getCategoryName(categoriesState.value!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Custom Header matching design
          _buildHeader(headerTitle),
          
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search workers by name or skill...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

          // Filters row
          categoriesState.when(
            data: (cats) => _buildFiltersRow(cats),
            loading: () => const SizedBox(height: 72), // Approx height of filter row
            error: (_, __) => const SizedBox(height: 72),
          ),

          // Main list
          Expanded(
            child: workers.when(
              data: (list) => list.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemBuilder: (_, i) => _WorkerCard(worker: list[i]),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ShimmerList(itemCount: 4),
              ),
              error: (e, _) => AppErrorWidget(error: e),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                     if (context.canPop()) {
                       context.pop();
                     } else {
                       context.go('/shell');
                     }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                      if (_debouncedSearchQuery != null &&
                        _debouncedSearchQuery!.isNotEmpty)
                      Text(
                        'Results for: $_debouncedSearchQuery',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (_selectedAreaId != null)
                      const Text(
                        'Filtered by area',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5),
                      )
                    else
                      const Text(
                        'All Professionals',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
            InkWell(
                onTap: () {
                  setState(() {
                    _showSearch = !_showSearch;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.search, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              // User avatar (Assuming standard generic avatar if user image not loaded in this context)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(Icons.person,
                    color: AppColors.primary, size: 24),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFiltersRow(List<dynamic> cats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Filter Button (acting as clear/reset for now or could open a modal)
          InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryId = null;
                _selectedAreaId = null;
                _searchController.clear();
                _debouncedSearchQuery = null;
                _sortBy = 'top_rated';
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4)
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Reset',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dynamic Categories as filter chips
          ...cats.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedCategoryId = isSelected ? null : cat.id;
                }),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(cat.name,
                      style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ),
            );
          }),

          // Sort dropdown inside a chip
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(24),
              ),
              child: DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(
                      value: 'top_rated', child: Text('Top Rated')),
                  DropdownMenuItem(
                      value: 'lowest_price', child: Text('Lowest Price')),
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(
                      value: 'most_reviewed', child: Text('Most Reviewed')),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? 'top_rated'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  size: 48, color: AppColors.divider),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Providers Found',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or expanding your search to find available professionals.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategoryId = null;
                  _selectedAreaId = null;
                  _searchController.clear();
                  _debouncedSearchQuery = null;
                  _sortBy = 'top_rated';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/shell/workers/${worker.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 400;
            if (isSmall) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildImageSection()),
                  const SizedBox(height: 16),
                  _buildDetailsSection(context),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                const SizedBox(width: 24),
                Expanded(child: _buildDetailsSection(context)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.divider,
              image: worker.avatarUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(worker.avatarUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            child: worker.avatarUrl == null
                ? const Center(
                    child: Icon(Icons.person,
                        size: 64, color: AppColors.primary))
                : null,
          ),
          Positioned(
            bottom: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    worker.avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                worker.fullName ?? 'Professional Worker',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(
              '৳${worker.hourlyRate.toStringAsFixed(0)}/hr',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.work_outline, size: 14, color: AppColors.textSecondary),
            Text(
              '${worker.experienceYears} yrs exp',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            if (worker.categories != null && worker.categories!.isNotEmpty)
              ...worker.categories!.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  c.name ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                ),
              )),
            if (worker.serviceAreas != null && worker.serviceAreas!.isNotEmpty)
              ...worker.serviceAreas!.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  a.name ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              )),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (worker.skills?.isNotEmpty == true
                  ? worker.skills!.take(3).toList()
                  : <String>[])
              .map((s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark)),
                  ))
              .toList()
            ..addAll(worker.skills != null && worker.skills!.length > 3
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('+${worker.skills!.length - 3} more',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark)),
                    )
                  ]
                : []),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => context.push('/shell/book', extra: worker.id),
                child: const Text('Book Now',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => _handleChat(context, worker),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Icon(Icons.chat_bubble_outline,
                        color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleChat(BuildContext context, WorkerModel worker) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to chat')));
      return;
    }
    try {
      final bookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('user_id', currentUser.id)
          .eq('worker_id', worker.id)
          .order('created_at', ascending: false)
          .limit(1);

      String? bookingId;
      if ((bookingsResponse as List).isNotEmpty) {
        bookingId = bookingsResponse.first['id'] as String;
      }
      final chatId = await ChatService().getOrCreateChat(
        userId: currentUser.id,
        workerId: worker.id,
        bookingId: bookingId,
      );
      if (context.mounted) {
        context.push('/shell/chat/$chatId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating chat: $e')));
      }
    }
  }
}
