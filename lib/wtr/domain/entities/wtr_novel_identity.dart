/// Helpers that decide whether a library book comes from WTR-Lab and extract
/// the numeric id the WTR reader API expects (`raw_id`).
///
/// Kept as pure functions over plain strings so the WTR module never couples to
/// the library's entity layer — the novel-details page feeds in
/// `book.sourceUrl` / `book.sourceId` / `book.sourceName` directly.
library;

/// True when the book's source looks like wtr-lab.com.
bool isWtrLabSource({String? sourceUrl, String? sourceName}) {
  final host = Uri.tryParse(sourceUrl ?? '')?.host;
  if (host != null && (host == 'wtr-lab.com' || host == 'www.wtr-lab.com')) {
    return true;
  }
  final name = (sourceName ?? '').toLowerCase();
  return name.contains('wtr-lab') || name == 'wtr';
}

/// Extracts the WTR `raw_id` for a book: prefers a numeric `sourceId`, then
/// falls back to the numeric segment after `/novel/` in the source URL
/// (e.g. `https://wtr-lab.com/en/novel/29058`).
int? wtrRawIdOf({String? sourceId, String? sourceUrl}) {
  if (sourceId != null) {
    final direct = int.tryParse(sourceId);
    if (direct != null) return direct;
  }
  final segments = Uri.tryParse(sourceUrl ?? '')?.pathSegments;
  if (segments == null) return null;
  final novelIdx = segments.indexOf('novel');
  if (novelIdx < 0 || novelIdx + 1 >= segments.length) return null;
  return int.tryParse(segments[novelIdx + 1]);
}
