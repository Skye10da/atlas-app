import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/selectors/selector_set.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';

/// Template for NovelFull (novelfull.net).
///
/// A classic server-rendered Yii novel site: chapter lists are paginated at
/// ~100 entries per page and the search form posts to `/search?keyword=`.
/// The generic [HtmlTemplate] handles plain pages, but its one-shot chapter
/// list and WordPress-style `?s=` search don't match this site, so this
/// subclass:
///
///  * pulls the complete chapter list from the site's own `ajax-chapter-option`
///    endpoint (keyed by the `data-novel-id` on the novel page), one request
///    instead of dozens, with the paginated list as a fallback,
///  * drives the site's real search endpoint,
///  * extracts the richer metadata (author, genres, status, real synopsis)
///    from the novel info panel.
///
/// Everything else (chapter content + shared clean/normalize tail) is
/// inherited from [HtmlTemplate].
class NovelfullTemplate extends HtmlTemplate {
  const NovelfullTemplate();

  /// Upper bound on pages walked by the pagination fallback, so a pathological
  /// site can't trigger an unbounded request loop.
  static const _maxPages = 200;

  @override
  String get templateId => 'novelfull';

  @override
  Set<PluginCapability> get supportedCapabilities =>
      PluginCapability.values.toSet();

  @override
  Future<List<SearchResult>> search(
    PluginContext context,
    String query,
  ) async {
    final selectors = context.selectors;
    if (selectors?.search == null) {
      throw const PluginCapabilityException(
        PluginCapability.search,
        'No search selectors configured for this plugin',
      );
    }
    // Novelfull-family sites drive search through a `keyword` query param.
    // `selectors.search.path`/`queryParam` let a data-only plugin point at a
    // different endpoint (e.g. `/novel-list/search`); the default `s` value
    // means the site didn't opt out of the conventional `keyword` name.
    final search = selectors!.search!;
    final path = search.path ?? '/search';
    final queryParam =
        search.queryParam == 's' ? 'keyword' : search.queryParam;
    final uri = Uri.parse(context.plugin.baseUrl).replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: {queryParam: query},
    );
    final html =
        await context.transport.fetchHtml(uri, headers: context.plugin.requestHeaders);
    final doc = HtmlTemplate.parser.parse(html);
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

    final seen = <String>{};
    final entries = <(int, ChapterRef)>[];

