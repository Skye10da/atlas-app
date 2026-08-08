/// A book's persisted reading progress, decoupled from the storage layer.
///
/// [position]/[totalPositions] are the exact-position resume fields: a flat
/// sentence index into the chapter's rebuildable sentence sequence plus the
/// total sentence count. Rows written before exact-position resume existed
/// carry `0`/`0`, which the reader treats as "resume at the top of the saved
/// chapter".
class ReadingProgressSnapshot {
  const ReadingProgressSnapshot({
    required this.bookId,
    required this.chapterId,
    required this.percentage,
    required this.position,
    required this.totalPositions,
  });

  final String bookId;
  final String chapterId;

  /// Whole-book fraction × 100 — kept for the library screen's book-level
  /// progress bar / Continue Reading card.
  final double percentage;

  /// Flat index into the chapter's reconstructed sentence list.
  final int position;

  /// Total sentences in the reconstructed list (sanity bound on restore).
  final int totalPositions;
}
