/// A single search match within a book's chapter content.
class BookSearchResult {
  const BookSearchResult({
    required this.chapterId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
    required this.matchStartInSnippet,
    required this.matchLength,
    required this.charOffset,
  });

  final String chapterId;
  final int chapterIndex;
  final String chapterTitle;
  final String snippet;
  final int matchStartInSnippet;
  final int matchLength;
  final int charOffset;
}

