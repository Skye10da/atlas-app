import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/templates/template_models.dart';

class SearchSelectors {
  const SearchSelectors({
    required this.resultItem,
    this.title = '@text',
    this.coverUrl,
    this.detailUrl,
    this.path,
    this.queryParam = 's',
    this.extraQueryParams = const {},
  });

  factory SearchSelectors.fromJson(Map<String, Object?> json) =>
      SearchSelectors(
        resultItem: (json['resultItem'] as String?) ?? '',
        title: (json['title'] as String?) ?? '@text',
        coverUrl: json['coverUrl'] as String?,
        detailUrl: json['detailUrl'] as String?,
        path: json['path'] as String?,
        queryParam: (json['queryParam'] as String?) ?? 's',
        extraQueryParams: json['extraQueryParams'] is Map
            ? (json['extraQueryParams'] as Map).map(
                (k, v) => MapEntry('$k', '$v'),
              )
            : const {},
      );

  final String resultItem;
  final String title;
  final String? coverUrl;
  final String? detailUrl;

  /// Site search path relative to `baseUrl`, e.g. `/search` or
  /// `/fictions/search`. When null, the generic template falls back to the
  /// WordPress-convention `?s=` query on the bare base URL.
  final String? path;

  /// Name of the query parameter carrying the search term (default `s`).
  final String queryParam;

  /// Fixed query parameters merged into every search request alongside the
  /// term, e.g. WordPress-manga sites need `{"post_type": "wp-manga"}`.
  final Map<String, String> extraQueryParams;
}

/// Overrides applied when parsing the response of [ChapterListSelectors.ajaxPath].
///
/// When a field is null the template falls back to the main [ChapterListSelectors]
/// values, so a site whose archive response is shaped like its index page needs
/// no extra config. NovelFull's legacy `ajax-chapter-option` endpoint instead
/// replies with a bare `<select>` of `<option value="/slug/chapter-N-...">`,
/// which is declared here (`item: "select > option[value]"`, `url: "@value"`).
///
/// Madara-style WordPress sites go a step further: the archive is a form POST
/// (`method: "POST"`, `form`) whose response wraps the `<li>` list in JSON
/// (`responseField: "data.content"`), keyed by the novel id held on a `data-*`
/// attribute rather than in the query string (`novelIdSelector`).
class AjaxArchiveSelectors {
  const AjaxArchiveSelectors({
    this.item,
    this.title,
    this.url,
    this.novelIdSelector = '[data-novel-id]@data-novel-id',
    this.method = 'GET',
    this.form = const {},
    this.responseField,
    this.ajaxBase = 'base',
  });

