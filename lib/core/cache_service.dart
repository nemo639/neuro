import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const int _ttlMinutes = 5;

  static String _key(String key) => 'cache_$key';
  static String _tsKey(String key) => 'cache_ts_$key';

  static Future<void> set(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(key), jsonEncode(data));
    await prefs.setInt(_tsKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey(key));
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _ttlMinutes * 60 * 1000) return null;
    final raw = prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(key));
    await prefs.remove(_tsKey(key));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
