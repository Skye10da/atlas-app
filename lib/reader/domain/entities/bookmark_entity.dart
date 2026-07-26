class BookmarkEntity {
  const BookmarkEntity({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.position,
    this.note,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String chapterId;
  final int position;
  final String? note;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
}
