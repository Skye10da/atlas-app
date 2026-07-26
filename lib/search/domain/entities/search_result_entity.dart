enum SearchResultKind { book, chapter }

class SearchResultEntity {
  const SearchResultEntity({
    required this.kind,
    required this.bookId,
    required this.title,
    required this.bookTitle,
    this.author,
    this.chapterIndex,
    this.chapterId,
    this.coverPath,
    this.totalChapters,
  });

  final SearchResultKind kind;
  final String bookId;
  final String title;
  final String bookTitle;
  final String? author;
  final int? chapterIndex;
  final String? chapterId;
  final String? coverPath;
  final int? totalChapters;
}
