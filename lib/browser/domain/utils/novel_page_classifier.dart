/// URL-level classification of the page the immersive browser is on.
///
/// The novel-detection pill must only ever offer an import for a novel's
/// *detail* page: importing a homepage, a category/genre listing or a
/// chapter page would index the wrong document (chapters pollute the
/// chapter list; listings produce junk titles). The classifier is
/// deliberately conservative: anything it cannot confidently call a novel
/// detail page is rejected.
enum NovelPageKind {
  /// A single novel/book detail page — the only importable kind.
  novelDetail,

  /// An individual chapter's content page. Never importable: the chapter
  /// list must be indexed from the detail page, not from this one.
  chapter,

  /// Anything else — homepage, category/genre/tag listing, search page,
  /// author page, single-word path roots, and non-http(s) addresses.
  other,
}

/// Lowercase path segments that mean a listing or site chrome page, never a
/// single novel's detail page.
const Set<String> _kListingSegments = {
  'home',
  'index',
  'main',
  'category',
  'categories',
  'cat',
  'genre',
  'genres',
  'tag',
  'tags',
  'list',
  'browse',
  'search',
  'latest',
  'new',
  'newest',
  'popular',
  'hot',
  'top',
  'trending',
  'ranking',
  'rankings',
  'rank',
  'update',
  'updated',
  'updates',
  'ongoing',
  'complete',
  'completed',
  'author',
  'authors',
  'user',
  'profile',
  'page',
  'news',
  'blog',
  'dashboard',
  'library',
  'bookmarks',
  'reading',
  'history',
  // Common compound listing routes (kept exact — stems would swallow novel
  // slugs like `the-latest-king`).
  'latest-update',
  'latest-updates',
  'latest-releases',
  'new-releases',
  'all-novels',
  'most-popular',
  'novel-list',
  'novels-list',
  'ongoing-novels',
  'completed-novels',
};

/// Lowercase path segments that mean a chapter/list-of-chapters page on the
/// popular novel-site URL schemes. Never importable: the chapter list must
/// be indexed from the detail page.
const Set<String> _kChapterSegments = {
  'chapter',
  'chapters',
  'chapter-list',
  'chapterlist',
  'chapters-list',
  'new-chapters',
  'toc',
  'episode',
  'ch',
  'part',
};

/// Matches chapter-shaped paths:
/// `chapter-12`, `chapter_12`, `/chapter/12`, `-chapter-12`, `chap-12`,
/// `episode-3`, `/ep/12`, `/ch/12`, `part-4`.
final RegExp _kChapterShape = RegExp(
  r'(?:chapter|chap|episode|ep|ch|part)[-_/\d]',
  caseSensitive: false,
);

/// Path prefixes that are reader routes on many sites (`/read/...`,
/// `/baca/...` — the Indonesian "read" used by several plugins).
const Set<String> _kReaderPathPrefixes = {
  'read',
  'baca',
  'reading-chapter',
};

/// Classifies [url] for the import affordance.
///
/// The verdict is purely lexical — it runs on every committed navigation, so
/// it must be cheap and deterministic. A `novelDetail` verdict means "safe to
/// hand to the import engine"; the import engine itself re-umps the URL
/// through the site's real adapter (or the universal one) as before.
NovelPageKind classifyNovelPageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return NovelPageKind.other;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return NovelPageKind.other;
  if (uri.host.isEmpty) return NovelPageKind.other;

  final segments = [
    for (final segment in uri.pathSegments)
      _stripFileExtension(segment.trim().toLowerCase()),
  ]..removeWhere((s) => s.isEmpty);
  final path = segments.join('/');

  // Site root or explicit home path: the homepage can never be a novel.
  if (path.isEmpty) return NovelPageKind.other;

  // Any listing-chrome segment anywhere in the path (category/genre/tag/
  // search/listings) disqualifies the whole URL, even when a slug rides
  // along in later segments (`/category/xianxia/novel-name`).
  for (final segment in segments) {
    if (_kListingSegments.contains(segment)) return NovelPageKind.other;
    if (_kChapterSegments.contains(segment)) return NovelPageKind.chapter;
  }

  // Reader route prefix (`/read/xxx`): a chapter page on this style of site.
  if (_kReaderPathPrefixes.contains(segments.first)) {
    return NovelPageKind.chapter;
  }

  // Explicit chapter marker anywhere in the path.
  if (_kChapterShape.hasMatch(path)) return NovelPageKind.chapter;

  // Trailing bare page number (`/123`) — a chapter under some URL schemes;
  // a novel detail page never ends in a raw count.
  final last = segments.last;
  if (RegExp(r'^\d+$').hasMatch(last) && segments.length > 1) {
    return NovelPageKind.chapter;
  }

  return NovelPageKind.novelDetail;
}

/// Drops a trailing `.html` / `.htm` / `.php` file extension so
/// `index.html`, `novel-name.html` and friends classify by their stem.
String _stripFileExtension(String segment) {
  for (final extension in const ['.html', '.htm', '.php']) {
    if (segment.endsWith(extension)) {
      return segment.substring(0, segment.length - extension.length);
    }
  }
  return segment;
}
