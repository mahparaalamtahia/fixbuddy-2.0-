import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> submitReview({
    required String bookingId,
    required String userId,
    required String workerId,
    required int rating,
    String? comment,
    List<String>? tags,
    List<Map<String, dynamic>>? photos,
  }) async {
    final result = await _supabase
        .from('reviews')
        .insert({
          'booking_id': bookingId,
          'user_id': userId,
          'worker_id': workerId,
          'rating': rating,
          'comment': comment,
        })
        .select('id')
        .single();
    final reviewId = result['id'] as String;

    if (photos != null && photos.isNotEmpty) {
      await _supabase.from('review_photos').insert(
            photos
                .map((p) => {
                      ...p,
                      'review_id': reviewId,
                    })
                .toList(),
          );
    }

    return reviewId;
  }

  Future<List<ReviewModel>> getWorkerReviews(String workerId) async {
    final data = await _supabase
        .from('reviews')
        .select('*, profiles(full_name, avatar_url)')
        .eq('worker_id', workerId)
        .eq('is_flagged', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => ReviewModel.fromJson(e)).toList();
  }

  Future<void> flagReview(String reviewId, bool isFlagged) async {
    await _supabase
        .from('reviews')
        .update({'is_flagged': isFlagged}).eq('id', reviewId);
  }

  Future<void> deleteReview(String reviewId) async {
    await _supabase.from('reviews').delete().eq('id', reviewId);
  }

  Future<List<ReviewModel>> getAllReviews({bool? flagged}) async {
    var query = _supabase
        .from('reviews')
        .select('*, profiles!inner(full_name, avatar_url)');
    if (flagged != null) {
      query = query.eq('is_flagged', flagged);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => ReviewModel.fromJson(e)).toList();
  }
}
