import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Session cache
  static Future<void> cacheSession(String key, String value) async {
    await _prefs.setString('session_$key', value);
  }

  static String? getCachedSession(String key) {
    return _prefs.getString('session_$key');
  }

  static Future<void> clearSession() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('session_'));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // Generic storage
  static Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static String? getString(String key) => _prefs.getString(key);

  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  static int? getInt(String key) => _prefs.getInt(key);

  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  static Future<void> clear() async {
    await _prefs.clear();
  }
}
