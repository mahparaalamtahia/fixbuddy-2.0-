import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/worker_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../../services/review_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/router/app_router.dart';

final _reviewServiceProvider =
    Provider<ReviewService>((ref) => ReviewService());

const _starLabels = {
  0: 'Tap a star',
  1: 'Poor',
  2: 'Fair',
  3: 'Good',
  4: 'Very Good',
  5: 'Excellent',
};

const _availableTags = [
  'On Time',
  'Professional',
  'Quality Work',
  'Good Communication',
  'Clean Work',
  'Fair Price',
];

class RatingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String workerId;
  const RatingScreen({
    super.key,
    required this.bookingId,
    required this.workerId,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _showThankYou = false;
  bool _hasDuplicateReview = false;
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _checkDuplicateReview();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicateReview() async {
    final data = await Supabase.instance.client
        .from('reviews')
        .select('id')
        .eq('booking_id', widget.bookingId)
        .maybeSingle();
    if (data != null && mounted) {
      setState(() => _hasDuplicateReview = true);
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a rating'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      await ref.read(_reviewServiceProvider).submitReview(
            bookingId: widget.bookingId,
            userId: user.id,
            workerId: widget.workerId,
            rating: _rating,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            tags: _selectedTags.isNotEmpty ? _selectedTags.toList() : null,
            photos: null, // Photo upload removed to match clean UI design
          );

      if (!mounted) return;
      analyticsService.trackEvent(AnalyticsService.reviewSubmitted,
          parameters: {'worker_id': widget.workerId, 'rating': _rating});
      setState(() {
        _isLoading = false;
        _showThankYou = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerAsync = ref.watch(workerByIdProvider(widget.workerId));

    if (_showThankYou) {
      return _buildThankYou();
    }

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5), // Simulate backdrop
      body: workerAsync.when(
        data: (worker) => _buildRatingForm(worker),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildRatingForm(null),
      ),
    );
  }

  Widget _buildThankYou() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 64, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              const Text('Thank You!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Your review has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingForm(WorkerModel? worker) {
    if (_hasDuplicateReview) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.feedback, size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('You have already reviewed this booking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.pop(),
                  child: const Text('Go Back',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final workerName = worker?.fullName ?? 'Worker';
    final avatarUrl = worker?.avatarUrl;
    final categoryName = worker?.categories?.isNotEmpty == true
        ? worker!.categories!.first.name?.toUpperCase() ?? 'EXPERT'
        : 'EXPERT';

    return Stack(
      children: [
        // Bottom Sheet Style Container
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 20)
              ],
            ),
            child: Column(
              children: [
                // Sheet Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Header
                      const Text(
                        'Rate Your Service Experience',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'How was your recent repair work with ',
                          children: [
                            TextSpan(
                                text: workerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            const TextSpan(text: '?'),
                          ],
                        ),
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Worker Identity
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.surface, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10)
                                ],
                                image: avatarUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            avatarUrl),
                                        fit: BoxFit.cover)
                                    : null,
                                color: AppColors.divider,
                              ),
                              child: avatarUrl == null
                                  ? const Icon(Icons.person,
                                      size: 48, color: AppColors.textSecondary)
                                  : null,
                            ),
                            Positioned(
                              bottom: -12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Interactive Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return GestureDetector(
                            onTap: () => setState(() => _rating = i + 1),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                i < _rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 48,
                                color: i < _rating
                                    ? AppColors.secondary
                                    : AppColors.divider,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _rating > 0
                            ? _starLabels[_rating]!
                            : 'Tap a star to rate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _rating > 0
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Commentary Text Area
                      const Text(
                        'LEAVE A DETAILED REVIEW',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Share your experience with ${workerName.split(' ').first}. Was the repair efficient? Did they clean up afterwards?',
                          hintStyle: const TextStyle(
                              color: AppColors.textHint, fontSize: 14),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Chip Recommendations
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final selected = _selectedTags.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selected
                                    ? _selectedTags.remove(tag)
                                    : _selectedTags.add(tag);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.divider),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Sticky Footer Action
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Submit Review and Complete Order',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating Back Button (for easy dismissal)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ],
    );
  }
}