  factory AjaxArchiveSelectors.fromJson(Map<String, Object?> json) =>
      AjaxArchiveSelectors(
        item: json['item'] as String?,
        title: json['title'] as String?,
        url: json['url'] as String?,
        novelIdSelector:
            (json['novelIdSelector'] as String?) ??
            '[data-novel-id]@data-novel-id',
        method: (json['method'] as String?)?.toUpperCase() ?? 'GET',
        form: json['form'] is Map
            ? (json['form'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : const {},
        responseField: json['responseField'] as String?,
        ajaxBase: (json['ajaxBase'] as String?) ?? 'base',
      );

  final String? item;
  final String? title;
  final String? url;

  /// Element + attribute carrying the novel id used to key the archive
  /// request — an extraction spec, so `#manga-chapters-holder@data-id` reads
  /// the `data-id` attribute of that element. `|` fallbacks work here too,
  /// e.g. `#manga-chapters-holder@data-id|#madara-chapters-holder@data-id`.
  /// In `GET` mode the value becomes the `?novelId=` query parameter; in
  /// `POST` mode it replaces the `{novelId}` placeholder in [form].
  final String novelIdSelector;

  /// `GET` (default) or `POST`. POST requests are sent as
  /// `application/x-www-form-urlencoded` to `<ajaxBase><ajaxPath>` with [form]
  /// as the body.
  final String method;

  /// Form body for `POST` archives. The value `{novelId}` is replaced with the
  /// extracted novel id, so Madara's `admin-ajax.php` contract is declared as
  /// `{"action": "manga_get_chapters", "manga": "{novelId}"}`.
  final Map<String, String> form;

  /// Dotted path into a JSON archive response that wraps the HTML fragment,
  /// e.g. `data.content` for `{"success": true, "data": {"content": "<li>..."}}`.
  /// Null means the response is plain HTML.
  final String? responseField;

  /// Which URL the archive path resolves against: `base` (the plugin base URL,
  /// e.g. `/wp-admin/admin-ajax.php`) or `novel` (the novel page itself, e.g.
  /// Madara's legacy `/ajax/chapters` endpoint under the novel slug).
  final String ajaxBase;
}

class ChapterListSelectors {
  const ChapterListSelectors({
    required this.item,
    this.title = '@text',
    this.url = '@href',
    this.reverse = false,
    this.pageParam = 'page',
    this.maxPages = 1,
    this.ajaxPath,
    this.ajaxArchive,
    this.paginationSelector,
    this.totalPagesSelector,
    this.sortByChapterNumber = false,
  });

  factory ChapterListSelectors.fromJson(Map<String, Object?> json) =>
      ChapterListSelectors(
        item: (json['item'] as String?) ?? '',
        title: (json['title'] as String?) ?? '@text',
        url: (json['url'] as String?) ?? '@href',
        reverse: json['reverse'] is bool ? json['reverse'] as bool : false,
        pageParam: (json['pageParam'] as String?) ?? 'page',
        maxPages: json['maxPages'] is num
            ? (json['maxPages'] as num).toInt()
            : 1,
        ajaxPath: json['ajaxPath'] as String?,
        ajaxArchive: json['ajaxArchive'] is Map
            ? AjaxArchiveSelectors.fromJson(
                Map<String, Object?>.from(json['ajaxArchive'] as Map),
              )
            : null,
        paginationSelector: json['paginationSelector'] as String?,
        totalPagesSelector: json['totalPagesSelector'] as String?,
        sortByChapterNumber: json['sortByChapterNumber'] is bool
            ? json['sortByChapterNumber'] as bool
            : false,
      );

  final String item;
  final String title;
  final String url;

  /// When true, reverses the merged chapter list — for sites that render the
  /// newest chapter first but should present chapters oldest→newest.
  final bool reverse;

  /// Query parameter used to walk additional index pages (default `page`).
  final String pageParam;

  /// Number of index pages to walk (`?pageParam=N`), default 1 (single page).
  final int maxPages;

  /// Optional site AJAX endpoint that returns the complete chapter list in one
  /// request (e.g. `/ajax/chapter-archive`). Templates that support it fetch
  /// `<baseUrl><ajaxPath>?novelId=...` and parse the response with [item] (or
  /// [ajaxArchive] when the archive is shaped differently).
  final String? ajaxPath;

  /// Selectors for the archive response when it doesn't match the index-page
  /// selectors. Falls back to [item]/[title]/[url] when absent.
  final AjaxArchiveSelectors? ajaxArchive;

  /// Container(s) holding pagination links (e.g. `ul.pagination, #barcon`).
  /// Templates scan `a[href]` and `option[data-url]` inside for
  /// `[?&]<pageParam>=N` and use the largest number as an upper bound on the
  /// pages to walk — a windowed bar is only ever a bound, so the walk also
  /// stops once a page adds nothing new.
  final String? paginationSelector;

  /// Optional element carrying the declared page count in `data-total-page`
  /// (e.g. `#truyen`); the most reliable bound when the site embeds it.
  final String? totalPagesSelector;

  /// When true, sorts the merged list by the chapter number embedded in each
  /// URL (`/chapter-<N>-...`), for sites whose index pages render newest-first.
  final bool sortByChapterNumber;
}

class ChapterContentSelectors {
  const ChapterContentSelectors({required this.container, this.title});

  factory ChapterContentSelectors.fromJson(Map<String, Object?> json) =>
      ChapterContentSelectors(
        container: (json['container'] as String?) ?? '',
        title: json['title'] as String?,
      );

  final String container;
  final String? title;
}

/// One extractable novel-metadata field. Either a plain CSS spec (string, e.g.
/// `.desc-text p` or `img@src`) or a labeled info-row extraction (object) for
/// sites whose info panel can't be expressed as a single CSS query.
sealed class MetadataField {
  const MetadataField();

  factory MetadataField.fromJson(Object? json) {
    if (json is String) return CssMetadataField(json);
    if (json is Map) {
      final map = Map<String, Object?>.from(json);
      final label = map['label'];
      final rawLabels = map['labels'];
      if (label is String || rawLabels is List) {
        final labels = <String>[
          if (label is String) label,
          ...?rawLabels is List ? rawLabels.whereType<String>() : null,
        ];
        return InfoRowMetadataField(
          container:
              (map['container'] as String?) ??
              '.col-info-desc .info div, .col-info-desc .info li',
          labels: labels,
          links: map['links'] is bool ? map['links'] as bool : false,
        );
      }
      final selector = map['selector'];
      if (selector is String) return CssMetadataField(selector);
    }
    throw const FormatException(
      'metadata field must be a selector string or an info-row object',
    );
  }
}

/// A plain CSS extraction instruction, applied the same way as other selector
/// values (`@attr` suffix and `|` fallbacks included).
class CssMetadataField extends MetadataField {
  const CssMetadataField(this.selector);

  final String selector;
}

/// Text/value of an info-panel row whose `<h3>` reads "<label>:". Rows are
/// matched by [container] (e.g. `.col-info-desc .info div, ... li`); [labels]
/// are the acceptable `<h3>` texts (e.g. `Genres:` / `Genre:`). With [links]
/// the link texts are returned (genre tags); otherwise the row's text with the
/// `<h3>` removed.
class InfoRowMetadataField extends MetadataField {
  const InfoRowMetadataField({
    this.container = '.col-info-desc .info div, .col-info-desc .info li',
    required this.labels,
    this.links = false,
  });

  final String container;
  final List<String> labels;
  final bool links;
}

/// Optional data-driven override section for a novel's metadata. Each field is
/// optional; fields not declared (or sites with no `metadata` section at all)
/// fall back to the template's og: tag defaults.
class MetadataSelectors {
  const MetadataSelectors({
    this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.genres,
    this.status,
  });

  factory MetadataSelectors.fromJson(Map<String, Object?> json) =>
      MetadataSelectors(
        title: _field(json['title']),
        author: _field(json['author']),
        description: _field(json['description']),
        coverUrl: _field(json['coverUrl']),
        genres: _field(json['genres']),
        status: _field(json['status']),
      );

  static MetadataField? _field(Object? json) =>
      json == null ? null : MetadataField.fromJson(json);

  final MetadataField? title;
  final MetadataField? author;
  final MetadataField? description;
  final MetadataField? coverUrl;
  final MetadataField? genres;
  final MetadataField? status;
}

/// A parsed `selectors.json` plus the logic that applies it over a DOM.
///
/// Selector values may carry an extraction instruction as an `@attr` suffix
/// (`@text`, `@href`, `img@src`, ...). This class is the single place that
/// knows how to turn a selector string into extracted data.
class SelectorSet {
  const SelectorSet({
    this.search,
    this.chapterList,
    this.chapterContent,
    this.metadata,
  });

  factory SelectorSet.fromJson(Map<String, Object?> json) {
    final search = json['search'];
    final chapterList = json['chapterList'];
    final chapterContent = json['chapterContent'];
    final metadata = json['metadata'];
    return SelectorSet(
      search: search is Map
          ? SearchSelectors.fromJson(Map<String, Object?>.from(search))
          : null,
      chapterList: chapterList is Map
          ? ChapterListSelectors.fromJson(
              Map<String, Object?>.from(chapterList),
            )
          : null,
      chapterContent: chapterContent is Map
          ? ChapterContentSelectors.fromJson(
              Map<String, Object?>.from(chapterContent),
            )
          : null,
      metadata: metadata is Map
          ? MetadataSelectors.fromJson(Map<String, Object?>.from(metadata))
          : null,
    );
  }

  final SearchSelectors? search;
  final ChapterListSelectors? chapterList;
  final ChapterContentSelectors? chapterContent;
  final MetadataSelectors? metadata;

  List<SearchResult> applySearch(Document doc, {required String baseUrl}) {
    final selectors = search;
    if (selectors == null) return const [];
    final results = <SearchResult>[];
    for (final item in doc.querySelectorAll(selectors.resultItem)) {
      final title = extract(item, selectors.title);
      final detail =
          extract(item, selectors.detailUrl ?? '@href') ??
          extract(item, 'a@href');
      if (title == null || title.isEmpty || detail == null) continue;
      String? coverUrl;
      if (selectors.coverUrl != null) {
        final raw = extract(item, selectors.coverUrl!);
        if (raw != null && raw.isNotEmpty) {
          coverUrl = _resolveUrl(raw, baseUrl);
        }
      }
      results.add(
        SearchResult(
          title: title,
          url: _resolveUrl(detail, baseUrl),
          coverUrl: coverUrl,
        ),
      );
    }
    return results;
  }

  List<ChapterRef> applyChapterList(Document doc) {
    final selectors = chapterList;
    if (selectors == null) return const [];
    final refs = <ChapterRef>[];
    for (final item in doc.querySelectorAll(selectors.item)) {
      final title = extract(item, selectors.title);
      final url = extract(item, selectors.url);
      if (title == null || title.isEmpty || url == null || url.isEmpty) {
        continue;
      }
      refs.add(ChapterRef(title: title, url: url));
    }
    return refs;
  }

  /// The element holding the chapter body. Falls back to the document body
  /// when the container selector doesn't match (site changed under us).
  Element? applyContentContainer(Document doc) {
    final selectors = chapterContent;
    if (selectors == null || selectors.container.isEmpty) return doc.body;
    return doc.querySelector(selectors.container) ?? doc.body;
  }

  /// Resolves a selector-driven extraction instruction relative to [scope].
  ///
  /// `|` separates fallback alternatives evaluated in order until one yields a
  /// non-empty value, so a site whose markup drifted under an old class can
  /// list `.chapter-title|.nchr-text` and keep working. Bracketed attribute
  /// selectors are not split on `|`.
  String? extract(Element scope, String spec) {
    for (final alternative in _splitAlternatives(spec)) {
      final value = _extractSingle(scope, alternative);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Like [extract] but collects the value of *every* matching element across
  /// the fallback alternatives, deduplicated. Used for multi-value metadata
  /// such as Madara genre links, where each `<a>` in
  /// `.summary_content .genres-content` is one genre and there is no comma
  /// separator to split on.
  List<String> extractAll(Element scope, String spec) {
    final values = <String>{};
    for (final alternative in _splitAlternatives(spec)) {
      final trimmed = alternative.trim();
      if (trimmed == '@text') {
        final value = scope.text.trim();
        if (value.isNotEmpty) values.add(value);
        continue;
      }
      final at = trimmed.lastIndexOf('@');
      final String selector;
      final String attr;
      if (at >= 0) {
        selector = trimmed.substring(0, at);
        attr = trimmed.substring(at + 1);
      } else {
        selector = trimmed;
        attr = 'text';
      }
      final elements = at == 0 ? [scope] : scope.querySelectorAll(selector);
      for (final el in elements) {
        final value = (attr == 'text' ? el.text : el.attributes[attr])?.trim();
        if (value != null && value.isNotEmpty) values.add(value);
      }
    }
    return values.toList();
  }

  /// Splits a selector spec on `|`, ignoring pipes inside `[...]` attribute
  /// selectors.
  List<String> _splitAlternatives(String spec) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final char in spec.split('')) {
      if (char == '[') {
        depth++;
      } else if (char == ']') {
        if (depth > 0) depth--;
      }
      if (char == '|' && depth == 0) {
        parts.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    parts.add(buffer.toString().trim());
    return parts;
  }

  String? _extractSingle(Element scope, String spec) {
    final trimmed = spec.trim();
    if (trimmed == '@text') return scope.text.trim();
    final at = trimmed.lastIndexOf('@');
    if (at >= 0) {
      final selector = trimmed.substring(0, at);
      final attr = trimmed.substring(at + 1);
      final el = at == 0 ? scope : scope.querySelector(selector);
      if (el == null) return null;
      if (attr == 'text') return el.text.trim();
      return el.attributes[attr]?.trim();
    }
    final el = scope.querySelector(trimmed);
    if (el == null) return null;
    return el.text.trim();
  }

  String _resolveUrl(String raw, String baseUrl) =>
      Uri.parse(baseUrl).resolve(raw).toString();
}
