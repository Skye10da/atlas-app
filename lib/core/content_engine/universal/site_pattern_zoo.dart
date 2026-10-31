import 'dart:convert' as convert;

import 'package:html/dom.dart';

/// A chapter link discovered by the heuristic zoo.
class ScrapedChapterLink {
  const ScrapedChapterLink(this.uri, this.title);

  final Uri uri;
  final String title;
}

/// A book hit discovered on a site search-results page by the heuristic
/// zoo. `coverUrl` is best-effort — grid-tile layouts carry it, list
/// layouts often don't.
class SearchResultHit {
  const SearchResultHit(this.uri, this.title, this.coverUrl);

  final Uri uri;
  final String title;
  final String? coverUrl;
}

/// Heuristic DOM extractors for novel/book pages on sites that have no
/// dedicated plugin ("unsupported sites").
///
/// Strategy mirrors what the bundled plugins' `selectors.json` files do, but
/// with a ranked candidate list per field instead of fixed selectors: try the
/// most common structural patterns first (JSON-LD, Open Graph, common
/// content-class conventions), then fall back to semantic text analysis.
///
/// Everything here is pure DOM-in / data-out so it is unit-testable against
/// fixture HTML copied from real sites. No transport, no plugin coupling, no
/// Flutter dependencies.
///
/// Note: `package:html` CSS selector support is limited — explicitly avoid
/// CSS3 substring attribute selectors (`[class*="x"]`); do those checks in
/// code instead.
class SitePatternZoo {
  SitePatternZoo._();

  // ---------------------------------------------------------------- title

  /// Ranked title-by-class conventions (adapted from plugin selector files
  /// and common web-novel platforms).
  static const List<String> titleTextSelectors = [
    '.novel-title',
    '.book-title',
    '#title',
    '.post-title',
    '.story-title',
    '.fiction-title',
  ];

  /// Separators between a page's real title and the site name in `<title>`
  /// ("Mystic Card One | StarNovel" → "Mystic Card One").
  static final RegExp _titleSeparators = RegExp(r'\s+[|·\-–—:]\s+');

  /// Extracts the best title guess, or null when nothing plausible exists.
  static String? detectTitle(Document doc, {String? preferredSource}) =>
      detectTitleAttributed(doc, preferredSource: preferredSource).$1;

  /// [detectTitle] with provenance: `$2` names the winning zoo source
  /// (`ld-json`, `og`, a class selector like `.novel-title`, `heading`, or
  /// `doc-title`) so learned per-origin rules can re-apply it directly.
  static (String?, String) detectTitleAttributed(
    Document doc, {
    String? preferredSource,
  }) {
    // Candidate scans in priority order; a learned hint jumps the queue.
    final ordered = <(String, String? Function())>[
      ('ld-json', () {
        final hit = _jsonLdText(doc, const {'headline', 'name', 'title'});
        return _looksLikeTitle(hit) ? _clean(hit!) : null;
      }),
      ('og', () {
        final og = _metaContent(doc, const [
          'og:title',
          'twitter:title',
          'name',
          'title',
        ]);
        return _looksLikeTitle(og) ? _clean(og!) : null;
      }),
      for (final selector in titleTextSelectors)
        (selector, () {
          final el = doc.querySelector(selector);
          return _looksLikeTitle(el?.text) ? _clean(el!.text) : null;
        }),
      ('heading', () {
        final heading = _longestText(doc.querySelectorAll('h1, h2, h3'));
        return _looksLikeTitle(heading?.text) ? _clean(heading!.text) : null;
      }),
      ('doc-title', () {
        final raw = doc.querySelector('title')?.text;
        if (raw == null) return null;
        String? best;
        for (final segment in raw.split(_titleSeparators)) {
          final s = _clean(segment);
          if (!_looksLikeTitle(s)) continue;
          if (best == null || s.length > best.length) best = s;
        }
        return best;
      }),
    ];
    if (preferredSource != null) {
      final index = ordered.indexWhere((c) => c.$1 == preferredSource);
      if (index > 0) {
        final preferred = ordered.removeAt(index);
        ordered.insert(0, preferred);
      }
    }
    for (final (source, find) in ordered) {
      final hit = find();
      if (hit != null) return (hit, source);
    }
    return (null, '');
  }

  // ---------------------------------------------------------------- author

