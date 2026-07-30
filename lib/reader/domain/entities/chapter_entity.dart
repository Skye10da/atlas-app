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

  bool get hasNextChapter => index < totalChapters - 1;
  bool get hasPrevChapter => index > 0;
}
