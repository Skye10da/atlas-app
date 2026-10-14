class ChapterEntity {
  const ChapterEntity({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.contentPath,
    this.wordCount = 0,
    this.pageCount = 0,
    this.totalChapters = 0,
    this.contentState = 0,
    this.version = 1,
    this.checksum,
    this.previousVersionRef,
  });

  final String id;
  final String bookId;
  final int index;
  final String title;
  final String contentPath;
  final int wordCount;
  final int pageCount;
  final int totalChapters;
  final int contentState;

  /// Content versioning (CDA v2.2). Bumped whenever content changes on
  /// re-fetch; [previousVersionRef] points at the superseded version.
  final int version;
  final String? checksum;
  final String? previousVersionRef;

  bool get hasNextChapter => index < totalChapters - 1;
  bool get hasPrevChapter => index > 0;

  /// Value equality on the chapter's stable identity (`id` / `bookId` /
  /// `index`). Riverpod `family` providers key by `==`, so without this
  /// two [ChapterEntity] instances carrying the same chapter (e.g. one
  /// from `ReaderContent`'s list and one from `novelChaptersProvider`'s
  /// prefetch) were treated as different family keys — breaking prefetch
  /// reuse and phase/overlay sync.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bookId == other.bookId &&
          index == other.index;

  @override
  int get hashCode => Object.hash(id, bookId, index);
}