  /// Ranked author-by-class conventions.
  static const List<String> authorTextSelectors = [
    '.novel-info .author',
    '.bookinfo .author',
    '.novel-author',
    '.book-author',
    '.post-author',
    '.author-name',
    '.authors',
  ];

  static String? detectAuthor(Document doc) {
    // 1. Structured metadata.
    final jsonLd = _jsonLdText(doc, const {'author'});
    if (jsonLd != null && _looksLikeName(jsonLd)) return _clean(jsonLd);

    // 2. `<meta>` author variants.
    for (final key in const [
      'og:author',
      'book:author',
      'article:author',
      'author',
    ]) {
      final el = doc.querySelector('meta[property="$key"]') ??
          doc.querySelector('meta[name="$key"]') ??
          doc.querySelector('meta[itemprop="$key"]');
      final value = (el?.attributes['content'] ?? '').trim();
      if (_looksLikeName(value)) return _clean(value);
    }

    // 3. Class conventions.
    for (final selector in authorTextSelectors) {
      final el = doc.querySelector(selector);
      if (_looksLikeName(el?.text)) return _clean(el!.text);
    }

    // 4. "Author: …" paragraph conventions (Chinese sites use 作者：).
    final text = doc.body?.text ?? '';
    final m = RegExp(
      r'(?:作者|Author|Written by|Pen Name)[\s:：（(]+([^\n\r]{2,20})',
      multiLine: true,
    ).firstMatch(text);
    if (m != null) {
      final name = _clean(m.group(1)!);
      if (_looksLikeName(name)) return name;
    }
    return null;
  }

  // ------------------------------------------------------------- description

  static String? detectDescription(Document doc) {
    for (final key in const [
      'og:description',
      'description',
      'twitter:description',
    ]) {
      final el = doc.querySelector('meta[property="$key"]') ??
          doc.querySelector('meta[name="$key"]') ??
          doc.querySelector('meta[itemprop="$key"]');
      final value = (el?.attributes['content'] ?? '').trim();
      if (value.length >= 20) return _clean(value);
    }
    return _bestParagraph(doc);
  }

  // ---------------------------------------------------------------- cover

  static String? detectCoverUrl(Document doc, Uri baseUrl) {
    for (final key in const ['og:image', 'twitter:image']) {
      final el = doc.querySelector('meta[property="$key"]') ??
          doc.querySelector('meta[name="$key"]');
      final src = (el?.attributes['content'] ?? '').trim();
      if (src.isNotEmpty) return _resolveUrl(src, baseUrl);
    }
    for (final selector in const ['.novel-cover img', '.book-cover img']) {
      final src = doc.querySelector(selector)?.attributes['src'];
      if (src != null && src.isNotEmpty) return _resolveUrl(src, baseUrl);
    }
    return null;
  }

  // ----------------------------------------------------------------- genres

  static List<String> detectGenres(Document doc) {
    final genres = <String>{};
    final jsonLd = _jsonLdText(doc, const {'genre'});
    if (jsonLd != null) {
      for (final g in jsonLd.split(',')) {
        final t = _clean(g);
        if (t.length >= 2 && t.length <= 30) genres.add(t);
      }
    }
    for (final selector in const [
      '.genres a',
      '.novel-tags a',
      '.book-genre a',
      '.tag a',
      '.tags a',
    ]) {
      for (final el in doc.querySelectorAll(selector)) {
        final t = el.text.trim();
        if (t.length >= 2 && t.length <= 24) genres.add(t);
      }
    }
    return genres.take(8).toList(growable: false);
  }

  // ---------------------------------------------------------- chapter links

  /// href patterns that mark a link as a chapter link.
  static final RegExp chapterHrefPattern = RegExp(
    r'(?:chapter|chap|episode|/read/|/baca/)',
    caseSensitive: false,
  );

  /// Chapter-like anchor text: English ("Chapter 12", "C5"), numbered
  /// ("123. Title"), and Chinese (第…章 / 第…节 / 第…卷), optionally followed
  /// by a short chapter-heading fragment.
  static final RegExp chapterTextPattern = RegExp(
    r'^\s*(?:'
    r'chapter\s+#?\d+[\.\d]*|'
    r'chap\.?\s*\d+|'
    r'c\s?\d{1,4}\b|'
    r'\d{1,4}\.\s*\S|'
    r'第\s*[0-9\u4e00-\u9fff零一二三四五六七八九十百千万]{1,9}\s*[章节卷话話]'
    r')\s*[\s\S]{0,60}$',
    caseSensitive: false,
  );

