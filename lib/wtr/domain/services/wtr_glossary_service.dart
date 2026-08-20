import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_glossary_term.dart';

/// Loads and caches WTR-Lab's per-novel glossary (`/api/v2/reader/terms/`).
///
/// The site's reader fetches this public endpoint and applies the terms to the
/// source-language chapter text for the `webplus` service — the "enhanced web
/// translation". Fetches go through the same [Transport] as the chapter
/// reader calls, so they benefit from the WebView/browser context the same
/// way. The cache is keyed by the novel's raw id, so a multi-chapter read
/// fetches the glossary once.
class WtrGlossaryService {
  WtrGlossaryService({
    Map<int, List<WtrGlossaryTerm>>? cache,
    Map<int, List<WtrGlossaryTerm>>? allCache,
  }) : _cache = cache ?? <int, List<WtrGlossaryTerm>>{},
       _allCache = allCache ?? <int, List<WtrGlossaryTerm>>{};

  final Map<int, List<WtrGlossaryTerm>> _cache;
  final Map<int, List<WtrGlossaryTerm>> _allCache;

  /// Terms for [rawId], loading them on first use.
  ///
  /// A failed or malformed glossary fetch yields an empty list (never throws),
  /// so a glossary outage can't break chapter rendering — it just loses the
  /// name substitutions.
  Future<List<WtrGlossaryTerm>> load(
    Transport transport,
    Uri base, {
    required int rawId,
    Map<String, String>? headers,
  }) async {
    final cached = _cache[rawId];
    if (cached != null) return cached;
    final terms = await _fetch(transport, base, rawId: rawId, headers: headers);
    _cache[rawId] = terms;
    return terms;
  }

  Future<List<WtrGlossaryTerm>> _fetch(
    Transport transport,
    Uri base, {
    required int rawId,
    Map<String, String>? headers,
  }) async {
    try {
      final value = await transport.fetchJson(
        base.resolve('/api/v2/reader/terms/$rawId.json'),
        headers: headers,
      );
      return parse(value);
    } on Object {
      return const [];
    }
  }

  /// Parses the `/api/v2/reader/terms/{rawId}.json` shape:
  /// `{glossaries: [{data: {terms: [[[aliases...], zh, type, ?, count], ...]}}]}`.
  static List<WtrGlossaryTerm> parse(Object? value) {
    if (value is! Map) return const [];
    final glossaries = value['glossaries'];
    if (glossaries is! List || glossaries.isEmpty) return const [];
    final glossary = glossaries.first;
    if (glossary is! Map) return const [];
    final data = glossary['data'];
    if (data is! Map) return const [];
    final terms = data['terms'];
    if (terms is! List) return const [];
    return terms
        .map(WtrGlossaryTerm.fromPublicTerm)
        .whereType<WtrGlossaryTerm>()
        .toList();
  }

  /// Terms for [rawId] from *every* glossary in the response, including the AI
  /// build's community `replacements`, loading them on first use.
  ///
  /// This is the fullest zh→en map the site knows for the novel. The AI reader
  /// cleanup pass uses it to substitute any source-language terms the AI body
  /// left untranslated; `load` stays the first-glossary view used by `webplus`.
  Future<List<WtrGlossaryTerm>> loadAll(
    Transport transport,
    Uri base, {
    required int rawId,
    Map<String, String>? headers,
  }) async {
    final cached = _allCache[rawId];
    if (cached != null) return cached;
    final terms = await _fetchAll(
      transport,
      base,
      rawId: rawId,
      headers: headers,
    );
    _allCache[rawId] = terms;
    return terms;
  }

  Future<List<WtrGlossaryTerm>> _fetchAll(
    Transport transport,
    Uri base, {
    required int rawId,
    Map<String, String>? headers,
  }) async {
    try {
      final value = await transport.fetchJson(
        base.resolve('/api/v2/reader/terms/$rawId.json'),
        headers: headers,
      );
      return parseAll(value);
    } on Object {
      return const [];
    }
  }

  /// Parses every glossary in the `/api/v2/reader/terms/{rawId}.json`
  /// response plus each glossary's AI `replacements`
  /// (`{value: [[aliases...], zh], Count: n}`).
  static List<WtrGlossaryTerm> parseAll(Object? value) {
    if (value is! Map) return const [];
    final glossaries = value['glossaries'];
    if (glossaries is! List) return const [];
    final result = <WtrGlossaryTerm>[];
    for (final glossary in glossaries.whereType<Map>()) {
      final data = glossary['data'];
      if (data is! Map) continue;
      final terms = data['terms'];
      if (terms is List) {
        result.addAll(
          terms
              .map(WtrGlossaryTerm.fromPublicTerm)
              .whereType<WtrGlossaryTerm>(),
        );
      }
      final replacements = data['replacements'];
      if (replacements is List) {
        result.addAll(
          replacements
              .whereType<Map>()
              .map((r) => WtrGlossaryTerm.fromPublicTerm(r['value']))
              .whereType<WtrGlossaryTerm>(),
        );
      }
    }
    return result;
  }

  /// Test hook: clears the cache so a fresh load hits the transport again.
  void clear() {
    _cache.clear();
    _allCache.clear();
  }
}
