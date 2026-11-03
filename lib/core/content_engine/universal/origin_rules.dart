import 'dart:convert';
import 'dart:io';

import 'package:atlas_app/core/logging/logger.dart';

/// A learned, per-origin extraction rule produced while importing from a
/// site the universal adapter had to guess its way through. It remembers
/// which zoo sources won so later visits skip the guessing and go straight
/// to what worked.
///
/// Rules are advisory: if a stored selector stops matching (the site
/// changed, or the page was a one-off), the normal zoo fallback runs and
/// the rule is simply re-learned/overwritten. They can never shadow a
/// real plugin — plugins resolve first in the registry.
class UniversalOriginRule {
  const UniversalOriginRule({
    required this.updatedAt,
    this.titleSource,
    this.contentSelector,
    this.searchTemplate,
  });

  /// Which zoo source produced the title last time — the provenance key
  /// from [UniversalPatternZoo.detectTitleAttributed]
  /// (`ld-json`, `og`, a class selector, `heading`, `doc-title`, ...).
  final String? titleSource;

  /// The CSS container that produced reader content last time — either a
  /// known zoo selector or one learned for this origin only.
  final String? contentSelector;

  /// The search-endpoint template learned for this origin (`{query}` /
  /// `{page}` placeholders, e.g. `/search?q={query}`), either learned from
  /// a successful probe or persisted from Phase 3 search.
  final String? searchTemplate;

  /// When this rule was last written (ISO-8601, UTC).
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (titleSource != null) 'titleSource': titleSource,
        if (contentSelector != null) 'contentSelector': contentSelector,
        if (searchTemplate != null) 'searchTemplate': searchTemplate,
      };

  /// Tolerant decode: unknown fields ignored, missing/invalid fields null.
  static UniversalOriginRule? fromJson(Map<String, dynamic> json) {
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final titleSource = json['titleSource'] as String?;
    final contentSelector = json['contentSelector'] as String?;
    final searchTemplate = json['searchTemplate'] as String?;
    if (updated == null &&
        (titleSource == null || titleSource.isEmpty) &&
        (contentSelector == null || contentSelector.isEmpty) &&
        (searchTemplate == null || searchTemplate.isEmpty)) {
      return null;
    }
    return UniversalOriginRule(
      updatedAt: updated ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      titleSource: (titleSource?.isEmpty ?? true) ? null : titleSource,
      contentSelector: (contentSelector?.isEmpty ?? true)
          ? null
          : contentSelector,
      searchTemplate: (searchTemplate?.isEmpty ?? true)
          ? null
          : searchTemplate,
    );
  }

  UniversalOriginRule copyWith({
    String? titleSource,
    String? contentSelector,
    String? searchTemplate,
  }) =>
      UniversalOriginRule(
        updatedAt: DateTime.now().toUtc(),
        titleSource: titleSource ?? this.titleSource,
        contentSelector: contentSelector ?? this.contentSelector,
        searchTemplate: searchTemplate ?? this.searchTemplate,
      );
}

///Persists [UniversalOriginRule]s, one per origin, in a single JSON file.
///
/// IO failures are swallowed by design: learned rules are an optimization,
/// never a correctness requirement — the import pipeline must keep working
/// with an empty store (read-only volumes, wipes, corruption, all fine).
class UniversalOriginRuleStore {
  UniversalOriginRuleStore({required this.filePath});

  final String filePath;

  Map<String, UniversalOriginRule>? _cache;

  /// Normalizes a URL to its origin key: scheme://host[:port]/ with any
  /// path, query, fragment, and userinfo dropped.
  static String originOf(Uri uri) {
    final defaultPort =
        (uri.isScheme('https') && uri.port == 443) ||
            (uri.isScheme('http') && uri.port == 80);
    final hasPort = uri.hasPort && !defaultPort;
    return '${uri.scheme}://${uri.host}${hasPort ? ':${uri.port}' : ''}/';
  }

  Future<Map<String, UniversalOriginRule>> _loadAll() async {
    if (_cache != null) return _cache!;
    final file = File(filePath);
    // First run: nothing persisted yet. An empty store is the normal state,
    // not a failure — don't log it (a missing file used to surface as a
    // PathNotFoundException warning on every fresh install).
    if (!await file.exists()) return _cache = {};
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        _cache = {};
        return _cache!;
      }

      final rules = <String, UniversalOriginRule>{};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final rule = UniversalOriginRule.fromJson(value);
          if (rule != null) rules[key] = rule;
        }
      });
      return _cache = rules;
    } on Object catch (e) {
      AppLogger.warning(
        'UniversalOriginRuleStore: could not read rules — starting empty ($e)',
      );
      return _cache = {};
    }
  }

  /// The rule learned for [origin], or null when none exists.
  Future<UniversalOriginRule?> rule(String origin) async =>
      (await _loadAll())[origin];

  /// A snapshot of all rules — used to register learned search origins at
  /// boot. Callers get their own copy.
  Future<Map<String, UniversalOriginRule>> all() async {
    final rules = await _loadAll();
    return Map.of(rules);
  }

  /// Stores/overwrites the rule for [origin] (whole-file, cached rewrite).
  Future<void> put(String origin, UniversalOriginRule rule) async {
    final all = await _loadAll();
    all[origin] = rule;
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          all.map((key, value) => MapEntry(key, value.toJson())),
        ),
      );
    } on Object catch (e) {
      // Keep the in-memory entry so this session still benefits from the
      // rule even if persistence failed.
      AppLogger.warning(
        'UniversalOriginRuleStore: could not persist rules ($e)',
      );
    }
  }
}
