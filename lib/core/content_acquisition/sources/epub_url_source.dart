import 'dart:io';
import 'dart:typed_data';

import 'package:epub_plus/epub_plus.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class EpubUrlSource implements SourceAdapter {
  List<EpubChapter>? _cachedFlatChapters;

  @override
  String get sourceName => 'EPUB URL';

  @override
  bool canHandle(Uri uri) {
    return uri.path.endsWith('.epub');
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final bytes = await _readBytes(uri);
    final book = await EpubReader.readBook(bytes);
    _cachedFlatChapters = _flattenChapters(book.chapters);

    if (_cachedFlatChapters!.isEmpty) {
      final content = book.content;
      if (content != null) {
        for (final entry in content.html.entries) {
          final raw = entry.value.content;
          if (raw == null) continue;
          final text = _stripHtml(raw).trim();
          if (text.isEmpty) continue;
          _cachedFlatChapters!.add(EpubChapter(
            title: 'Chapter ${_cachedFlatChapters!.length + 1}',
            htmlContent: raw,
            subChapters: [],
          ));
        }
      }
    }

    final title = book.title ?? _titleFromFilename(uri);
    final author = book.author ?? 'Unknown Author';
    final languages = book.schema?.package?.metadata?.languages ?? [];
    final language = languages.isNotEmpty ? languages.first : null;
    final coverBytes = _extractCoverBytes(book);

    return NovelModel(
      sourceId: uri.toString(),
      title: title,
      author: author,
      coverBytes: coverBytes,
      language: language,
      source: sourceName,
      sourceUrl: uri.toString(),
      chapterCount: _cachedFlatChapters!.length,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    final flat = _cachedFlatChapters;
    if (flat == null || flat.isEmpty) {
      return [
        ChapterModel(
          id: '${novel.sourceId}_ch0',
          title: novel.title,
          index: 0,
          contentUrl: novel.sourceUrl,
        ),
      ];
    }

    final results = <ChapterModel>[];
    var index = 0;
    for (final ch in flat) {
      final html = ch.htmlContent;
      if (html == null) continue;

      final text = _stripHtml(html).trim();
      if (text.isEmpty) continue;

      final chTitle = ch.title ?? 'Chapter ${index + 1}';
      results.add(ChapterModel(
        id: '${novel.sourceId}_ch$index',
        title: chTitle,
        index: index,
        content: text,
        contentUrl: novel.sourceUrl,
        wordCount: text.split(RegExp(r'\s+')).length,
      ));
      index++;
    }

    if (results.isEmpty) {
      throw Exception('No readable content found in EPUB');
    }
    return results;
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    return chapter;
  }

  Future<Uint8List> _readBytes(Uri uri) async {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to download EPUB: ${response.statusCode}');
      }
      return response.bodyBytes;
    }
    try {
      final file = File(uri.toFilePath());
      if (await file.exists()) return file.readAsBytes();
    } catch (_) {}
    if (uri.scheme.length == 1 && uri.path.isNotEmpty) {
      final file = File('${uri.scheme}:${uri.path}');
      if (await file.exists()) return file.readAsBytes();
    }
    throw Exception('Cannot read EPUB from: $uri');
  }

  String _titleFromFilename(Uri uri) {
    final segments = uri.pathSegments;
    final filename = segments.isNotEmpty
        ? segments.last.replaceAll('.epub', '')
        : 'Untitled';
    return filename.replaceAll(RegExp(r'[-_]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Uint8List? _extractCoverBytes(EpubBook book) {
    final manifest = book.schema?.package?.manifest;
    final items = manifest?.items ?? [];
    final metaItems = book.schema?.package?.metadata?.metaItems ?? [];

    EpubManifestItem? coverItem;
    for (final item in items) {
      if (item.id?.toLowerCase() == 'cover-image') { coverItem = item; break; }
    }
    if (coverItem == null) {
      for (final meta in metaItems) {
        if (meta.name?.toLowerCase() == 'cover' && meta.content != null) {
          final cid = meta.content!.toLowerCase();
          for (final item in items) {
            if (item.id?.toLowerCase() == cid) { coverItem = item; break; }
          }
          if (coverItem != null) break;
        }
      }
    }
    if (coverItem == null) {
      for (final item in items) {
        if ((item.properties ?? '').toLowerCase().contains('cover-image')) {
          coverItem = item; break;
        }
      }
    }
    if (coverItem?.href == null) return null;
    final href = coverItem!.href!;
    final imageFile = book.content?.images[href];
    final bytes = imageFile?.content;
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<head>.*?</head>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script.*?>.*?</script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style.*?>.*?</style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final flat = <EpubChapter>[];
    for (final ch in chapters) {
      flat.add(ch);
      flat.addAll(_flattenChapters(ch.subChapters));
    }
    return flat;
  }
}
