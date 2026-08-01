import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

abstract interface class SourceAdapter {
  bool canHandle(Uri uri);
  String get sourceName;

  /// What kind of content this adapter produces. File/ebook sources (EPUB,
  /// TXT, MD) produce [ContentCategory.book]; web-serialized novel sites
  /// produce [ContentCategory.novel].
  ContentCategory get contentCategory;

  Future<NovelModel> getMetadata(Uri uri);
  Future<List<ChapterModel>> getChapters(NovelModel novel);
  Future<ChapterModel> getChapter(ChapterModel chapter);
}
