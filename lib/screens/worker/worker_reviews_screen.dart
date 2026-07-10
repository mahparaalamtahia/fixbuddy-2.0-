import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../models/review_model.dart';
import '../../providers/worker_provider.dart';
import '../../services/review_service.dart';

final _reviewServiceProvider =
    Provider<ReviewService>((ref) => ReviewService());

final workerReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, workerId) async {
  final service = ref.watch(_reviewServiceProvider);
  return await service.getWorkerReviews(workerId);
});

class WorkerReviewsScreen extends ConsumerWidget {
  const WorkerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorker = ref.watch(currentWorkerProvider);

    return currentWorker.when(
      data: (worker) {
        if (worker == null) {
          return const Scaffold(
            body: ErrorState(
              message: 'Worker profile not found',
              actionLabel: 'Retry',
            ),
          );
        }
        return _ReviewsContent(workerId: worker.id);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentWorkerProvider),
        ),
      ),
    );
  }
}

class _ReviewsContent extends ConsumerWidget {
  final String workerId;
  const _ReviewsContent({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerReviewsProvider(workerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
      ),
      body: reviewsAsync.when(
        data: (reviews) => _ReviewsBody(reviews: reviews),
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 120),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(workerReviewsProvider(workerId)),
        ),
      ),
    );
  }
}

class _ReviewsBody extends StatelessWidget {
  final List<ReviewModel> reviews;
  const _ReviewsBody({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const EmptyState(
        title: 'No reviews yet',
        description: 'Reviews from customers will appear here',
        icon: Icons.star_border,
      );
    }

    final totalReviews = reviews.length;
    final averageRating =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews;

    final ratingCounts =
        List.generate(5, (i) => reviews.where((r) => r.rating == 5 - i).length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Row(
                          children: List.generate(
                              5,
                              (i) => const Icon(
                                    Icons.star,
                                    size: 20,
                                    color: AppColors.warning,
                                  )),
                        ),
                        Text(
                          '$totalReviews reviews',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(5, (i) {
                  final star = 5 - i;
                  final count = ratingCounts[i];
                  final fraction =
                      totalReviews > 0 ? count / totalReviews : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$star \u2605',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 8,
                              backgroundColor: AppColors.divider,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.warning),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...reviews.map((review) => _ReviewCard(review: review)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userAvatar != null
                      ? NetworkImage(review.userAvatar!)
                      : null,
                  child: review.userAvatar == null
                      ? Text(
                          (review.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'Anonymous',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (review.createdAt != null)
                        Text(
                          DateFormatter.relativeTime(review.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: AppColors.warning,
                          )),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
