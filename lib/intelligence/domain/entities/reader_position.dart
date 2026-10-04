/// Captures the reader's current location in a novel.
///
/// Used by the Context Engine to ensure no facts, entities, or events
/// beyond [currentChapter] are ever revealed or leaked into prompt contexts.
class ReaderPosition {
  const ReaderPosition({
    required this.bookId,
    this.readThroughId = 'default',
    required this.currentChapter,
    this.scrollOffset = 0.0,
  });

  factory ReaderPosition.fromJson(Map<String, dynamic> json) {
    return ReaderPosition(
      bookId: json['bookId'] as String,
      readThroughId: json['readThroughId'] as String? ?? 'default',
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 1,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String bookId;

  /// Identifier of the specific read-through session (default: 'default').
  final String readThroughId;

  /// The current chapter index (0-based or 1-based, matching Atlas chapter index).
  final int currentChapter;

  /// Normalized scroll progress within the current chapter (0.0 to 1.0).
  final double scrollOffset;

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'readThroughId': readThroughId,
    'currentChapter': currentChapter,
    'scrollOffset': scrollOffset,
  };
}

/// An excerpt or summary of a chapter included in the immediate recency window.
class ChapterExcerpt {
  const ChapterExcerpt({
    required this.chapterIndex,
    required this.title,
    required this.text,
    this.isSummary = false,
  });

  final int chapterIndex;
  final String title;
  final String text;
  final bool isSummary;
}

