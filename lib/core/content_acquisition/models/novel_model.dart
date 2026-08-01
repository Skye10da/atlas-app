import 'dart:typed_data';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';

class NovelModel {
  const NovelModel({
    required this.sourceId,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.coverBytes,
    this.language,
    this.genres = const [],
    this.status,
    this.rating,
    required this.source,
    required this.sourceUrl,
    this.category = ContentCategory.book,
    this.fileFormat,
    this.chapterCount = 0,
    this.lastUpdated,
  });

  final String sourceId;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final Uint8List? coverBytes;
  final String? language;
  final List<String> genres;
  final String? status;
  final double? rating;
  final String source;
  final String sourceUrl;
  final ContentCategory category;
  final String? fileFormat;
  final int chapterCount;
  final DateTime? lastUpdated;

  NovelModel copyWith({
    String? sourceId,
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    Uint8List? coverBytes,
    String? language,
    List<String>? genres,
    String? status,
    double? rating,
    String? source,
    String? sourceUrl,
    ContentCategory? category,
    String? fileFormat,
    int? chapterCount,
    DateTime? lastUpdated,
  }) {
    return NovelModel(
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      coverBytes: coverBytes ?? this.coverBytes,
      language: language ?? this.language,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      category: category ?? this.category,
      fileFormat: fileFormat ?? this.fileFormat,
      chapterCount: chapterCount ?? this.chapterCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