    final novelPage = await _fetchPage(context, novelUrl, 1);
    final novelId = _novelIdOf(novelPage);
    if (novelId == null ||
        !await _collectFromAjax(context, novelId, seen, entries)) {
      _collectChapters(context, novelPage, selectors, seen, entries);
      final totalPages = _maxPage(novelPage);
      for (var page = 2; page <= totalPages && page <= _maxPages; page++) {
        final doc = await _fetchPage(context, novelUrl, page);
        _collectChapters(context, doc, selectors, seen, entries);
      }
    }

    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return entries.map((e) => e.$2).toList();
  }

  /// Fetches the complete chapter list from the site's own AJAX endpoint.
  ///
  /// Two shapes are supported:
  ///
  ///  * `chapterList.ajaxPath` configured — the response is a list-shaped
  ///    fragment matching the `chapterList.item` selector, so it is parsed with
  ///    [SelectorSet.applyChapterList] (used by readnovelfull's
  ///    `/ajax/chapter-archive?novelId=...`).
  ///  * otherwise the legacy `ajax-chapter-option?novelId=...` endpoint, which
  ///    replies with a `<select>` of `<option value="/slug/chapter-N-...">`.
  ///
  /// Returns false when the endpoint can't be reached or returns nothing
  /// usable, so the caller can fall back to walking the paginated list.
  Future<bool> _collectFromAjax(
    PluginContext context,
    String novelId,
    Set<String> seen,
    List<(int, ChapterRef)> entries,
  ) async {
    final selectors = context.selectors;
    final chapterList = selectors?.chapterList;
    final ajaxPath = chapterList?.ajaxPath;
    final String html;
    try {
      html = await context.transport.fetchHtml(
        Uri.parse(context.plugin.baseUrl).replace(
          path: ajaxPath != null && ajaxPath.isNotEmpty
              ? (ajaxPath.startsWith('/') ? ajaxPath : '/$ajaxPath')
              : '/ajax-chapter-option',
          queryParameters: {'novelId': novelId},
        ),
        headers: context.plugin.requestHeaders,
      );
    } on Object {
      return false;
    }
    final doc = HtmlTemplate.parser.parse(html);
    if (ajaxPath != null && ajaxPath.isNotEmpty) {
      final base = Uri.parse(context.plugin.baseUrl);
      var added = 0;
      for (final ref in selectors!.applyChapterList(doc)) {
        final url = base.resolve(ref.url).toString();
        if (!seen.add(url)) continue;
        entries.add((
          _chapterNumber(url) ?? entries.length + 1,
          ChapterRef(title: ref.title, url: url),
        ));
        added++;
      }
      return added > 0;
    }
    final options = doc.querySelectorAll('select > option[value]');
    if (options.isEmpty) return false;

    final base = Uri.parse(context.plugin.baseUrl);
    for (final option in options) {
      final url = base.resolve(option.attributes['value']!).toString();
      if (!seen.add(url)) continue;
      entries.add((
        _chapterNumber(url) ?? entries.length + 1,
        ChapterRef(title: option.text.trim(), url: url),
      ));
    }
    return true;
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
    return _extractMetadata(HtmlTemplate.parser.parse(html), context);
  }

  Future<Document> _fetchPage(
    PluginContext context,
    String novelUrl,
    int page,
  ) async {
    final uri = page <= 1
        ? Uri.parse(novelUrl)
        : Uri.parse(novelUrl).replace(queryParameters: {'page': '$page'});
    final html =
        await context.transport.fetchHtml(uri, headers: context.plugin.requestHeaders);
    return HtmlTemplate.parser.parse(html);
  }

  void _collectChapters(
    PluginContext context,
    Document doc,
    SelectorSet selectors,
    Set<String> seen,
    List<(int, ChapterRef)> entries,
  ) {
    final base = Uri.parse(context.plugin.baseUrl);
    for (final ref in selectors.applyChapterList(doc)) {
      final url = base.resolve(ref.url).toString();
      if (!seen.add(url)) continue;
      entries.add((_chapterNumber(url) ?? entries.length + 1, ChapterRef(
            title: ref.title,
            url: url,
          )));
    }
  }

  /// Highest page number referenced by the pagination bar, or the site's own
  /// declared page count. The bar only shows a window around the current page,
  /// so this is a bound on the *next* pages to walk, never an accurate total
  /// count — the `data-total-page` attribute the site embeds is.
  int _maxPage(Document doc) {
    var max = 1;
    for (final a in doc.querySelectorAll('ul.pagination a[href]')) {
      final href = a.attributes['href'] ?? '';
      final match = RegExp(r'[?&]page=(\d+)').firstMatch(href);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > max) max = n;
    }
    // Newer novelfull-family layouts replace the `<ul>` bar with a
    // `<select id="indexselect">` whose options carry `?page=N` in `data-url`.
    for (final option in doc.querySelectorAll('#barcon option[data-url]')) {
      final match = RegExp(r'[?&]page=(\d+)')
          .firstMatch(option.attributes['data-url'] ?? '');
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > max) max = n;
    }
    // And the current layout states the page count directly on the chapter
    // list container (and the surrounding novel wrapper).
    final total = int.tryParse(
          doc.querySelector('#list-chapter')?.attributes['data-total-page'] ?? '',
        ) ??
        int.tryParse(
          doc.querySelector('#truyen')?.attributes['data-total-page'] ?? '',
        );
    if (total != null && total > max) max = total;
    return max;
  }

  /// Novel id embedded in the novel page. Old novelfull-family themes put it on
  /// `#rating[data-novel-id]`; the current novelfull.net theme moved it to the
  /// score box and the chapter-list container. Falls back to any element
  /// carrying the attribute.
  String? _novelIdOf(Document doc) {
    const candidates = [
      '#rating[data-novel-id]',
      '#novel-score[data-novel-id]',
      '#list-chapter[data-novel-id]',
    ];
    for (final selector in candidates) {
      final id = doc.querySelector(selector)?.attributes['data-novel-id'];
      if (id != null && id.isNotEmpty) return id;
    }
    return doc.querySelector('[data-novel-id]')?.attributes['data-novel-id'];
  }

  /// Chapter number from a `/slug/chapter-123-...` or `/slug/chapter-123.html`
  /// URL. Resolving by URL keeps the merge order correct even when the page
  /// lists are rendered newest-first.
  int? _chapterNumber(String url) {
    final path = Uri.parse(url).path;
    final match = RegExp(r'/chapter-(\d+)').firstMatch(path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  NovelMetadata _extractMetadata(Document doc, PluginContext context) {
    // Novelfull-family clones disagree on whether og: tags are emitted with
    // `property=` (novelfull.net) or `name=` (readnovelfull); check both.
    String? metaTag(String key) =>
        _metaContent(doc, 'property', key) ?? _metaContent(doc, 'name', key);

    final title = metaTag('og:title') ??
        doc.querySelector('.desc h3.title')?.text.trim();

    final author = metaTag('og:novel:author') ?? _infoValue(doc, 'Author');

    var genres = _infoList(doc, 'Genres');
    if (genres.isEmpty) genres = _infoList(doc, 'Genre');
    if (genres.isEmpty) {
      // Current novelfull.net theme drops the info rows for the meta tags.
      final metaGenres = metaTag('og:novel:genre');
      if (metaGenres != null && metaGenres.trim().isNotEmpty) {
        genres = metaGenres
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList();
      }
    }

    return NovelMetadata(
      title: title?.trim() ?? 'Untitled',
      author: author,
      description: _description(doc) ??
          metaTag('description') ??
          metaTag('og:description'),
      coverUrl: metaTag('og:image') ?? metaTag('twitter:image'),
      language: context.plugin.language,
      genres: genres,
      status: _infoValue(doc, 'Status') ?? metaTag('og:novel:status'),
    );
  }

  String? _metaContent(Document doc, String attr, String key) =>
      doc.querySelector('meta[$attr="$key"]')?.attributes['content']?.trim();

  /// The real synopsis lives in `.desc-text` (`og:description` on this site is
  /// boilerplate). Prefer its first paragraph, fall back to the full text with
  /// the "See more" toggle stripped off. The current novelfull.net theme moved
  /// the synopsis into `#novel-summary-inner`.
  String? _description(Document doc) {
    final paragraph = doc.querySelector('.desc-text p');
    if (paragraph != null) {
      final text = paragraph.text.trim();
      if (text.isNotEmpty) return text;
    }
    final block = doc.querySelector('.desc-text');
    if (block != null) {
      final text = block.text.trim().replaceFirst(RegExp(r'\s*See more\s*$'), '');
      if (text.isNotEmpty) return text;
    }
    final inner = doc.querySelector('#novel-summary-inner');
    if (inner != null) {
      final text = inner.text.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Text of the info row whose `<h3>` reads "<label>:" — e.g. `Status:`
  /// → "Ongoing". Row elements are `div`s on novelfull.net and `li`s on
  /// readnovelfull.
  String? _infoValue(Document doc, String label) {
    for (final row in _infoRows(doc)) {
      final h3 = row.querySelector('h3');
      if (h3 == null || h3.text.trim() != '$label:') continue;
      h3.remove();
      final value = row.text.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Links of the info row whose `<h3>` reads "<label>:" — e.g. the genre
  /// tags under `Genres:`.
  List<String> _infoList(Document doc, String label) {
    for (final row in _infoRows(doc)) {
      final h3 = row.querySelector('h3');
      if (h3 == null || h3.text.trim() != '$label:') continue;
      return row
          .querySelectorAll('a')
          .map((a) => a.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<Element> _infoRows(Document doc) =>
      doc.querySelectorAll('.col-info-desc .info div, .col-info-desc .info li');
}
