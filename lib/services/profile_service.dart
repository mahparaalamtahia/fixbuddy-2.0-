import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ProfileModel?> getProfile(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select('*, areas(name)')
        .eq('id', userId)
        .single();
    return ProfileModel.fromJson(data);
  }

  Future<void> updateProfile(
      String userId, Map<String, dynamic> updates) async {
    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  Future<List<ProfileModel>> getWorkerProfiles() async {
    final data = await _supabase
        .from('profiles')
        .select('*, areas(name)')
        .eq('role', 'worker')
        .eq('is_active', true);
    return (data as List).map((e) => ProfileModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getProfileByRole(String userId) async {
    return await _supabase
        .from('profiles')
        .select('role, is_active')
        .eq('id', userId)
        .single();
  }
}
