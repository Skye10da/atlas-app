import 'dart:convert';

import 'package:epub_plus/epub_plus.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class PublicDomainLibrarySource implements SearchableSource {
  PublicDomainLibrarySource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://publicdomainlibrary.org';

  @override
  String get sourceName => 'Public Domain Library';

  @override
  ContentCategory get contentCategory => ContentCategory.book;

  @override
  bool canHandle(Uri uri) {
    return uri.host == 'publicdomainlibrary.org' || uri.host == 'www.publicdomainlibrary.org';
  }

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async {
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {'q': query.term});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Public Domain Library search failed: ${response.statusCode}');
    }

    final results = _parseSearchResults(response.body);
    return SourceSearchResponse(results: results, totalCount: results.length);
  }

  List<SourceSearchResult> _parseSearchResults(String html) {
    final results = <SourceSearchResult>[];

    final previews = html.split('data-book-preview');
    for (int i = 1; i < previews.length; i++) {
      final card = previews[i];

      final titleMatch = RegExp(r'pdl-book-preview__title[^>]*>\s*([^<]+)').firstMatch(card);
      final title = titleMatch?.group(1)?.trim() ?? 'Untitled';

      final authorMatch = RegExp(r'pdl-book-preview__author[^>]*>\s*([^<]+)').firstMatch(card);
      final author = authorMatch?.group(1)?.trim();

      final viewMatch = RegExp(r'/en/ebooks/([\w-]+)').firstMatch(card);
      final slug = viewMatch?.group(1);
      if (slug == null) continue;

      final coverMatch = RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(card);
      final coverUrl = coverMatch?.group(1);

      results.add(SourceSearchResult(
        id: slug,
        title: title,
        author: author,
        coverUrl: coverUrl,
        importUrl: '$_baseUrl/en/ebooks/$slug',
      ));
    }

    return results;
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch book: ${response.statusCode}');
    }

    final jsonLd = _parseJsonLd(response.body);

    final title = jsonLd['name'] as String? ?? 'Untitled';
    final authorData = jsonLd['author'] as Map?;
    final author = authorData?['name'] as String?;
    final description = jsonLd['description'] as String?;
    final image = jsonLd['image'] as String?;
    final genres = (jsonLd['genre'] as List<dynamic>?)?.cast<String>() ?? [];

    String? epubUrl;
    final workExamples = jsonLd['workExample'] as List<dynamic>? ?? [];
    for (final example in workExamples) {
      if (example is Map) {
        final format = example['encodingFormat'] as String?;
        if (format?.toUpperCase() == 'EPUB') {
          final action = example['potentialAction'] as Map?;
          epubUrl = action?['target'] as String?;
          break;
        }
      }
    }

    if (epubUrl == null) throw Exception('No EPUB available for this book.');

    final slug = uri.pathSegments.last;
    return NovelModel(
      sourceId: slug,
      title: title,
      author: author,
      description: description,
      coverUrl: image,
      genres: genres,
      source: sourceName,
      sourceUrl: epubUrl,
      fileFormat: 'epub',
    );
  }

  Map<String, dynamic> _parseJsonLd(String html) {
    final jsonMatch = RegExp(
      r'<script type="application/ld\+json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (jsonMatch == null) throw Exception('No JSON-LD metadata found');
    return jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    final response = await _client.get(Uri.parse(novel.sourceUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download EPUB: ${response.statusCode}');
    }

    final book = await EpubReader.readBook(response.bodyBytes);
    final flat = _flattenChapters(book.chapters);

    if (flat.isEmpty) throw Exception('No chapters in EPUB');

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
        wordCount: text.split(RegExp(r'\s+')).length,
      ));
      index++;
    }

    if (results.isEmpty) throw Exception('No readable content in EPUB');
    return results;
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final flat = <EpubChapter>[];
    for (final ch in chapters) {
      flat.add(ch);
      flat.addAll(_flattenChapters(ch.subChapters));
    }
    return flat;
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

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;
    throw Exception('Public Domain Library chapters are only available in batch.');
  }
}
