import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

class DiscoverSettingsStore {
  static const String _keyIntervalHours = 'discover_update_interval_hours';

  static Future<int> getIntervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyIntervalHours) ?? 12;
  }

  static Future<void> setIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIntervalHours, hours);
  }
}

class DiscoverCacheService {
  DiscoverCacheService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Map<String, List<TrendingBook>>?> getCachedTrending() async {
    try {
      final rows = await _db.customSelect(
        'SELECT data_json, expires_at FROM discover_cache WHERE cache_key = ? LIMIT 1',
        variables: [const Variable<String>('trending_all')],
      ).get();

      if (rows.isEmpty) return null;

      final r = rows.first;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(r.read<int>('expires_at'));
      if (DateTime.now().isAfter(expiresAt)) {
        return null;
      }

      final jsonStr = r.read<String>('data_json');
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      final result = <String, List<TrendingBook>>{};

      for (final entry in decoded.entries) {
        if (entry.value is List) {
          result[entry.key] = (entry.value as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => TrendingBook.fromJson(item))
              .toList();
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedTrending(
    Map<String, List<TrendingBook>> trendingBooks,
    int ttlHours,
  ) async {
    try {
      final now = DateTime.now();
      final expires = ttlHours > 0
          ? now.add(Duration(hours: ttlHours))
          : now.add(const Duration(days: 365));

      final serialized = <String, dynamic>{};
      for (final entry in trendingBooks.entries) {
        serialized[entry.key] = entry.value.map((b) => b.toJson()).toList();
      }

      await _db.customStatement(
        '''
        INSERT INTO discover_cache (cache_key, category, data_json, fetched_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(cache_key) DO UPDATE SET
          data_json = excluded.data_json,
          fetched_at = excluded.fetched_at,
          expires_at = excluded.expires_at
        ''',
        [
          'trending_all',
          'trending',
          jsonEncode(serialized),
          now.millisecondsSinceEpoch,
          expires.millisecondsSinceEpoch,
        ],
      );
    } catch (_) {}
  }

  Future<List<TrendingBook>?> getCachedRecommendations() async {
    try {
      final rows = await _db.customSelect(
        'SELECT data_json, expires_at FROM discover_cache WHERE cache_key = ? LIMIT 1',
        variables: [const Variable<String>('for_you')],
      ).get();

      if (rows.isEmpty) return null;

      final r = rows.first;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(r.read<int>('expires_at'));
      if (DateTime.now().isAfter(expiresAt)) {
        return null;
      }

      final jsonStr = r.read<String>('data_json');
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => TrendingBook.fromJson(item))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedRecommendations(
    List<TrendingBook> recs,
    int ttlHours,
  ) async {
    try {
      final now = DateTime.now();
      final expires = ttlHours > 0
          ? now.add(Duration(hours: ttlHours))
          : now.add(const Duration(days: 365));

      final serialized = recs.map((b) => b.toJson()).toList();

      await _db.customStatement(
        '''
        INSERT INTO discover_cache (cache_key, category, data_json, fetched_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(cache_key) DO UPDATE SET
          data_json = excluded.data_json,
          fetched_at = excluded.fetched_at,
          expires_at = excluded.expires_at
        ''',
        [
          'for_you',
          'recommendation',
          jsonEncode(serialized),
          now.millisecondsSinceEpoch,
          expires.millisecondsSinceEpoch,
        ],
      );
    } catch (_) {}
  }

  Future<void> clearCache() async {
    await _db.customStatement('DELETE FROM discover_cache');
  }
}

