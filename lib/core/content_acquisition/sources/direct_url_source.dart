import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class DirectUrlSource implements SourceAdapter {
  @override
  String get sourceName => 'Direct URL';

  @override
  ContentCategory get contentCategory => ContentCategory.book;

  @override
  bool canHandle(Uri uri) {
    return uri.path.endsWith('.txt') || uri.path.endsWith('.md');
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final segments = uri.pathSegments;
    final filename = segments.isNotEmpty
        ? segments.last.replaceAll(RegExp(r'\.(txt|md)$'), '')
        : 'Untitled';
    final title = filename
        .replaceAll(RegExp(r'[-_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return NovelModel(
      sourceId: uri.toString(),
      title: _titleCase(title),
      source: sourceName,
      sourceUrl: uri.toString(),
      category: contentCategory,
      fileFormat: uri.path.endsWith('.md') ? 'markdown' : 'text',
      chapterCount: 1,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    return [
      ChapterModel(
        id: '${novel.sourceId}_ch0',
        title: novel.title,
        index: 0,
        contentUrl: novel.sourceUrl,
      ),
    ];
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;

    final uri = Uri.parse(chapter.contentUrl!);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch: ${response.statusCode}');
    }

    return ChapterModel(
      id: chapter.id,
      title: chapter.title,
      index: chapter.index,
      contentUrl: chapter.contentUrl,
      content: response.body,
      wordCount: response.body.split(RegExp(r'\s+')).length,
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }
}
