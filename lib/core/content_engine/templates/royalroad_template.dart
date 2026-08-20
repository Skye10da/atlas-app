import 'dart:convert';

import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';

/// Template for Royal Road (www.royalroad.com).
///
/// Royal Road's chapter index is a paginated server-rendered table whose full
/// contents are also mirrored in a `window.chapters` JSON array on the fiction
/// page — the one place the generic [HtmlTemplate]'s CSS-selector model can't
/// reach (it has no expression for "parse this inline JSON"), so this
/// subclass handles it in code and keeps everything else data-driven:
///
///  * `chapterList` prefers the `window.chapters` array (complete, with real
///    publish dates and sort order), falling back to the `table#chapters` rows,
///  * `metadata` reads the `application/ld+json` Book schema (title, synopsis,
///    author, rating, dates) and overlays DOM-only fields (cover, genres,
///    status, chapter count),
///  * `chapterContent` additionally strips elements hidden by the site's
///    anti-copy CSS (`display: none` rules inline in `<style>`).
///
/// Search and the clean/normalize tail are inherited from [HtmlTemplate],
/// driven by the plugin's `selectors.json` (`/fictions/search?title=`).
class RoyalRoadTemplate extends HtmlTemplate {
  const RoyalRoadTemplate();

  @override
  String get templateId => 'royalroad';

