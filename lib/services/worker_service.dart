import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_model.dart';
import '../models/availability_slot_model.dart';
import '../models/worker_document_model.dart';

class WorkerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const int _pageSize = 10;

  Future<List<WorkerModel>> getAvailableWorkers({
    String? categoryId,
    String? areaId,
    String? searchQuery,
    String sortBy = 'top_rated',
    int page = 0,
    int limit = _pageSize,
  }) async {
    final from = page * limit;

    final data = await _supabase.rpc('search_professionals', params: {
      'p_search_query': searchQuery,
      'p_category_id': categoryId,
      'p_area_id': areaId,
      'p_sort_by': sortBy,
      'p_limit': limit,
      'p_offset': from,
    });

    final List<dynamic> resultList = data as List<dynamic>;
    return resultList.map((e) => WorkerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WorkerModel>> getFeaturedWorkers({int limit = 100}) async {
    try {
      final data = await _supabase
          .from('workers')
          .select('''
            id, profile_id, bio, experience_years, hourly_rate,
            is_available, is_verified, avg_rating, review_count, total_bookings,
            mode,
            profiles!inner(id, full_name, email, phone, avatar_url, area_id,
              areas(name)
            ),
            worker_categories(category_id,
              categories(name, icon_name, color_hex)
            ),
            worker_skills(skill),
            worker_areas(area_id, areas(name))
          ''')
          .eq('is_available', true)
          // Temporarily commented out for testing so unverified/new workers show up
          // .eq('is_verified', true)
          // .gte('avg_rating', 4.0)
          .order('avg_rating', ascending: false)
          .order('review_count', ascending: false)
          .limit(limit);
      return (data as List).map((e) => WorkerModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<WorkerModel?> getWorkerById(String workerId) async {
    final data = await _supabase.from('workers').select('''
          id, profile_id, bio, experience_years, hourly_rate,
          is_available, is_verified, avg_rating, review_count, total_bookings,
          created_at,
          mode,
          profiles!inner(id, full_name, email, phone, avatar_url, area_id,
            areas(name)
          ),
          worker_categories(category_id,
            categories(name, icon_name, color_hex)
          ),
          worker_skills(id, skill),
          worker_areas(area_id, areas(name))
        ''').eq('id', workerId).maybeSingle();
    if (data == null) return null;
    return WorkerModel.fromJson(data);
  }

  Future<WorkerModel?> getCurrentWorker(String profileId) async {
    final data = await _supabase.from('workers').select('''
          id, profile_id, bio, experience_years, hourly_rate,
          is_available, is_verified, avg_rating, review_count, total_bookings,
          mode,
          profiles!inner(id, full_name, email, phone, avatar_url, area_id,
            areas(name)
          ),
          worker_categories(category_id,
            categories(name, icon_name, color_hex)
          ),
          worker_skills(id, skill),
          worker_areas(area_id, areas(name))
        ''').eq('profile_id', profileId).maybeSingle();
    if (data == null) return null;
    return WorkerModel.fromJson(data);
  }

  Future<void> updateWorker(
      String workerId, Map<String, dynamic> updates) async {
    await _supabase.from('workers').update(updates).eq('id', workerId);
  }

  Future<void> toggleAvailability(String workerId, bool isAvailable) async {
    await _supabase
        .from('workers')
        .update({'is_available': isAvailable}).eq('id', workerId);
  }

  Future<void> addCategory(String workerId, String categoryId) async {
    await _supabase.from('worker_categories').insert({
      'worker_id': workerId,
      'category_id': categoryId,
    });
  }

  Future<void> removeCategory(String workerId, String categoryId) async {
    await _supabase
        .from('worker_categories')
        .delete()
        .eq('worker_id', workerId)
        .eq('category_id', categoryId);
  }

  Future<void> addSkill(String workerId, String skill) async {
    await _supabase.from('worker_skills').insert({
      'worker_id': workerId,
      'skill': skill,
    });
  }

  Future<void> removeSkill(String workerId, String skill) async {
    await _supabase
        .from('worker_skills')
        .delete()
        .eq('worker_id', workerId)
        .eq('skill', skill);
  }

  Future<void> addArea(String workerId, String areaId) async {
    await _supabase.from('worker_areas').insert({
      'worker_id': workerId,
      'area_id': areaId,
    });
  }

  Future<void> removeArea(String workerId, String areaId) async {
    await _supabase
        .from('worker_areas')
        .delete()
        .eq('worker_id', workerId)
        .eq('area_id', areaId);
  }

  Future<Map<String, dynamic>> getWorkerStats(String workerId) async {
    return await _supabase
        .rpc('get_worker_stats', params: {'p_worker_id': workerId});
  }

  Future<Map<String, dynamic>> getWorkerFullProfile(String workerId) async {
    return await _supabase
        .rpc('get_worker_full_profile', params: {'p_worker_id': workerId});
  }

  Future<List<WorkerDocumentModel>> getWorkerDocuments(String workerId) async {
    final data = await _supabase
        .from('worker_documents')
        .select()
        .eq('worker_id', workerId)
        .order('uploaded_at', ascending: false);
    return (data as List).map((e) => WorkerDocumentModel.fromJson(e)).toList();
  }

  Stream<List<WorkerDocumentModel>> watchWorkerDocuments(String workerId) {
    return _supabase
        .from('worker_documents')
        .stream(primaryKey: ['id'])
        .eq('worker_id', workerId)
        .order('uploaded_at', ascending: false)
        .map((data) => data.map((e) => WorkerDocumentModel.fromJson(e)).toList());
  }

  Future<void> uploadWorkerDocument(Map<String, dynamic> doc) async {
    await _supabase.from('worker_documents').insert(doc);
  }

  Future<void> verifyDocument(
      String docId, String status, String? rejectionReason) async {
    final updates = <String, dynamic>{
      'status': status,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status == 'rejected' && rejectionReason != null) {
      updates['rejection_reason'] = rejectionReason;
    }
    await _supabase.from('worker_documents').update(updates).eq('id', docId);
  }

  Future<List<AvailabilitySlot>> getAvailabilitySlots(String workerId) async {
    final data = await _supabase
        .from('worker_availability_slots')
        .select()
        .eq('worker_id', workerId)
        .order('day_of_week')
        .order('period');
    return (data as List).map((e) => AvailabilitySlot.fromJson(e)).toList();
  }

  Future<void> upsertAvailabilitySlot(Map<String, dynamic> slot) async {
    await _supabase
        .from('worker_availability_slots')
        .upsert(slot, onConflict: 'worker_id, day_of_week, period');
  }

  Future<void> setAvailabilitySlots(
      String workerId, List<Map<String, dynamic>> slots) async {
    for (final slot in slots) {
      slot['worker_id'] = workerId;
    }
    await _supabase.from('worker_availability_slots').upsert(
        slots
            .map((s) => {
                  ...s,
                  'worker_id': workerId,
                })
            .toList(),
        onConflict: 'worker_id, day_of_week, period');
  }
}
