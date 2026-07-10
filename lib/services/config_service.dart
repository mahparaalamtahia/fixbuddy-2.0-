import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config_model.dart';

class ConfigService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<AppConfigModel>> getAllConfig() async {
    final data = await _supabase.from('app_config').select();
    return (data as List).map((e) => AppConfigModel.fromJson(e)).toList();
  }

  Future<Map<String, String>> getConfigMap() async {
    final data = await _supabase.from('app_config').select('key, value');
    final map = <String, String>{};
    for (final item in data as List) {
      map[item['key'] as String] = item['value'] as String;
    }
    return map;
  }

  Future<String?> getValue(String key) async {
    final data = await _supabase
        .from('app_config')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return data?['value'] as String?;
  }

  Future<bool> getBool(String key) async {
    final value = await getValue(key);
    return value?.toLowerCase() == 'true';
  }

  Future<void> setConfig(String key, String value) async {
    await _supabase.from('app_config').update({
      'value': value,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('key', key);
  }

  Stream<Map<String, String>> streamConfig() {
    return _supabase.from('app_config').stream(primaryKey: ['id']).map((data) {
      final map = <String, String>{};
      for (final item in data) {
        map[item['key'] as String] = item['value'] as String;
      }
      return map;
    });
  }
}
