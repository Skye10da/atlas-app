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
  });

  factory SearchSelectors.fromJson(Map<String, Object?> json) => SearchSelectors(
        resultItem: (json['resultItem'] as String?) ?? '',
        title: (json['title'] as String?) ?? '@text',
        coverUrl: json['coverUrl'] as String?,
        detailUrl: json['detailUrl'] as String?,
        path: json['path'] as String?,
        queryParam: (json['queryParam'] as String?) ?? 's',
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
}

class ChapterListSelectors {
  const ChapterListSelectors({
    required this.item,
    this.title = '@text',
    this.url = '@href',
    this.reverse = false,
    this.pageParam = 'page',
    this.maxPages = 1,
  });

  factory ChapterListSelectors.fromJson(Map<String, Object?> json) =>
      ChapterListSelectors(
        item: (json['item'] as String?) ?? '',
        title: (json['title'] as String?) ?? '@text',
        url: (json['url'] as String?) ?? '@href',
        reverse: json['reverse'] is bool ? json['reverse'] as bool : false,
        pageParam: (json['pageParam'] as String?) ?? 'page',
        maxPages: json['maxPages'] is num ? (json['maxPages'] as num).toInt() : 1,
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
}

class ChapterContentSelectors {
  const ChapterContentSelectors({
    required this.container,
    this.title,
  });

  factory ChapterContentSelectors.fromJson(Map<String, Object?> json) =>
      ChapterContentSelectors(
        container: (json['container'] as String?) ?? '',
        title: json['title'] as String?,
      );

  final String container;
  final String? title;
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
  });

  factory SelectorSet.fromJson(Map<String, Object?> json) {
    final search = json['search'];
    final chapterList = json['chapterList'];
    final chapterContent = json['chapterContent'];
    return SelectorSet(
      search: search is Map
          ? SearchSelectors.fromJson(Map<String, Object?>.from(search))
          : null,
      chapterList: chapterList is Map
          ? ChapterListSelectors.fromJson(Map<String, Object?>.from(chapterList))
          : null,
      chapterContent: chapterContent is Map
          ? ChapterContentSelectors.fromJson(
              Map<String, Object?>.from(chapterContent),
            )
          : null,
    );
  }

  final SearchSelectors? search;
  final ChapterListSelectors? chapterList;
  final ChapterContentSelectors? chapterContent;

  List<SearchResult> applySearch(Document doc, {required String baseUrl}) {
    final selectors = search;
    if (selectors == null) return const [];
    final results = <SearchResult>[];
    for (final item in doc.querySelectorAll(selectors.resultItem)) {
      final title = _extract(item, selectors.title);
      final detail = _extract(item, selectors.detailUrl ?? '@href') ??
          _extract(item, 'a@href');
      if (title == null || title.isEmpty || detail == null) continue;
      String? coverUrl;
      if (selectors.coverUrl != null) {
        final raw = _extract(item, selectors.coverUrl!);
        if (raw != null && raw.isNotEmpty) {
          coverUrl = _resolveUrl(raw, baseUrl);
        }
      }
      results.add(SearchResult(
        title: title,
        url: _resolveUrl(detail, baseUrl),
        coverUrl: coverUrl,
      ));
    }
    return results;
  }

  List<ChapterRef> applyChapterList(Document doc) {
    final selectors = chapterList;
    if (selectors == null) return const [];
    final refs = <ChapterRef>[];
    for (final item in doc.querySelectorAll(selectors.item)) {
      final title = _extract(item, selectors.title);
      final url = _extract(item, selectors.url);
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
  String? _extract(Element scope, String spec) {
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
