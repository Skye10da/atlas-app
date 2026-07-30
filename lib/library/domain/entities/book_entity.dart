class BookEntity {
  const BookEntity({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.format,
    required this.totalChapters,
    this.description,
    this.language,
    this.tags = const [],
    this.rating,
    this.status,
    this.fileSize,
    this.filePath,
    this.sourceName,
    this.sourceId,
    this.sourceUrl,
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
  final String? description;
  final String? language;
  final List<String> tags;
  final double? rating;
  final String? status;
  final int? fileSize;
  final String? filePath;
  final String? sourceName;
  final String? sourceId;
  final String? sourceUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final double? progress;

  bool get isNovel => sourceName != null;
}
