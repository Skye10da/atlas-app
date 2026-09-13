import 'package:atlas_app/core/content_acquisition/models/content_category.dart';

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
    this.itemType = ContentCategory.book,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.progress,
    this.updateTrackingEnabled = true,
    this.lastCheckedAt,
    this.newChapterCount = 0,
    this.hasUpdate = false,
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
  final ContentCategory itemType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final double? progress;

  /// Whether periodic update checks run for this book (ongoing novels).
  final bool updateTrackingEnabled;

  /// Last time an update check was performed for this book.
  final DateTime? lastCheckedAt;

  /// Newly discovered chapters not yet acknowledged by opening the book.
  final int newChapterCount;

  /// True when new chapters were found since the book was last opened.
  final bool hasUpdate;

  bool get isNovel => itemType == ContentCategory.novel;
}

extension BookProgressX on BookEntity {
  /// Canonical 0..1 fraction. DB schema 13 stores 0..1; pre-13 0..100 rows
  /// are migrated via `percentage/100`. Keep `>1` guard one release for
  /// devices that haven't yet migrated.
  double get progress01 {
    final p = progress;
    if (p == null) return 0.0;
    final v = p > 1.0 ? p / 100.0 : p;
    return v.clamp(0.0, 1.0);
  }

  int get progressPct => (progress01 * 100).round().clamp(0, 100);

  /// Precise 0..100 with 2-decimal stability for thousands of chapters.
  double get progressPercent => progress01 * 100;

  String get progressLabel2 => progressPercent.toStringAsFixed(2);
}