  @override
  Set<PluginCapability> get supportedCapabilities =>
      PluginCapability.values.toSet();

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: context.plugin.requestHeaders,
    );
    final doc = HtmlTemplate.parser.parse(html);
    return _chaptersFromScript(html, context.plugin.baseUrl) ??
        _chaptersFromRows(doc, context.plugin.baseUrl);
  }

  /// Full chapter list from the `window.chapters = [...]` script on the
  /// fiction page. Returns null when the array is absent or unparseable so the
  /// caller can fall back to the DOM table.
  List<ChapterRef>? _chaptersFromScript(String html, String baseUrl) {
    final match = RegExp(
      r'window\.chapters\s*=\s*(\[[\s\S]*?\]);\s*window\.volumes',
    ).firstMatch(html);
    if (match == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(match.group(1)!);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;

    final base = Uri.parse(baseUrl);
    final entries = <(int, ChapterRef)>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final visible = raw['visible'];
      if (visible is num && visible == 0) continue;
      final title = raw['title'];
      final url = raw['url'];
      if (title is! String || title.isEmpty || url is! String || url.isEmpty) {
        continue;
      }
      final order = raw['order'];
      final date = raw['date'];
      entries.add((
        order is num ? order.toInt() : entries.length,
        ChapterRef(
          title: title,
          url: base.resolve(url).toString(),
          publishedAt: date is String ? DateTime.tryParse(date) : null,
        ),
      ));
    }
    if (entries.isEmpty) return null;
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return entries.map((e) => e.$2).toList();
  }

  /// Fallback: the server-rendered `table#chapters` rows (the visible window
  /// of the paginated index, typically the last 100-odd chapters).
  List<ChapterRef> _chaptersFromRows(Document doc, String baseUrl) {
    final base = Uri.parse(baseUrl);
    final refs = <ChapterRef>[];
    for (final row in doc.querySelectorAll('table#chapters tr.chapter-row')) {
      final url = row.attributes['data-url'];
      final title = row.querySelector('a')?.text.trim();
      if (url == null || title == null || title.isEmpty) continue;
      refs.add(ChapterRef(title: title, url: base.resolve(url).toString()));
    }
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
    final doc = HtmlTemplate.parser.parse(html);
    final selectors = context.selectors;
    final root = selectors != null
        ? selectors.applyContentContainer(doc)
        : doc.body;
    if (root != null) _stripCssHiddenElements(doc, root);

    String? title;
    final titleSelector = selectors?.chapterContent?.title;
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
    return HtmlTemplate.pipeline.run(
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
  Future<NovelMetadata> metadata(PluginContext context, String novelUrl) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: context.plugin.requestHeaders,
    );
    final doc = HtmlTemplate.parser.parse(html);
    return _extractMetadata(doc, html, context);
  }

  NovelMetadata _extractMetadata(
    Document doc,
    String html,
    PluginContext context,
  ) {
    final schema = _ldJsonBook(doc);
    String? schemaString(String key) {
      final value = schema?[key];
      return value is String ? value : null;
    }

    final title =
        schemaString('name') ??
        doc.querySelector('.fic-title h1.font-white')?.text.trim() ??
        'Untitled';
    final author = _schemaPersonName(schema?['author']);

    final rating = _schemaRating(schema?['aggregateRating']);
    final lastUpdated = DateTime.tryParse(schemaString('dateModified') ?? '');

    final chapterCount = _chapterCount(doc, html);
    final description =
        _htmlToText(schemaString('description')) ??
        doc
            .querySelector('meta[name="description"]')
            ?.attributes['content']
            ?.trim();

    return NovelMetadata(
      title: title,
      author: author,
      description: description,
      coverUrl: doc
          .querySelector('.cover-art-container img')
          ?.attributes['src']
          ?.trim(),
      language: context.plugin.language,
      chapterCount: chapterCount,
      genres: doc
          .querySelectorAll('.fiction-tag')
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      status: _status(doc),
      rating: rating,
      lastUpdated: lastUpdated,
    );
  }

  Map<String, Object?>? _ldJsonBook(Document doc) {
    final script = doc.querySelector('script[type="application/ld+json"]');
    if (script == null) return null;
    try {
      final decoded = jsonDecode(script.text);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  String? _schemaPersonName(Object? person) {
    if (person is String && person.isNotEmpty) return person;
    if (person is Map) {
      final name = person['name'];
      return name is String && name.isNotEmpty ? name : null;
    }
    return null;
  }

  double? _schemaRating(Object? rating) {
    if (rating is! Map) return null;
    final value = rating['ratingValue'];
    return value is num ? value.toDouble() : null;
  }

  /// Chapter count from the `data-chapters` attribute on `table#chapters`, or
  /// from the length of `window.chapters` when the attribute is missing.
  int _chapterCount(Document doc, String html) {
    final attr = doc
        .querySelector('table#chapters')
        ?.attributes['data-chapters'];
    final fromAttr = attr != null ? int.tryParse(attr) : null;
    if (fromAttr != null) return fromAttr;
    final script = RegExp(
      r'window\.chapters\s*=\s*(\[[\s\S]*?\]);\s*window\.volumes',
    ).firstMatch(html);
    if (script == null) return 0;
    try {
      final decoded = jsonDecode(script.group(1)!);
      return decoded is List ? decoded.length : 0;
    } on FormatException {
      return 0;
    }
  }

  /// Royal Road renders the fiction status as a `label-sm` pill whose text is
  /// one of ONGOING / COMPLETED / HIATUS (adjacent to the "Original" pill).
  String? _status(Document doc) {
    final status = RegExp(r'^(?:ONGOING|COMPLETED|HIATUS)\s*$');
    for (final label in doc.querySelectorAll('span.label-sm, span.label')) {
      final text = label.text.trim().toUpperCase();
      if (status.hasMatch(text)) return label.text.trim();
    }
    return null;
  }

  /// Removes elements hidden by the site's inline anti-copy CSS, e.g.
  /// `.cjA5ZjgxNWViMDY5NTRhMjliNzYyYmI3YzJkODFhYzBh{ display: none; }`. The DOM
  /// parser has no layout engine, so otherwise those "hidden" paragraphs leak
  /// into the rendered text.
  void _stripCssHiddenElements(Document doc, Element root) {
    final hiddenClass = RegExp(r'\.([a-zA-Z0-9_-]+)\s*\{[^}]*display:\s*none');
    final classes = <String>{};
    for (final style in doc.querySelectorAll('style')) {
      for (final match in hiddenClass.allMatches(style.text)) {
        classes.add(match.group(1)!);
      }
    }
    for (final className in classes) {
      for (final el in root.querySelectorAll('.$className')) {
        el.remove();
      }
    }
  }

  /// Strips tags/entities from an HTML fragment (the ld+json `description`
  /// field is HTML-encoded) down to plain text.
  String? _htmlToText(String? html) {
    if (html == null || html.isEmpty) return null;
    final doc = HtmlTemplate.parser.parse(html);
    final text = doc.body?.text.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
