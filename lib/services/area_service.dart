import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/area_model.dart';

class AreaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<AreaModel>> getActiveAreas() async {
    final data = await _supabase
        .from('areas')
        .select('*')
        .eq('is_active', true)
        .order('sort_order');
    return (data as List).map((e) => AreaModel.fromJson(e)).toList();
  }

  Future<List<AreaModel>> getAllAreas() async {
    final data = await _supabase.from('areas').select('*').order('sort_order');
    return (data as List).map((e) => AreaModel.fromJson(e)).toList();
  }

  Future<AreaModel> createArea(Map<String, dynamic> data) async {
    final result = await _supabase.from('areas').insert(data).select().single();
    return AreaModel.fromJson(result);
  }

  Future<void> updateArea(String id, Map<String, dynamic> data) async {
    await _supabase.from('areas').update(data).eq('id', id);
  }

  Future<void> deleteArea(String id) async {
    await _supabase.from('areas').delete().eq('id', id);
  }
}