  /// Pagination / navigation hrefs that must never count as chapters.
  static final RegExp _paginationUrlPattern = RegExp(
    r'[?&]page=\d|/page/\d',
    caseSensitive: false,
  );

  /// File-like endpoints that a novel import should never chase.
  static final RegExp _fileLikeUrlPattern = RegExp(
    r'\.(pdf|txt|jpg|jpeg|png|gif|webp|epub|md|atlas)(\?|#|$)',
    caseSensitive: false,
  );

  /// Known non-chapter navigation paths.
  static final RegExp _junkPathPattern = RegExp(
    r'(/login|/register|/tag/|/genre/|/search|/terms|/privacy|/contact|'
    r'/donate|/account|/comment|/about|/category/)',
    caseSensitive: false,
  );

  /// All chapter-like anchors on [baseUrl]'s document, de-duplicated by URL,
  /// in document order.
  static List<ScrapedChapterLink> detectChapterLinks(
    Document doc,
    Uri baseUrl,
  ) {
    final links = <ScrapedChapterLink>[];
    final seen = <String>{};
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final uri = _tryResolve(href, baseUrl);
      if (uri == null) continue;
      if (!seen.add(uri.toString())) continue;

      if (uri.host.isNotEmpty && uri.host != baseUrl.host) continue;
      if (_fileLikeUrlPattern.hasMatch(uri.toString())) continue;
      if (_paginationUrlPattern.hasMatch(uri.toString())) continue;
      if (_junkPathPattern.hasMatch(uri.path)) continue;
      if (href.startsWith('#')) continue;

      final text = _clean(a.text);
      final hrefMatches = chapterHrefPattern.hasMatch(href);
      final textMatches = chapterTextPattern.hasMatch(text);

      // A good chapter link has BOTH an href-shaped chapter URL and visible
      // chapter-shaped text. Cross-origin, file-like, junk paths and page
      // navigation were all rejected above.
      final bool valid =
          (textMatches || hrefMatches) && text.length >= 2 && text.length <= 80;
      if (!valid) continue;

      links.add(ScrapedChapterLink(uri, text));
    }
    return links;
  }

  /// The pagination "next" anchor on a (multi-page) chapter list, if any.
  static Uri? detectNextPage(Document doc, Uri baseUrl) {
    for (final selector in const [
      'a[rel="next"]',
      '.pagination .next',
      'a.next',
    ]) {
      final uri = _tryResolve(
        doc.querySelector(selector)?.attributes['href'] ?? '',
        baseUrl,
      );
      if (uri != null &&
          uri.host == baseUrl.host &&
          !_fileLikeUrlPattern.hasMatch(uri.toString())) {
        return uri;
      }
    }
    for (final a in doc.querySelectorAll('a[href]')) {
      final t = a.text.trim().toLowerCase();
      if (t == 'next' || t == '下一页' || t == 'next →' || t == '»') {
        final uri = _tryResolve(a.attributes['href'] ?? '', baseUrl);
        if (uri != null && uri.host == baseUrl.host) return uri;
      }
    }
    return null;
  }

  // ------------------------------------------------- site search (Phase 3)

  /// Search-endpoint conventions of novel sites, probed in order the first
  /// time an origin is searched; the winner is learned into the origin rule.
  /// `{query}` is the URL-encoded term, `{page}` the 1-based page number.
  static const List<String> searchUrlTemplates = [
    '/search?q={query}',
    '/?s={query}',
    '/search/,keyword/{page}',
    '/search/{query}',
    '/?query={query}',
  ];

  /// Recognized "nothing found" markers; a page containing one is a *real*
  /// empty result set, not a wrong search-url guess.
  static const List<String> _noResultsMarkers = [
    'no results',
    'not found',
    'did not match',
    '0 results',
    'zero results',
    '没有找到',
    '没有搜索到',
    '搜索结果为空',
  ];

  /// Anchor titles that are site chrome, never a book title.
  static const Set<String> _navWords = {
    'new',
    'hot',
    'latest',
    'popular',
    'completed',
    'ongoing',
    'rankings',
    'ranking',
    'forum',
    'community',
    'app',
    'more',
    'home',
    'genre',
    'genres',
    'tags',
    'login',
    'register',
    'sign in',
    'support',
    'dmca',
    'index',
    'library',
    'read now',
  };

  static bool looksLikeNoResultsPage(Document doc) {
    final text = (doc.body?.text ?? '').toLowerCase();
    return _noResultsMarkers.any(text.contains);
  }

  /// Book links on a search-results page: title from the anchor text or,
  /// for image grid cards, the image's alt/title attribute; cover from the
  /// first image inside the anchor. Filtered the same way as chapter links
  /// (cross-origin, file-like URLs, junk paths), de-duplicated by URL.
  static List<SearchResultHit> detectSearchResults(
    Document doc,
    Uri baseUrl, {
    int max = 24,
  }) {
    if (looksLikeNoResultsPage(doc)) return const [];

    final hits = <SearchResultHit>[];
    final seen = <String>{};
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final uri = _tryResolve(href, baseUrl);
      if (uri == null) continue;
      if (!seen.add(uri.toString())) continue;
      if (uri.host.isNotEmpty && uri.host != baseUrl.host) continue;
      if (_fileLikeUrlPattern.hasMatch(uri.toString())) continue;
      if (_junkPathPattern.hasMatch(uri.path)) continue;
      if (uri.path == '/' || uri == baseUrl) continue; // home/logo links

      // Title: anchor text, else an image alt/title (grid-tile results).
      var title = _clean(a.text);
      if (!_looksLikeTitle(title, min: 3)) {
        for (final img in a.querySelectorAll('img')) {
          final candidate = _clean(
            img.attributes['title'] ?? img.attributes['alt'] ?? '',
          );
          if (_looksLikeTitle(candidate, min: 3)) {
            title = candidate;
            break;
          }
        }
      }
      if (title.length < 3 || title.length > 120) continue;
      if (_navWords.contains(title.toLowerCase())) continue;

      String? coverUrl;
      for (final img in a.querySelectorAll('img')) {
        final src = _resolveUrl(
          img.attributes['src'] ?? img.attributes['data-src'] ?? '',
          baseUrl,
        );
        if (src != null) {
          coverUrl = src;
          break;
        }
      }

      hits.add(SearchResultHit(uri, title, coverUrl));
      if (hits.length >= max) break;
    }
    return hits;
  }

  // ------------------------------------------------------- chapter content

  /// Ranked content-container selector candidates, dense first, semantic
  /// (`article`, `main`) last.
  static const List<String> contentContainerSelectors = [
    '#chapter_content',
    '.chapter-content',
    '.chapter_content',
    '#chapter-content',
    '#chapterContent',
    '#txtContent',
    '#contentBox',
    '#read-content',
    '.read-content',
    '.read_content',
    '.readcontent',
    '.novel-content',
    '.novel_content',
    '.book-content',
    '.story-content',
    '.post-content',
    '.entry-content',
    '.article-content',
    '#articleContent',
    '.cont',
    '#cont',
    '#contents',
    '.content',
    '#content',
    'article',
    'main',
  ];

  /// Extracts the reader-content paragraphs, or an empty list when nothing
  /// looks like story body text.
  static List<String> detectContentParagraphs(Document doc) =>
      detectContentAttributed(doc).paragraphs;

  /// [detectContentParagraphs] with provenance: `selector` names the winning
  /// container (a CSS selector from [contentContainerSelectors], `density`,
  /// or `body`), and `preferredSelector` (from a learned per-origin rule)
  /// is tried before the ranked list — it may even be a selector the zoo
  /// does not know natively.
  static ({List<String> paragraphs, String? selector}) detectContentAttributed(
    Document doc, {
    String? preferredSelector,
  }) {
    final cleaned = _cloneMinusJunk(doc);

    final ordered = <String>[
      ?preferredSelector,
      ...contentContainerSelectors,
    ];
    final seen = <String>{};
    for (final selector in ordered) {
      if (!seen.add(selector)) continue;
      for (final el in cleaned.querySelectorAll(selector)) {
        if (_looksLikeStoryBody(_clean(el.text))) {
          return (
            paragraphs: _paragraphsFromNode(el),
            selector: selector,
          );
        }
      }
    }

    // Readability-lite: the densest text containers on the page.
    for (final el in _densestElementsByText(cleaned).take(3)) {
      if (_looksLikeStoryBody(_clean(el.text))) {
        return (paragraphs: _paragraphsFromNode(el), selector: 'density');
      }
    }

    // Last resort: the page body itself (single-page article/book content
    // with no recognizable container). A weaker bar applies here: the body
    // includes page chrome the container pass would have avoided, so only
    // demand a decent amount of text, not full story-body confidence.
    final body = cleaned.body;
    if (body != null && _clean(body.text).length >= 120) {
      return (paragraphs: _paragraphsFromNode(body), selector: 'body');
    }
    return (paragraphs: const [], selector: null);
  }

  /// Detects the current chapter's own title inside its page.
  static String? detectChapterPageTitle(Document doc) {
    for (final selector in const [
      '.chapter-title',
      '.current-title',
      'h1',
      'h2',
      '.title',
    ]) {
      final el = doc.querySelector(selector);
      if (_looksLikeTitle(el?.text, min: 3)) return _clean(el!.text);
    }
    final docTitle = doc.querySelector('title')?.text;
    if (docTitle == null) return null;
    final first = docTitle.split(_titleSeparators).first.trim();
    return _looksLikeTitle(first, min: 3) ? _clean(first) : null;
  }

  // ============================================================== internals

  static bool _looksLikeTitle(String? text, {int min = 2}) {
    if (text == null) return false;
    final t = text.trim();
    if (t.length < min || t.length > 200) return false;
    if (RegExp(r'^\d+$').hasMatch(t)) return false;
    return true;
  }

  static bool _looksLikeName(String? text) {
    if (text == null) return false;
    final t = text.trim();
    if (t.length < 2 || t.length > 60) return false;
    if (RegExp(r'^\d+$').hasMatch(t)) return false;
    return true;
  }

  /// A story body is long enough and worded enough to not be a stub, a
  /// dialog line, or a data table.
  static bool _looksLikeStoryBody(String text) {
    if (text.length < 200 || text.length > 500000) return false;
    return text.split(RegExp(r'\s+')).length >= 40;
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static Element? _longestText(List<Element> elements) {
    Element? best;
    var bestLength = 0;
    for (final el in elements) {
      final length = el.text.trim().length;
      if (length > bestLength) {
        best = el;
        bestLength = length;
      }
    }
    return best;
  }

  /// Open Graph first, then twitter/name meta variants: `[name=keys]` plus
  /// matching `[property=…]`, plus itemprop fallbacks.
  static String? _metaContent(Document doc, List<String> keys,
      {String? metaName}) {
    for (final key in keys) {
      for (final sel in <String>[
        'meta[property="$key"]',
        'meta[name="$key"]',
        'meta[itemprop="$key"]',
      ]) {
        final content = (doc.querySelector(sel)?.attributes['content'] ?? '')
            .trim();
        if (content.isNotEmpty) return content;
      }
    }
    if (metaName == null) return null;
    for (final sel in <String>[
      'meta[name="$metaName"]',
      'meta[itemprop="$metaName"]',
    ]) {
      final content = (doc.querySelector(sel)?.attributes['content'] ?? '')
          .trim();
      if (content.isNotEmpty) return content;
    }
    return null;
  }

  /// Searches all `application/ld+json` blocks for any of [keys] at any
  /// nesting depth (JSON-LD nests via `@graph`, `isPartOf`, etc.).
  static String? _jsonLdText(Document doc, Set<String> keys) {
    for (final script
        in doc.querySelectorAll('script[type="application/ld+json"]')) {
      final raw = script.text;
      if (raw.isEmpty) continue;
      var parsed = _tryParseJsonLd(raw);
      if (parsed == null) {
        // Some sites prefix comments / BOM; slice from the first brace.
        final start = [raw.indexOf('{'), raw.indexOf('[')]
            .where((i) => i >= 0)
            .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
        if (start == null || start == 0) continue;
        parsed = _tryParseJsonLd(raw.substring(start));
        if (parsed == null) continue;
      }
      final hit = _jsonWalk(parsed, keys, 0);
      if (hit is String && hit.trim().isNotEmpty) return hit;
    }
    return null;
  }

  static Object? _tryParseJsonLd(String raw) {
    try {
      return convert.jsonDecode(raw);
    } on Object {
      return null;
    }
  }

  static const int _maxJsonDepth = 12;

  static Object? _jsonWalk(Object? node, Set<String> keys, int depth) {
    if (depth > _maxJsonDepth) return null;
    if (node is Map) {
      for (final key in keys) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) return value;
        if (value is Map) {
          final name = value['name'];
          if (name is String && name.trim().isNotEmpty) return name;
        }
      }
      for (final child in node.values) {
        final hit = _jsonWalk(child, keys, depth + 1);
        if (hit != null) return hit;
      }
    } else if (node is List) {
      for (final child in node) {
        final hit = _jsonWalk(child, keys, depth + 1);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  static String? _bestParagraph(Document doc) {
    String? best;
    var bestLength = 0;
    for (final p in doc.querySelectorAll('p')) {
      final t = _clean(p.text);
      if (t.length >= 20 && t.length > bestLength) {
        best = t;
        bestLength = t.length;
      }
    }
    return best;
  }

  static String? _resolveUrl(String url, Uri baseUrl) =>
      _tryResolve(url, baseUrl)?.toString();

  static Uri? _tryResolve(String href, Uri baseUrl) {
    try {
      final uri = baseUrl.resolve(href.trim());
      if (uri.scheme.isEmpty) return null;
      return uri;
    } on Object {
      return null;
    }
  }

  /// Clones [doc], dropping nodes that pollute content extraction.
  static Document _cloneMinusJunk(Document doc) {
    final html = doc.documentElement?.outerHtml;
    if (html == null || html.isEmpty) return doc;
    try {
      final clone = Document.html(html);
      _stripJunk(clone);
      return clone;
    } on Object {
      return doc;
    }
  }

  /// Path: the html package's CSS support is limited — junk-class matching
  /// (`ad`, `banner`, `share`, …) is done by walking, not CSS.
  static const List<String> _junkTagNames = [
    'script',
    'style',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'iframe',
    'button',
    'noscript',
    'svg',
    'ins',
  ];

  /// Class/ID substrings that mark junk containers (ads, comments, related).
  static const List<String> _junkClassFragments = [
    'comment',
    'share',
    'social',
    'related',
    'recommend',
    'banner',
    'sidebar',
    'pagination',
    'breadcrumb',
    'vote',
    'rating-box',
    'footer-nav',
    'site-title',
    'cookie',
  ];

  static void _stripJunk(Document doc) {
    for (final tag in _junkTagNames) {
      for (final el in doc.querySelectorAll(tag).toList(growable: false)) {
        el.remove();
      }
    }
    // Ad blocks like `<div class="adsense-header">`, `<div id="ad_box">`.
    final adNodes = doc.querySelectorAll('[class][id]').toList()
      ..retainWhere((el) => _looksLikeAdNode(el));
    for (final el in adNodes) {
      el.remove();
    }
  }

  static bool _looksLikeAdNode(Element el) {
    final id = (el.attributes['id'] ?? '').toLowerCase();
    final cls = (el.attributes['class'] ?? '').toLowerCase();
    final haystack = '$id $cls';
    if (RegExp(r'(^|[\s\-_])(ad|ads|adv)[\s\-_]').hasMatch(haystack)) {
      return true;
    }
    for (final fragment in _junkClassFragments) {
      if (haystack.contains(fragment)) return true;
    }
    return false;
  }

  /// Approximate innerText with paragraph breaks from block-level tags.
  static List<String> _paragraphsFromNode(Element el) {
    final buffer = StringBuffer();
    _emitText(el, buffer);
    final raw = buffer.toString();
    final paragraphs = raw
        .split(RegExp(r'\n\s*\n+'))
        .map(_clean)
        .where((p) => p.length >= 2)
        .toList(growable: false);
    if (paragraphs.isEmpty && raw.trim().isNotEmpty) {
      return [_clean(raw)];
    }
    return paragraphs;
  }

  static void _emitText(Node node, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.text);
      return;
    }
    if (node is Element) {
      final tag = (node.localName ?? '').toLowerCase();
      if (tag == 'br') {
        buffer.write('\n');
        return;
      }
      final isBlock = const {
        'p', 'div', 'section', 'article', 'li', 'blockquote', 'pre',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'tr',
      }.contains(tag);
      if (isBlock) buffer.write('\n');
      for (final child in node.nodes) {
        _emitText(child, buffer);
      }
      if (isBlock) buffer.write('\n');
    }
  }

  /// Elements from `div, section, article, main` sorted by text density —
  /// long contiguous text with few direct children wins.
  static List<Element> _densestElementsByText(Document doc) {
    final candidates = <(Element, int)>[];
    for (final el in doc.querySelectorAll('div, section, article, main')) {
      final text = el.text.trim();
      if (text.length < 200) continue;
      final childCount = el.nodes.length;
      candidates.add((el, (text.length * 10) ~/ (childCount + 1)));
    }
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    return candidates.map((c) => c.$1).toList(growable: false);
  }
}
