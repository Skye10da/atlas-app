import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart'
    show ImportException;
import 'package:atlas_app/core/content_engine/universal/origin_rules.dart';
import 'package:atlas_app/core/content_engine/universal/site_pattern_zoo.dart';

/// A last-resort source adapter that imports novels from sites WITHOUT a
/// dedicated plugin, by detecting the page structure with the universal
/// [SitePatternZoo] heuristics (JSON-LD / Open Graph / common class
/// conventions / semantic text analysis).
///
/// It is registered strictly AFTER every plugin in the source registry, so it
/// can never shadow a supported site — `SourceRegistry.resolve` is
/// first-match and plugins are registered during discovery.
///
/// Imports are permissive but gated: a page qualifies when the zoo finds a
/// plausible title AND either chapter-like links (≥2) or story body
/// paragraphs (≥3). When it qualifies, the visitor sees the standard confirm
/// sheet with the detected fields and explicitly continues ("best guess").
/// Pages that do NOT qualify keep failing with a quiet "no novel structure"
/// error — never an error dump.
///
/// Phase 1 scope (deliberate simplifications):
///    Chapter lists follow "next"-style pagination, bounded.
///  * Chapter content uses the zoo container heuristics, plus learned
///    per-origin rules ([UniversalOriginRule]) that are consulted first
///    and re-learned on every success, so repeat visits from the same
///    site skip the heuristics.
///  * Per-origin plugin synthesis / teaching / LLM backstop are later phases.
class UniversalHtmlSource implements SourceAdapter {
  UniversalHtmlSource({
    /// The HTML fetcher, normally a `WebViewTransport.fetchHtml` tear-off so
    /// challenge-protected pages resolve instead of failing (the constructor
    /// parameter name keeps the transport provenance explicit).
    required Future<String> Function(Uri, {Map<String, String>? headers})
        transport,
    this.listFetchTimeout = const Duration(seconds: 30),
    this.contentFetchTimeout = const Duration(seconds: 45),
    this.maxListPages = 12,
    this.pageDelay = const Duration(milliseconds: 400),
    this.loadRule,
    this.saveRule,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  })  : fetchHtml = transport,
        _sleep = sleep ?? Future<void>.delayed;

  final Future<String> Function(Uri, {Map<String, String>? headers}) fetchHtml;
  final Duration listFetchTimeout;
  final Duration contentFetchTimeout;

  /// Upper bound on chapter-list pagination pages fetched per import.
  final int maxListPages;
  final Duration pageDelay;
  final Future<void> Function(Duration) _sleep;

  /// Loads the learned rule for a URL origin, when persistence is wired up.
  /// Null hooks (tests / unwired runs) simply skip learning.
  final Future<UniversalOriginRule?> Function(String origin)? loadRule;
  final Future<void> Function(String origin, UniversalOriginRule rule)?
      saveRule;

