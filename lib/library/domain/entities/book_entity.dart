class BookEntity {
  const BookEntity({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.format,
    required this.totalChapters,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.progress,
  });

  final String id;
  final String title;
  final String? author;
  final String? coverPath;
  final String format;
  final int totalChapters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final double? progress;
}
