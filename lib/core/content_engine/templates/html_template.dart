import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/parser/dom_parser.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/content_pipeline.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';

/// Generic CSS-selector-driven template: applies `selectors.json` directly
/// against fetched HTML. Default fallback for any site whose markup is
/// regular enough not to need bespoke logic. Subclassing templates reuse
/// [parser] and [pipeline] for the shared fetch → clean → normalize tail.
///
/// Beyond the plain WordPress convention, `selectors.json` can drive a custom
/// search endpoint (`search.path` + `search.queryParam`) and a paginated
/// chapter index (`chapterList.pageParam` + `chapterList.maxPages`), so most
/// server-rendered sites stay data-only.
class HtmlTemplate implements Template {
  const HtmlTemplate();

  static const parser = DomParser();
  static const pipeline = ContentPipeline();

  /// Upper bound on index pages walked, so a malformed `maxPages` can't turn
  /// a pagination config into an unbounded request loop.
  static const _maxPages = 200;

  @override
  String get templateId => 'html';

  @override
  Set<PluginCapability> get supportedCapabilities =>
      PluginCapability.values.toSet();

  @override
  Future<List<SearchResult>> search(
    PluginContext context,
    String query,
  ) async {
    final selectors = context.selectors;
    if (selectors == null || selectors.search == null) {
      throw const PluginCapabilityException(
        PluginCapability.search,
        'No search selectors configured for this plugin',
      );
    }
    final uri = _searchUri(context.plugin.baseUrl, query, selectors.search!);
    final html =
        await context.transport.fetchHtml(uri, headers: context.plugin.requestHeaders);
    final doc = parser.parse(html);
    return selectors.applySearch(doc, baseUrl: context.plugin.baseUrl);
  }

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) async {
    final selectors = context.selectors;
    if (selectors == null || selectors.chapterList == null) {
      throw const PluginCapabilityException(
        PluginCapability.chapterList,
        'No chapter-list selectors configured for this plugin',
      );
    }
    final chapterList = selectors.chapterList!;
    final base = Uri.parse(context.plugin.baseUrl);
    final seen = <String>{};
    var refs = <ChapterRef>[];
    final maxPages = chapterList.maxPages.clamp(1, _maxPages).toInt();

    for (var page = 1; page <= maxPages; page++) {
      final uri = page <= 1
          ? Uri.parse(novelUrl)
          : Uri.parse(novelUrl).replace(queryParameters: {
              chapterList.pageParam: '$page',
            });
      final html =
          await context.transport.fetchHtml(uri, headers: context.plugin.requestHeaders);
      final before = refs.length;
      for (final ref in selectors.applyChapterList(parser.parse(html))) {
        final url = base.resolve(ref.url).toString();
        if (!seen.add(url)) continue;
        refs.add(ChapterRef(
          title: ref.title,
          url: url,
          publishedAt: ref.publishedAt,
        ));
      }
      // Sites that clamp out-of-range pages to the last page would otherwise
      // repeat it for every remaining request; a page that adds nothing new
      // means the list is exhausted.
      if (refs.length == before) break;
    }

    if (chapterList.reverse) refs = refs.reversed.toList();
    return refs;
  }

  @override
  Future<AtlasDocument> chapterContent(
    PluginContext context,
    String chapterUrl,
  ) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(chapterUrl),
      headers: context.plugin.requestHeaders,
    );
    final doc = parser.parse(html);
    final selectors = context.selectors;
    final contentSelectors = selectors?.chapterContent;
    final root = selectors != null && contentSelectors != null
        ? selectors.applyContentContainer(doc)
        : doc.body;
    String? title;
    final titleSelector = contentSelectors?.title;
    if (titleSelector != null && titleSelector.isNotEmpty) {
      title = doc.querySelector(titleSelector)?.text.trim();
    }
    if (root == null) {
      return AtlasDocument(
        title: title ?? '',
        metadata: DocumentMetadata(
          sourceUrl: chapterUrl,
          sourceName: context.plugin.sourceName,
        ),
      );
    }
    return pipeline.run(
      root,
      title: title,
      metadata: DocumentMetadata(
        sourceUrl: chapterUrl,
        sourceName: context.plugin.sourceName,
      ),
      filters: context.filters,
    );
  }

  @override
  Future<NovelMetadata> metadata(
    PluginContext context,
    String novelUrl,
  ) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: context.plugin.requestHeaders,
    );
    return _extractMetadata(parser.parse(html), context);
  }

  NovelMetadata _extractMetadata(Document doc, PluginContext context) {
    String? meta(String selector) =>
        doc.querySelector(selector)?.attributes['content']?.trim();

    final title = meta('meta[property="og:title"]') ??
        doc.querySelector('title')?.text.trim() ??
        'Untitled';
    final coverUrl =
        meta('meta[property="og:image"]') ?? meta('meta[name="twitter:image"]');
    final description =
        meta('meta[name="description"]') ?? meta('meta[property="og:description"]');

    return NovelMetadata(
      title: title,
      coverUrl: coverUrl,
      description: description,
      language: context.plugin.language,
    );
  }

  /// Site search endpoint. Defaults to the WordPress convention (`?s=query` on
  /// the bare base URL); plugins can point elsewhere via `search.path` +
  /// `search.queryParam` in their selectors.
  Uri _searchUri(String baseUrl, String query, SearchSelectors search) {
    final path = search.path;
    if (path == null || path.isEmpty) {
      return Uri.parse(baseUrl).replace(queryParameters: {'s': query});
    }
    return Uri.parse(baseUrl).replace(
          path: path.startsWith('/') ? path : '/$path',
          queryParameters: {search.queryParam: query},
        );
  }
}