  /// Listed as "Universal" in the UI so the import sheet can hint that the
  /// page was auto-detected rather than served by a named site plugin.
  @override
  String get sourceName => 'Universal';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  /// Claims any browsable web page that no other adapter claimed (files like
  /// .txt/.md/.epub/.pdf/.atlas/.md are handled by the earlier adapters).
  @override
  bool canHandle(Uri uri) {
    if (!uri.isScheme('https') && !uri.isScheme('http')) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    final path = uri.path.toLowerCase();
    const fileExtensions = ['.pdf', '.epub', '.atlas', '.txt', '.md',
        '.jpg', '.jpeg', '.png', '.gif', '.webp', '.zip', '.rar'];
    for (final ext in fileExtensions) {
      if (path.endsWith(ext)) return false;
    }
    return true;
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final doc = await _parse(uri, timeout: listFetchTimeout);
    final origin = UniversalOriginRuleStore.originOf(uri);

    final rule = await _loadRule(origin);
    final titleHit = SitePatternZoo.detectTitleAttributed(
      doc,
      preferredSource: rule?.titleSource,
    );
    final title = titleHit.$1;
    final contentHit = SitePatternZoo.detectContentAttributed(
      doc,
      preferredSelector: rule?.contentSelector,
    );
    final chapterLinks = SitePatternZoo.detectChapterLinks(doc, uri);

    // Gate: a page qualifies when we found a title AND (chapter links OR
    // readable story body). Under that threshold the URL stays "unsupported"
    // with the regular quiet error — no half-imports of random pages.
    final qualifies = title != null &&
        (chapterLinks.length >= 2 || contentHit.paragraphs.length >= 3);
    if (!qualifies) {
      throw const ImportException(
        'No novel structure could be detected at this URL.',
      );
    }

    // Learning (Phase 2): remember which zoo sources won for this origin so
    // later visits skip the guessing. Fire-and-forget; failures are logged,
    // never propagated.
    _remember(
      origin,
      UniversalOriginRule(
        updatedAt: DateTime.now().toUtc(),
        titleSource: titleHit.$2,
        contentSelector: contentHit.selector ?? rule?.contentSelector,
      ),
    );

    final NovelModel novel = NovelModel(
      sourceId: uri.toString(),
      title: title,
      author: SitePatternZoo.detectAuthor(doc),
      description: SitePatternZoo.detectDescription(doc),
      coverUrl: SitePatternZoo.detectCoverUrl(doc, uri),
      genres: SitePatternZoo.detectGenres(doc),
      source: sourceName,
      sourceUrl: uri.toString(),
      category: contentCategory,
      chapterCount: chapterLinks.length >= 2 ? chapterLinks.length : 1,
    );
    return novel;
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    var baseUrl = Uri.parse(novel.sourceUrl);
    var doc = await _parse(baseUrl, timeout: listFetchTimeout);

    var links = SitePatternZoo.detectChapterLinks(doc, baseUrl);

    var pagesFetched = 0;
    while (links.isNotEmpty && pagesFetched < maxListPages) {
      final next = SitePatternZoo.detectNextPage(doc, baseUrl);
      if (next == null) break;
      final nextDoc = await _parse(next, timeout: listFetchTimeout);
      final merged = SitePatternZoo.detectChapterLinks(nextDoc, next);
      if (merged.isEmpty) break;
      links = [...links, ...merged];
      baseUrl = next;
      doc = nextDoc;
      pagesFetched++;
      await _sleep(pageDelay);
    }

    final seen = <String>{};
    final chapters = <ChapterModel>[];
    for (final link in links) {
      if (!seen.add(link.uri.toString())) continue;
      chapters.add(
        ChapterModel(
          id: '${novel.sourceId}_u${chapters.length}',
          title: link.title,
          index: chapters.length,
          contentUrl: link.uri.toString(),
        ),
      );
    }
    if (chapters.isNotEmpty) return chapters;

    // No chapter links at all: either the list is JS-rendered (WebView
    // transport already handled the challenge level) or the page content IS
    // the book (article / single-pager). Import the page as one chapter —
    // matching the Direct URL source's single-file behavior.
    return [
      ChapterModel(
        id: '${novel.sourceId}_u0',
        title: novel.title,
        index: 0,
        contentUrl: novel.sourceUrl,
      ),
    ];
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;
    final contentUrl = chapter.contentUrl;
    if (contentUrl == null) {
      throw ImportException('Chapter ${chapter.id} has no content URL.');
    }
    final pageUri = Uri.parse(contentUrl);
    final doc = await _parse(pageUri, timeout: contentFetchTimeout);
    final origin = UniversalOriginRuleStore.originOf(pageUri);

    final rule = await _loadRule(origin);
    final contentHit = SitePatternZoo.detectContentAttributed(
      doc,
      preferredSelector: rule?.contentSelector,
    );
    if (contentHit.paragraphs.isEmpty) {
      throw ImportException(
        'Chapter content could not be extracted: ${chapter.title}',
      );
    }

    // Re-learn when the winning container differs from the stored one
    // (first visit at this origin, or the site changed and the fallback
    // recovered).
    if (contentHit.selector != null && contentHit.selector != rule?.contentSelector) {
      _remember(
        origin,
        (rule ?? UniversalOriginRule(updatedAt: _epoch)).copyWith(
          contentSelector: contentHit.selector,
        ),
      );
    }

    final body = contentHit.paragraphs.join('\n\n');
    final pageTitle =
        SitePatternZoo.detectChapterPageTitle(doc) ?? chapter.title;

    return ChapterModel(
      id: chapter.id,
      title: pageTitle,
      index: chapter.index,
      contentUrl: contentUrl,
      content: body,
      wordCount: body.split(RegExp(r'\s+')).length,
    );
  }

  // ------------------------------------------------------------- internals

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Future<UniversalOriginRule?> _loadRule(String origin) async {
    final loader = loadRule;
    if (loader == null) return null;
    try {
      return await loader(origin);
    } on Object {
      // Rules are advisory; a failing store must never break an import.
      return null;
    }
  }

  void _remember(String origin, UniversalOriginRule rule) {
    final saver = saveRule;
    if (saver == null) return;
    unawaited(() async {
      try {
        await saver(origin, rule);
      } on Object {
        // Persistence failures are deliberately swallowed: the in-session
        // copy already applies to this import, and the next import simply
        // re-learns.
      }
    }());
  }

  Future<Document> _parse(Uri uri, {required Duration timeout}) async {
    String html;
    try {
      html = await fetchHtml(uri).timeout(
        timeout,
        onTimeout: () =>
            throw const ImportException('Timed out reaching this page.'),
      );
    } on ImportException {
      rethrow;
    } on Object catch (e) {
      throw ImportException('Could not reach ${uri.host}: $e');
    }
    return html_parser.parse(html);
  }
}
