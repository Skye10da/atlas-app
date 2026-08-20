import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:epub_plus/epub_plus.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class GutenbergSource implements SearchableSource {
  GutenbergSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get sourceName => 'Project Gutenberg';

  @override
  ContentCategory get contentCategory => ContentCategory.book;

  static const _gutendexBase = 'https://gutendex.com';
  static const _textBase = 'https://www.gutenberg.org/cache/epub';
  static const _gutenbergRoot = 'https://www.gutenberg.org/ebooks';

  @override
  bool canHandle(Uri uri) {
    return uri.host == 'www.gutenberg.org' || uri.host == 'gutenberg.org';
  }

  int _extractId(Uri uri) {
    final ebookMatch = RegExp(r'/ebooks/(\d+)').firstMatch(uri.path);
    if (ebookMatch != null) return int.parse(ebookMatch.group(1)!);
    final cacheMatch = RegExp(r'/epub/(\d+)').firstMatch(uri.path);
    if (cacheMatch != null) return int.parse(cacheMatch.group(1)!);
    throw ArgumentError('Could not extract Gutenberg book ID from: $uri');
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final bookId = _extractId(uri);
    final response = await _client.get(
      Uri.parse('$_gutendexBase/books/$bookId'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Gutenberg API returned ${response.statusCode} for book $bookId',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final novel = _parseBook(json, bookId);

    if (novel.coverBytes == null && novel.fileFormat == 'epub') {
      try {
        final epubResponse = await _client.get(Uri.parse(novel.sourceUrl));
        if (epubResponse.statusCode == 200) {
          final book = await _readEpubInIsolate(epubResponse.bodyBytes);
          final coverBytes = _extractCoverBytes(book);
          if (coverBytes != null) {
            return novel.copyWith(coverBytes: coverBytes);
          }
        }
      } catch (_) {}
    }

    return novel;
  }

  NovelModel _parseBook(Map<String, dynamic> json, int bookId) {
    final title = json['title'] as String? ?? 'Untitled';
    final authors = json['authors'] as List<dynamic>? ?? [];
    final author = authors.isNotEmpty
        ? (authors[0] as Map)['name'] as String?
        : null;
    final subjects = json['subjects'] as List<dynamic>? ?? [];
    final genres = subjects
        .map((s) => s.toString())
        .where((s) => s.contains('--'))
        .map((s) => s.split(' -- ').last.trim())
        .toList();
    final lang = (json['languages'] as List<dynamic>?)?.firstOrNull?.toString();
    final downloads = json['download_count'] as int?;
    final formats = json['formats'] as Map<String, dynamic>? ?? {};
    final coverUrl = formats['image/jpeg'] as String?;

    final epubUrl = formats['application/epub+zip'] as String?;
    final textUrl =
        formats['text/plain; charset=us-ascii'] as String? ??
        formats['text/plain; charset=utf-8'] as String? ??
        '$_textBase/$bookId/pg$bookId.txt';
    final sourceUrl = epubUrl ?? textUrl;

    return NovelModel(
      sourceId: bookId.toString(),
      title: title,
      author: author,
      coverUrl: coverUrl,
      language: lang,
      genres: genres,
      source: sourceName,
      sourceUrl: sourceUrl,
      fileFormat: epubUrl != null ? 'epub' : 'text',
      chapterCount: 0,
      lastUpdated: downloads != null
          ? DateTime.fromMillisecondsSinceEpoch(downloads)
          : null,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    if (novel.fileFormat == 'epub') {
      try {
        return await _getChaptersFromEpub(novel);
      } catch (_) {}
    }

    var text = await _fetchText(novel.sourceUrl, novel.sourceId);
    if (text == null) {
      return [
        ChapterModel(
          id: '${novel.sourceId}_ch0',
          title: novel.title,
          index: 0,
          contentUrl: novel.sourceUrl,
        ),
      ];
    }

    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final stripped = _stripGutenbergWrapper(text);
    final sections = _splitChapters(stripped);

    if (sections.isEmpty) {
      final wordCount = stripped.split(RegExp(r'\s+')).length;
      return [
        ChapterModel(
          id: '${novel.sourceId}_ch0',
          title: novel.title,
          index: 0,
          content: stripped,
          contentUrl: novel.sourceUrl,
          wordCount: wordCount,
        ),
      ];
    }

    return sections.asMap().entries.map((e) {
      final i = e.key;
      final s = e.value;
      return ChapterModel(
        id: '${novel.sourceId}_ch$i',
        title: s.title,
        index: i,
        content: s.content,
        contentUrl: novel.sourceUrl,
        wordCount: s.content.split(RegExp(r'\s+')).length,
      );
    }).toList();
  }

  Future<List<ChapterModel>> _getChaptersFromEpub(NovelModel novel) async {
    final response = await _client.get(Uri.parse(novel.sourceUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download EPUB: ${response.statusCode}');
    }
    final book = await _readEpubInIsolate(response.bodyBytes);
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
      results.add(
        ChapterModel(
          id: '${novel.sourceId}_ch$index',
          title: chTitle,
          index: index,
          content: text,
          contentUrl: novel.sourceUrl,
          wordCount: text.split(RegExp(r'\s+')).length,
        ),
      );
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
        .replaceAll(
          RegExp(r'<head>.*?</head>', dotAll: true, caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'<script.*?>.*?</script>',
            dotAll: true,
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'<style.*?>.*?</style>', dotAll: true, caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String?> _fetchText(String sourceUrl, String sourceId) async {
    final urls = [
      sourceUrl,
      '$_textBase/$sourceId/pg$sourceId.txt',
      '$_textBase/$sourceId/pg$sourceId.txt.utf-8',
    ];

    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final response = await _client.get(uri);
        if (response.statusCode == 200) return response.body;
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;

    final uri = Uri.parse(chapter.contentUrl!);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chapter: ${response.statusCode}');
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

  Uint8List? _extractCoverBytes(EpubBook book) {
    final manifest = book.schema?.package?.manifest;
    final items = manifest?.items ?? [];
    final metaItems = book.schema?.package?.metadata?.metaItems ?? [];

    EpubManifestItem? coverItem;
    for (final item in items) {
      if (item.id?.toLowerCase() == 'cover-image') {
        coverItem = item;
        break;
      }
    }
    if (coverItem == null) {
      for (final meta in metaItems) {
        if (meta.name?.toLowerCase() == 'cover' && meta.content != null) {
          final cid = meta.content!.toLowerCase();
          for (final item in items) {
            if (item.id?.toLowerCase() == cid) {
              coverItem = item;
              break;
            }
          }
          if (coverItem != null) break;
        }
      }
    }
    if (coverItem == null) {
      for (final item in items) {
        if ((item.properties ?? '').toLowerCase().contains('cover-image')) {
          coverItem = item;
          break;
        }
      }
    }
    if (coverItem?.href == null) return null;
    final href = coverItem!.href!;
    final imageFile = book.content?.images[href];
    final bytes = imageFile?.content;
    return bytes != null ? Uint8List.fromList(bytes) : null;
  }

  String _stripGutenbergWrapper(String text) {
    final startPattern = RegExp(
      r'^\*\*\*\s*START OF (THE|THIS)\s+PROJECT GUTENBERG',
      multiLine: true,
      caseSensitive: false,
    );
    final endPattern = RegExp(
      r'^\*\*\*\s*END OF (THE|THIS)\s+PROJECT GUTENBERG',
      multiLine: true,
      caseSensitive: false,
    );

    var stripped = text;
    final startMatch = startPattern.firstMatch(stripped);
    if (startMatch != null) {
      stripped = stripped.substring(startMatch.end).trimLeft();
    }
    final endMatch = endPattern.firstMatch(stripped);
    if (endMatch != null) {
      stripped = stripped.substring(0, endMatch.start).trimRight();
    }
    return stripped;
  }

  List<_ChapterSection> _splitChapters(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'^[ \t]*(CHAPTER|Chapter|Chapitre|Capítulo|Kapitel)\s+\w+',
        multiLine: true,
      ),
      RegExp(
        r'^[ \t]*(CHAPTER|Chapter)\s+(THE\s+)?[IVXLCDM]+\b',
        multiLine: true,
        caseSensitive: false,
      ),
      RegExp(
        r'^[ \t]*(CHAPTER|Chapter)\s+(THE\s+)?(One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|'
        r'Eleven|Twelve|Thirteen|Fourteen|Fifteen|Sixteen|Seventeen|Eighteen|Nineteen|Twenty)\b',
        multiLine: true,
        caseSensitive: false,
      ),
      RegExp(
        r'^[ \t]*(CHAPTER|Chapter)\s+\d+',
        multiLine: true,
        caseSensitive: false,
      ),
    ];

    final matches = <RegExpMatch>[];
    final seen = <int>{};
    for (final pattern in patterns) {
      for (final m in pattern.allMatches(text)) {
        if (seen.add(m.start)) {
          matches.add(m);
        }
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));
    if (matches.length < 2) {
      final broad = RegExp(
        r'^[ \t]*(CHAPTER|Chapter|Ch\.|§)\s*\w+',
        multiLine: true,
        caseSensitive: false,
      );
      for (final m in broad.allMatches(text)) {
        if (seen.add(m.start)) {
          matches.add(m);
        }
      }
      matches.sort((a, b) => a.start.compareTo(b.start));
      if (matches.length < 2) return [];
    }

    final sections = <_ChapterSection>[];
    for (int i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : text.length;
      final content = text.substring(start, end).trim();

      final titleLineEnd = content.indexOf('\n');
      final title = titleLineEnd > 0
          ? content.substring(0, titleLineEnd).trim()
          : matches[i].group(0)!.trim();
      final body = titleLineEnd > 0
          ? content.substring(titleLineEnd).trim()
          : '';

      sections.add(_ChapterSection(title: title, content: body));
    }
    return sections;
  }

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async {
    final uri = Uri.parse('$_gutendexBase/books').replace(
      queryParameters: {'search': query.term, 'page': query.page.toString()},
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gutenberg search failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final books = json['results'] as List<dynamic>? ?? [];
    final next = json['next'] as String?;

    final results = books.map((b) {
      final book = b as Map<String, dynamic>;
      final id = book['id'] as int;
      final authors = book['authors'] as List<dynamic>? ?? [];
      final author = authors.isNotEmpty
          ? (authors[0] as Map)['name'] as String?
          : null;
      final formats = book['formats'] as Map<String, dynamic>? ?? {};
      final coverUrl = formats['image/jpeg'] as String?;
      final subjects = book['subjects'] as List<dynamic>? ?? [];
      final desc = subjects.isNotEmpty
          ? subjects.take(3).map((s) => s.toString()).join(', ')
          : null;

      return SourceSearchResult(
        id: id.toString(),
        title: book['title'] as String? ?? 'Untitled',
        author: author,
        coverUrl: coverUrl,
        description: desc,
        importUrl: '$_gutenbergRoot/$id',
      );
    }).toList();

    return SourceSearchResponse(
      results: results,
      nextPage: next != null ? query.page + 1 : null,
    );
  }
}

class _ChapterSection {
  _ChapterSection({required this.title, required this.content});
  final String title;
  final String content;
}

Future<EpubBook> _readEpubInIsolate(List<int> bytes) =>
    Isolate.run(() => EpubReader.readBook(bytes));
