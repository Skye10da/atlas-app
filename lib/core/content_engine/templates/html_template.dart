import 'dart:convert';
import 'dart:math' as math;

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
/// Beyond the plain WordPress convention, `selectors.json` can drive:
///
///  * a custom search endpoint (`search.path` + `search.queryParam`) with extra
///    fixed query params (`search.extraQueryParams`),
///  * a paginated chapter index (`chapterList.pageParam` + `chapterList.maxPages`,
///    plus `paginationSelector`/`totalPagesSelector` to detect the page count),
///  * a single-request chapter archive keyed by a novel id
///    (`chapterList.ajaxPath` + `chapterList.ajaxArchive`),
///  * a data-driven novel metadata section (`metadata`) overriding the og: tag
///    defaults,
///  * `|`-separated fallback selector specs on any selector value.
///
/// So most server-rendered sites stay data-only.
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

    var refs = await _fetchAjaxArchive(context, selectors, chapterList, base, novelUrl)
        ?? await _walkChapterPages(context, selectors, chapterList, base, novelUrl);

    if (chapterList.sortByChapterNumber) refs = _sortByChapterNumber(refs);
    if (chapterList.reverse) refs = refs.reversed.toList();
    return refs;
  }

  /// Pulls the complete chapter list from `chapterList.ajaxPath` when
  /// configured. `GET` archives resolve the path against the plugin base URL
  /// and key on `?novelId=<id>`; `POST` archives (Madara/WordPress-manga) send
  /// a form body whose `{novelId}` placeholder is filled from the novel page,
  /// resolving the path against the base URL or the novel page per
  /// `ajaxArchive.ajaxBase`. Returns null when the archive isn't configured,
  /// the novel id is missing, the request fails, or nothing usable is parsed —
  /// so the caller falls back to walking the paginated index.
  Future<List<ChapterRef>?> _fetchAjaxArchive(
    PluginContext context,
    SelectorSet selectors,
    ChapterListSelectors chapterList,
    Uri base,
    String novelUrl,
  ) async {
    final ajaxPath = chapterList.ajaxPath;
    if (ajaxPath == null || ajaxPath.isEmpty) return null;
    final archive = chapterList.ajaxArchive;
    final headers = context.plugin.requestHeaders;

    final novelHtml = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: headers,
    );
    final novelId = selectors.extract(
      parser.parse(novelHtml).documentElement!,
      archive?.novelIdSelector ?? '[data-novel-id]@data-novel-id',
    );
    if (novelId == null || novelId.isEmpty) return null;

    final path = ajaxPath.startsWith('/') ? ajaxPath : '/$ajaxPath';
    final isPost = (archive?.method ?? 'GET') == 'POST';
    final String html;
    try {
      if (isPost) {
        final form = {
          for (final entry in (archive?.form ?? const {}).entries)
            entry.key: entry.value.replaceAll('{novelId}', novelId),
        };
        final target = (archive?.ajaxBase == 'novel')
            ? Uri.parse(novelUrl)
                .replace(path: _appendPath(Uri.parse(novelUrl).path, path))
            : base.replace(path: _appendPath(base.path, path));
        html =
            await context.transport.fetchHtmlPost(target, headers: headers, form: form);
      } else {
        final uri = base.replace(
          path: _appendPath(base.path, path),
          queryParameters: {'novelId': novelId},
        );
        html = await context.transport.fetchHtml(uri, headers: headers);
      }
    } on Object {
      return null;
    }


    final refs = <ChapterRef>[];
    final seen = <String>{};
    final itemSelector = archive?.item ?? chapterList.item;
    final titleSpec = archive?.title ?? chapterList.title;
    final urlSpec = archive?.url ?? chapterList.url;
    for (final item in parser.parse(_archiveHtml(html, archive?.responseField))
        .querySelectorAll(itemSelector)) {
      final title = selectors.extract(item, titleSpec);
      final rawUrl = selectors.extract(item, urlSpec);
      if (title == null || title.isEmpty || rawUrl == null || rawUrl.isEmpty) {
        continue;
      }
      final url = base.resolve(rawUrl).toString();
      if (!seen.add(url)) continue;
      refs.add(ChapterRef(title: title, url: url));
    }
    return refs.isEmpty ? null : refs;
  }

  /// Unwraps an archive response: plain HTML passes through; a JSON response
  /// configured with [AjaxArchiveSelectors.responseField] (e.g. `data.content`)
  /// has that dotted path extracted. Falls back to the raw body when the field
  /// can't be resolved so the caller degrades to the paginated walk.
  String _archiveHtml(String raw, String? responseField) {
    if (responseField == null || responseField.isEmpty) return raw;
    try {
      Object? node = jsonDecode(raw);
      for (final part in responseField.split('.')) {
        if (node is Map) {
          node = node[part];
        } else {
          return raw;
        }
      }
      return node is String ? node : raw;
    } on Object {
      return raw;
    }
  }

  /// Appends [child] (normalized with a leading slash) onto [dir], so a
  /// novel-relative ajax endpoint keeps the permalink prefix: a novel at
  /// `/novel/slug` with path `/ajax/chapters` resolves to
  /// `/novel/slug/ajax/chapters` rather than the site root.
  String _appendPath(String dir, String child) {
    final d = dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
    return '$d$child';
  }

  /// Walks the paginated chapter index (`?pageParam=N`) from page 1, stopping
  /// once a page adds nothing new. The page count is the configured [maxPages]
  /// raised to the largest `?page=N` found in `paginationSelector` (links /
  /// `option[data-url]`) or the `data-total-page` attribute declared by
  /// `totalPagesSelector`.
  Future<List<ChapterRef>> _walkChapterPages(
    PluginContext context,
    SelectorSet selectors,
    ChapterListSelectors chapterList,
    Uri base,
    String novelUrl,
  ) async {
    final seen = <String>{};
    final refs = <ChapterRef>[];
    final headers = context.plugin.requestHeaders;

    final first = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: headers,
    );
    _collectChapterRefs(selectors, parser.parse(first), base, seen, refs);
    final maxPages = _maxPagesOf(parser.parse(first), chapterList)
        .clamp(1, _maxPages)
        .toInt();

    for (var page = 2; page <= maxPages; page++) {
      final uri = Uri.parse(novelUrl)
          .replace(queryParameters: {chapterList.pageParam: '$page'});
      final html = await context.transport.fetchHtml(uri, headers: headers);
      final before = refs.length;
      _collectChapterRefs(selectors, parser.parse(html), base, seen, refs);
      // Sites that clamp out-of-range pages to the last page would otherwise
      // repeat it for every remaining request; a page that adds nothing new
      // means the list is exhausted.
      if (refs.length == before) break;
    }
    return refs;
  }

  void _collectChapterRefs(
    SelectorSet selectors,
    Document doc,
    Uri base,
    Set<String> seen,
    List<ChapterRef> refs,
  ) {
    for (final ref in selectors.applyChapterList(doc)) {
      final url = base.resolve(ref.url).toString();
      if (!seen.add(url)) continue;
      refs.add(ChapterRef(
        title: ref.title,
        url: url,
        publishedAt: ref.publishedAt,
      ));
    }
  }

  /// Upper bound on the pages to walk, derived from the first index page: the
  /// configured [ChapterListSelectors.maxPages], raised by the largest
  /// `?page=N` referenced in the pagination bar and by any `data-total-page`
  /// declared on `totalPagesSelector`.
  int _maxPagesOf(Document doc, ChapterListSelectors chapterList) {
    var max = chapterList.maxPages;
    final pattern = RegExp('[?&]${chapterList.pageParam}=(\\d+)');
    int scan(Element container) {
      var pages = 0;
      for (final el in container.querySelectorAll('a[href]')) {
        pages = math.max(pages, _pageNumber(el.attributes['href'] ?? '', pattern));
      }
      for (final el in container.querySelectorAll('option[data-url]')) {
        pages =
            math.max(pages, _pageNumber(el.attributes['data-url'] ?? '', pattern));
      }
      return pages;
    }

    final paginationSelector = chapterList.paginationSelector;
    if (paginationSelector != null && paginationSelector.isNotEmpty) {
      for (final bar in doc.querySelectorAll(paginationSelector)) {
        max = math.max(max, scan(bar));
      }
    }
    final totalPagesSelector = chapterList.totalPagesSelector;
    if (totalPagesSelector != null && totalPagesSelector.isNotEmpty) {
      final total = int.tryParse(
        doc.querySelector(totalPagesSelector)?.attributes['data-total-page'] ?? '',
      );
      if (total != null) max = math.max(max, total);
    }
    return max;
  }

  int _pageNumber(String raw, RegExp pattern) {
    final match = pattern.firstMatch(raw);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  /// Sorts by the chapter number embedded in `/chapter-<N>-...` URLs, keeping
  /// unnumbered entries in their source order behind numbered ones.
  List<ChapterRef> _sortByChapterNumber(List<ChapterRef> refs) {
    final indexed = <(int?, int, ChapterRef)>[];
    for (var i = 0; i < refs.length; i++) {
      indexed.add((_chapterNumber(refs[i].url), i, refs[i]));
    }
    indexed.sort((a, b) {
      final an = a.$1;
      final bn = b.$1;
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.$2.compareTo(b.$2);
    });
    return [for (final e in indexed) e.$3];
  }

  int? _chapterNumber(String url) {
    final path = Uri.parse(url).path;
    final match = RegExp(r'/chapter-(\d+)').firstMatch(path);
    return match != null ? int.tryParse(match.group(1)!) : null;
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
    final selectors = context.selectors;
    final metadata = selectors?.metadata;

    String? metaTag(String key) =>
        doc.querySelector('meta[property="$key"]')?.attributes['content']?.trim() ??
        doc.querySelector('meta[name="$key"]')?.attributes['content']?.trim();

    final title = _firstNonEmpty(
      _fieldValue(doc, metadata?.title, selectors),
      metaTag('og:title'),
      doc.querySelector('title')?.text.trim(),
    ) ?? 'Untitled';

    final author = _firstNonEmpty(
      _fieldValue(doc, metadata?.author, selectors),
      metaTag('og:novel:author'),
    );

    final description = _firstNonEmpty(
      _fieldValue(doc, metadata?.description, selectors),
      metaTag('description'),
      metaTag('og:description'),
    );

    final coverUrl = _resolveCoverUrl(
      _firstNonEmpty(
        _fieldValue(doc, metadata?.coverUrl, selectors),
        metaTag('og:image'),
        metaTag('twitter:image'),
      ),
      context.plugin.baseUrl,
    );

    var genres = _genresOf(doc, metadata?.genres, selectors);
    if (genres.isEmpty) {
      final metaGenres = metaTag('og:novel:genre');
      if (metaGenres != null && metaGenres.trim().isNotEmpty) {
        genres = metaGenres
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList();
      }
    }

    final status = _firstNonEmpty(
      _fieldValue(doc, metadata?.status, selectors),
      metaTag('og:novel:status'),
    );

    return NovelMetadata(
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      language: context.plugin.language,
      genres: genres,
      status: status,
    );
  }

  /// Applies a [MetadataField] declared in the plugin's `metadata` section, or
  /// returns null so the caller can fall back to the og: tag defaults.
  String? _fieldValue(Document doc, MetadataField? field, SelectorSet? selectors) {
    if (field is CssMetadataField && selectors != null) {
      return selectors.extract(doc.documentElement!, field.selector);
    }
    if (field is InfoRowMetadataField && !field.links) {
      return _infoValue(doc, field);
    }
    return null;
  }

  /// Resolves a cover image URL against the plugin base when it is relative,
  /// since some engines (e.g. NovelFull) serve `src` as `/uploads/...`.
  String? _resolveCoverUrl(String? raw, String baseUrl) {
    if (raw == null || raw.isEmpty) return raw;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme) return raw;
    return Uri.parse(baseUrl).resolve(raw).toString();
  }

  List<String> _genresOf(Document doc, MetadataField? field, SelectorSet? selectors) {
    if (field is InfoRowMetadataField && field.links) {
      return _infoLinks(doc, field);
    }
    if (field is CssMetadataField && selectors != null) {
      final genres = <String>[];
      for (final value in selectors.extractAll(doc.documentElement!, field.selector)) {
        // Covers comma-separated values (NovelFull) and per-`<a>` genres
        // (Madara) alike.
        genres.addAll(
          value
              .split(',')
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty),
        );
      }
      return genres;
    }
    return const [];
  }

  /// Text of the info row whose `<h3>` matches one of the field's labels.
  String? _infoValue(Document doc, InfoRowMetadataField field) {
    for (final row in doc.querySelectorAll(field.container)) {
      final h3 = row.querySelector('h3');
      if (h3 == null || !field.labels.contains(h3.text.trim())) continue;
      h3.remove();
      final value = row.text.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Link texts of the info row whose `<h3>` matches one of the field's labels
  /// — e.g. the genre tags under a `Genres:` / `Genre:` row.
  List<String> _infoLinks(Document doc, InfoRowMetadataField field) {
    for (final row in doc.querySelectorAll(field.container)) {
      final h3 = row.querySelector('h3');
      if (h3 == null || !field.labels.contains(h3.text.trim())) continue;
      return row
          .querySelectorAll('a')
          .map((a) => a.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String? _firstNonEmpty(String? value, [String? second, String? third]) {
    for (final candidate in [value, second, third]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  /// Site search endpoint. Defaults to the WordPress convention (`?s=query` on
  /// the bare base URL); plugins can point elsewhere via `search.path` +
  /// `search.queryParam` in their selectors, and append fixed query parameters
  /// via `search.extraQueryParams`.
  Uri _searchUri(String baseUrl, String query, SearchSelectors search) {
    final params = <String, String>{
      search.queryParam: query,
      ...search.extraQueryParams,
    };
    final path = search.path;
    if (path == null || path.isEmpty) {
      return Uri.parse(baseUrl).replace(queryParameters: params);
    }
    return Uri.parse(baseUrl).replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: params,
    );
  }
}
