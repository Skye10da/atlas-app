import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/searchable_source.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';

class OpenLibrarySource implements SearchableSource {
  OpenLibrarySource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://openlibrary.org';
  static const _iaTextBase = 'https://archive.org/stream';
  static const _coverBase = 'https://covers.openlibrary.org/b/id';

  @override
  String get sourceName => 'Open Library';

  @override
  bool canHandle(Uri uri) {
    return uri.host == 'openlibrary.org' || uri.host == 'www.openlibrary.org';
  }

  String? _extractWorkKey(Uri uri) {
    final match = RegExp(r'/works/(OL\d+\w*)').firstMatch(uri.path);
    return match?.group(1);
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final workKey = _extractWorkKey(uri);
    if (workKey == null) throw Exception('Could not extract work key from: $uri');

    final workJson = await _fetchJson('$_baseUrl/works/$workKey.json');

    final title = workJson['title'] as String? ?? 'Untitled';

    String? description;
    final desc = workJson['description'];
    if (desc is String) {
      description = desc;
    } else if (desc is Map) {
      description = desc['value'] as String?;
    }

    final subjects = (workJson['subjects'] as List<dynamic>?)?.cast<String>() ?? [];
    final covers = (workJson['covers'] as List<dynamic>?) ?? [];
    final coverId = covers.isNotEmpty ? covers.first : null;

    String? author;
    final authors = workJson['authors'] as List<dynamic>? ?? [];
    if (authors.isNotEmpty) {
      final first = authors.first;
      if (first is Map) {
        final authorRef = first['author'] as Map?;
        final authorKey = authorRef?['key'] as String?;
        if (authorKey != null) {
          try {
            final authorJson = await _fetchJson('$_baseUrl$authorKey.json');
            author = authorJson['name'] as String?;
          } catch (_) {}
        }
      }
    }

    String? iaId;
    final iaParam = uri.queryParameters['ia'];
    if (iaParam != null && iaParam.isNotEmpty) {
      iaId = iaParam;
    } else {
      try {
        final editionsJson = await _fetchJson('$_baseUrl/works/$workKey/editions.json?limit=10');
        final entries = editionsJson['entries'] as List<dynamic>? ?? [];
        for (final entry in entries) {
          if (entry is Map) {
            final ia = entry['ia'] as String?;
            if (ia != null && ia.isNotEmpty) {
              iaId = ia;
              break;
            }
          }
        }
      } catch (_) {}
    }

    final coverUrl = coverId != null ? '$_coverBase/$coverId-M.jpg' : null;
    final sourceUrl = iaId != null ? '$_iaTextBase/$iaId/${iaId}_djvu.txt' : uri.toString();

    return NovelModel(
      sourceId: workKey,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      genres: subjects,
      source: sourceName,
      sourceUrl: sourceUrl,
      fileFormat: 'text',
      chapterCount: 0,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    if (!novel.sourceUrl.contains('archive.org')) {
      throw ImportRedirect('$_baseUrl/works/${novel.sourceId}');
    }

    final response = await _client.get(Uri.parse(novel.sourceUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download full text: ${response.statusCode}');
    }

    var text = response.body;
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final sections = _splitChapters(text);

    if (sections.isEmpty) {
      final wordCount = text.split(RegExp(r'\s+')).length;
      return [
        ChapterModel(
          id: '${novel.sourceId}_ch0',
          title: novel.title,
          index: 0,
          content: text,
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
        wordCount: s.content.split(RegExp(r'\s+')).length,
      );
    }).toList();
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;
    throw Exception('Open Library chapters are only available in batch.');
  }

  @override
  Future<SourceSearchResponse> search(SourceSearchQuery query) async {
    final uri = Uri.parse('$_baseUrl/search.json').replace(
      queryParameters: {
        'q': query.term,
        'page': query.page.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Open Library search failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = json['docs'] as List<dynamic>? ?? [];
    final numFound = json['numFound'] as int? ?? 0;
    final pageSize = query.pageSize;

    final results = <SourceSearchResult>[];
    for (final d in docs) {
      final doc = d as Map<String, dynamic>;

      final key = doc['key'] as String?;
      if (key == null) continue;

      final title = doc['title'] as String? ?? 'Untitled';
      final authors = doc['author_name'] as List<dynamic>? ?? [];
      final author = authors.isNotEmpty ? authors.first.toString() : null;
      final coverI = doc['cover_i'] as int?;
      final coverUrl = coverI != null ? '$_coverBase/$coverI-M.jpg' : null;

      final iaList = doc['ia'] as List<dynamic>?;
      final hasFullText = iaList != null && iaList.isNotEmpty;
      final iaId = hasFullText ? iaList.first.toString() : null;

      final firstPublishYear = doc['first_publish_year'] as int?;
      final descParts = <String>[];
      if (firstPublishYear != null) descParts.add('First published $firstPublishYear');
      descParts.add(hasFullText ? 'Full text available' : 'Browse on Open Library');
      final description = descParts.join(' · ');

      final importUrl = hasFullText ? '$_baseUrl$key?ia=$iaId' : '$_baseUrl$key';
      results.add(SourceSearchResult(
        id: key,
        title: title,
        author: author,
        coverUrl: coverUrl,
        description: description,
        importUrl: importUrl,
        language: doc['language'] is List ? (doc['language'] as List).firstOrNull?.toString() : null,
      ));
    }

    final totalPages = (numFound / pageSize).ceil();
    final nextPage = query.page < totalPages ? query.page + 1 : null;

    return SourceSearchResponse(
      results: results,
      totalCount: numFound,
      nextPage: nextPage,
    );
  }

  Future<Map<String, dynamic>> _fetchJson(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Open Library API returned ${response.statusCode} for $url');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<_ChapterSection> _splitChapters(String text) {
    final patterns = <RegExp>[
      RegExp(r'^[ \t]*(CHAPTER|Chapter|Chapitre|Capítulo|Kapitel)\s+\w+', multiLine: true),
      RegExp(r'^[ \t]*(CHAPTER|Chapter)\s+(THE\s+)?[IVXLCDM]+\b', multiLine: true, caseSensitive: false),
      RegExp(r'^[ \t]*(CHAPTER|Chapter)\s+\d+', multiLine: true, caseSensitive: false),
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
      final broad = RegExp(r'^[ \t]*(CHAPTER|Chapter|Ch\.|§)\s*\w+', multiLine: true, caseSensitive: false);
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
      final body = titleLineEnd > 0 ? content.substring(titleLineEnd).trim() : '';

      sections.add(_ChapterSection(title: title, content: body));
    }
    return sections;
  }
}

class _ChapterSection {
  _ChapterSection({required this.title, required this.content});
  final String title;
  final String content;
}
