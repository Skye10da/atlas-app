import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Reads WTR-Lab's account term preferences (`/api/v2/term-preferences`) for a
/// single glossary term and resolves its top preference.
///
/// The site's Term Editor records the replacement choices applied to each
/// source term, keyed by the novel's raw id and the Chinese term's hash. This
/// service lets Atlas mirror the account-aware glossary the site renders in AI
/// mode: for each Chinese term the AI body leaves untranslated it asks which
/// English replacement the account prefers and uses the highest-counted one.
///
/// Fail-soft by design: a failed, malformed, or anonymous request resolves to
/// no preference (`null`), so a term-preferences outage can't break rendering —
/// it just loses the account-specific substitution.
class WtrTermPreferenceService {
  WtrTermPreferenceService({Map<(int, String), String?>? cache})
      : _cache = cache ?? <(int, String), String?>{};

  final Map<(int, String), String?> _cache;

  /// The top preferred replacement for [zh] in novel [rawId], or null when the
  /// account has no recorded preference (or the lookup fails). Cached per
  /// (rawId, zh) so a multi-chapter read asks once per term.
  ///
  /// [lang] is the target language the site resolves replacements into (e.g.
  /// `en`); it is forwarded as the endpoint's `lang` query parameter.
  Future<String?> topPreference(
    Transport transport,
    Uri base, {
    required int rawId,
    required String zh,
    required String lang,
    Map<String, String>? headers,
  }) async {
    final key = (rawId, zh);
    if (_cache.containsKey(key)) return _cache[key];
    final preference = await _fetch(
      transport,
      base,
      rawId: rawId,
      zh: zh,
      lang: lang,
      headers: headers,
    );
    _cache[key] = preference;
    return preference;
  }

  Future<String?> _fetch(
    Transport transport,
    Uri base, {
    required int rawId,
    required String zh,
    required String lang,
    Map<String, String>? headers,
  }) async {
    try {
      final value = await transport.fetchJson(
        base
            .resolve('/api/v2/term-preferences')
            .replace(
              queryParameters: {
                'source_id': 'id.raw.$rawId',
                'hash': zh,
                'lang': lang,
              },
            ),
        headers: headers,
      );
      return parseTop(value);
    } on Object {
      return null;
    }
  }

  /// The top replacement from a `/api/v2/term-preferences` response
  /// (`{success: true, data: [{replacement, count, ...}, ...]}`): the
  /// highest-counted replacement, or null when the payload has none.
  static String? parseTop(Object? value) {
    final entries = _entries(value);
    String? best;
    num bestCount = -1;
    for (final entry in entries) {
      final replacement = _firstString(
        entry,
        const [
          'replacement',
          'term',
          'target',
          'target_text',
          'targetText',
          'translation',
          'value',
          'en',
          'to',
        ],
      );
      if (replacement == null || replacement.isEmpty) continue;
      final count = _firstNumber(
        entry,
        const [
          'count',
          'Count',
          'score',
          'votes',
          'uses',
          'usage_count',
          'user_count',
          'userCount',
          'preference_count',
        ],
      );
      if (best == null || count > bestCount) {
        best = replacement;
        bestCount = count;
      }
    }
    return best;
  }

  static List<Map> _entries(Object? value) {
    if (value is List) return value.whereType<Map>().toList();
    if (value is! Map) return const [];
    for (final key in const [
      'data',
      'terms',
      'items',
      'results',
      'preferences',
      'replacements',
      'sources',
    ]) {
      final entry = value[key];
      if (entry is List) return entry.whereType<Map>().toList();
      if (entry is Map) {
        final nested = _entries(entry);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }

  static String? _firstString(Map map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String) return value;
      if (value is List && value.isNotEmpty && value.first is String) {
        return value.first as String;
      }
    }
    return null;
  }

  static num _firstNumber(Map map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value;
    }
    return 0;
  }

  /// Test hook: clears the cache so a fresh lookup hits the transport again.
  void clear() => _cache.clear();
}