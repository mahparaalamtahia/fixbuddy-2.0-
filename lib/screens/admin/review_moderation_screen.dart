import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/review_model.dart';

final _supabase = Supabase.instance.client;

final allReviewsProvider = FutureProvider<List<ReviewModel>>((ref) async {
  final sub = _supabase.channel('admin_all_reviews').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'reviews',
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    sub.unsubscribe();
  });

  final data = await _supabase.from('reviews').select('''
        *,
        profiles!inner(full_name, avatar_url),
        workers!inner(profiles!inner(full_name))
      ''').order('created_at', ascending: false);
  return (data as List).map((e) => ReviewModel.fromJson(e)).toList();
});

class ReviewModerationScreen extends ConsumerWidget {
  const ReviewModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(allReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Moderation')),
      body: reviews.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No reviews yet'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final review = list[i];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: review.userAvatar != null
                                    ? NetworkImage(review.userAvatar!)
                                    : null,
                                child: review.userAvatar == null
                                    ? Text(
                                        review.userName != null &&
                                                review.userName!.isNotEmpty
                                            ? review.userName![0]
                                            : 'U',
                                        style: const TextStyle(fontSize: 12))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review.userName ?? 'User',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    if (review.workerName != null)
                                      Text('Review for ${review.workerName}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                    5,
                                    (s) => Icon(
                                          s < review.rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 16,
                                          color: AppColors.warning,
                                        )),
                              ),
                            ],
                          ),
                          if (review.comment != null &&
                              review.comment!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(review.comment!),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (review.createdAt != null)
                                Text(
                                    DateFormatter.formatDateTime(
                                        review.createdAt!),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint)),
                              const Spacer(),
                              if (review.isFlagged)
                                Chip(
                                    label: const Text('Flagged',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.error)),
                                    backgroundColor:
                                        AppColors.error.withValues(alpha: 0.1),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: review.isFlagged
                                    ? null
                                    : () async {
                                        await _supabase
                                            .from('reviews')
                                            .update({'is_flagged': true}).eq(
                                                'id', review.id);
                                        ref.invalidate(allReviewsProvider);
                                      },
                                icon: const Icon(Icons.block, size: 16),
                                label: const Text('Reject',
                                    style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(
                                      color: review.isFlagged
                                          ? AppColors.divider
                                          : AppColors.error),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                onPressed: !review.isFlagged
                                    ? null
                                    : () async {
                                        await _supabase
                                            .from('reviews')
                                            .update({'is_flagged': false}).eq(
                                                'id', review.id);
                                        ref.invalidate(allReviewsProvider);
                                      },
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Approve',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: AppColors.success,
                                  backgroundColor:
                                      AppColors.success.withValues(alpha: 0.1),
                                  disabledBackgroundColor: AppColors.divider,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
