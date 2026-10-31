import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart'
    show ChapterModel;
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart'
    show NovelModel;
import 'package:atlas_app/core/content_acquisition/services/import_service.dart'
    show ImportException;
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
import 'package:atlas_app/core/content_engine/universal/site_pattern_zoo.dart';

/// A searchable view of ONE learned origin — a site the universal importer
/// previously worked on, identified by its origin key in the rule store.
///
/// `sourceName` is the origin host, so the site appears in the saved-sites
/// directory and gets its `/sources/<host>` search screen automatically,
/// reusing every existing search surface.
///
/// The first search probes common search-endpoint conventions
/// ([SitePatternZoo.searchUrlTemplates]); the winner is learned into the
/// origin rule so later searches hit it directly. When the learned template
/// stops yielding links, probing runs again — except when the page really
/// proclaims "no results", which is a legitimate empty hit set.
///
/// This class only ever searches its own origin and never claims URLs
/// (`canHandle` is false): URL resolution stays with the universal import
/// adapter, and a real plugin for the same host would take precedence in
/// every flow (plugins resolve first).
class UniversalOriginSearchSource implements SearchableSource {
  UniversalOriginSearchSource({
    /// The origin key, as stored in the rule store (`https://host/`).
    required String origin,
    /// The HTML fetcher — normally a WebViewTransport tear-off so
    /// challenge-protected search pages resolve.
    required Future<String> Function(Uri, {Map<String, String>? headers})
        transport,
    required Future<UniversalOriginRule?> Function(String origin) loadRule,
    required Future<void> Function(String origin, UniversalOriginRule rule)
        saveRule,
    this.searchTimeout = const Duration(seconds: 20),
    @visibleForTesting Future<void> Function(Duration)? sleep,
  })  : _origin = origin.endsWith('/') ? origin : '$origin/',
        fetchHtml = transport,
        _loadRule = loadRule,
        _saveRule = saveRule,
        _sleep = sleep ?? Future<void>.delayed;

  final Future<String> Function(Uri, {Map<String, String>? headers}) fetchHtml;
  final Future<UniversalOriginRule?> Function(String origin) _loadRule;
  final Future<void> Function(String origin, UniversalOriginRule rule)
      _saveRule;
  final Duration searchTimeout;
  final Future<void> Function(Duration) _sleep;

  final String _origin;

  /// Origins already registered in the source registry — a guard so any
  /// re-registration pass (rule reload, provider refresh) never duplicates
  /// a site row in the directory.
  static final Set<String> registeredOrigins = <String>{};

  Uri get _originBase => Uri.parse(_origin);

  @override
  String get sourceName => _originBase.host;

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  /// Search-only view: never claims URLs for the resolve-chain.
  @override
  bool canHandle(Uri uri) => false;

  // Import methods are unreachable in practice — URL resolution goes
  // through the universal import adapter (or a real plugin, which wins on
  // a shared host). They exist only to satisfy the [SourceAdapter]
  // contract the searchable interface inherits.
  @override
  Future<NovelModel> getMetadata(Uri uri) async => throw const ImportException(
        'Search views cannot import directly; open the link instead.',
      );

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async =>
      throw const ImportException(
        'Search views cannot import directly; open the link instead.',
      );

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async =>
      throw const ImportException(
        'Search views cannot import directly; open the link instead.',
      );

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async {
    final term = query.term.trim();
    if (term.isEmpty) return const SourceSearchResponse(results: []);

    final rule = await _loadRule(_origin);
    final knownTemplate = rule?.searchTemplate;

    if (knownTemplate != null) {
      final outcome = await _searchWithTemplate(knownTemplate, term);
      if (outcome != null) return outcome;
      // The learned template stopped yielding links — re-probe below.
    }

    // Probe every remaining template in order. A candidate qualifies when
    // it yields ≥2 plausible book links (a lone link is indistinguishable
    // from stray navigation); the winner is learned for next time.
    final candidates = SitePatternZoo.searchUrlTemplates
        .where((t) => t != knownTemplate)
        .toList();
    for (final template in candidates) {
      final hits = await _hitsFor(_buildSearchUrl(template, term));
      if (hits != null && hits.length >= 2) {
        final learned = (rule ??
                UniversalOriginRule(updatedAt: DateTime.now().toUtc()))
            .copyWith(searchTemplate: template);
        await _saveRule(_origin, learned);
        return _response(hits);
      }
      await _sleep(const Duration(milliseconds: 250));
    }

    throw const ImportException(
      "This site's search could not be detected.",
    );
  }

  // ------------------------------------------------------------- internals

  /// A search against a trusted template. Returns null only when the
  /// template broke; a real "no results" page is a legitimate empty
  /// response, and any hit counts.
  Future<SourceSearchResponse?> _searchWithTemplate(
    String template,
    String term,
  ) async {
    final doc = await _parse(_buildSearchUrl(template, term));
    if (doc == null) return null;
    if (SitePatternZoo.looksLikeNoResultsPage(doc)) {
      return const SourceSearchResponse(results: []);
    }
    final hits = SitePatternZoo.detectSearchResults(doc, _originBase);
    return hits.isEmpty ? null : _response(hits);
  }

  /// One probe fetch. Returns the detected hits, or null when the page
  /// proclaimed "no results" / the fetch failed / nothing plausible was
  /// extracted.
  Future<List<SearchResultHit>?> _hitsFor(
    Uri url,
  ) async {
    final doc = await _parse(url);
    if (doc == null) return null;
    if (SitePatternZoo.looksLikeNoResultsPage(doc)) return null;
    final hits = SitePatternZoo.detectSearchResults(doc, _originBase);
    return hits.isEmpty ? null : hits;
  }

  Uri _buildSearchUrl(String template, String term) {
    final encoded = Uri.encodeQueryComponent(term);
    final path = template
        .replaceFirst('{query}', encoded)
        .replaceFirst('{page}', '1');
    return _originBase.resolve(path);
  }

  SourceSearchResponse _response(List<SearchResultHit> hits) =>
      SourceSearchResponse(
        results: [
          for (final hit in hits)
            SourceSearchResult(
              id: hit.uri.toString(),
              title: hit.title,
              importUrl: hit.uri.toString(),
              coverUrl: hit.coverUrl,
            ),
        ],
      );

  /// Fetch + parse; any failure (timeout, network, challenge) is null from
  /// the probe's point of view — template failed, keep probing.
  Future<Document?> _parse(Uri url) async {
    String html;
    try {
      html = await fetchHtml(url).timeout(
        searchTimeout,
        onTimeout: () => throw const ImportException('Timed out.'),
      );
    } on Object {
      return null;
    }
    return html_parser.parse(html);
  }
}
