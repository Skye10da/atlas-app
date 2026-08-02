import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/parser/dom_parser.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/content_pipeline.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';

/// Generic CSS-selector-driven template: applies `selectors.json` directly
/// against fetched HTML. Default fallback for any site whose markup is
/// regular enough not to need bespoke logic. Subclassing templates reuse
/// [parser] and [pipeline] for the shared fetch → clean → normalize tail.
class HtmlTemplate implements Template {
  const HtmlTemplate();

  static const parser = DomParser();
  static const pipeline = ContentPipeline();

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
    final uri = _searchUri(context.plugin.baseUrl, query);
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
    final html = await context.transport
        .fetchHtml(Uri.parse(novelUrl), headers: context.plugin.requestHeaders);
    final doc = parser.parse(html);
    return selectors.applyChapterList(doc);
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

  /// WordPress-convention site search (`?s=query`). A plugin needing a custom
  /// search endpoint would use a site-specific template instead.
  Uri _searchUri(String baseUrl, String query) =>
      Uri.parse(baseUrl).replace(queryParameters: {'s': query});
}
