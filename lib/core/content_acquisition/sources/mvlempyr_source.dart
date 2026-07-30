import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class MvlempyrSource implements SourceAdapter {
  MvlempyrSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _domain = 'www.mvlempyr.io';

  @override
  String get sourceName => 'MVLEMPYR';

  @override
  bool canHandle(Uri uri) {
    return uri.host == _domain || uri.host == 'mvlempyr.io';
  }

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final targetUri = uri.path.startsWith('/chapter/')
        ? await _novelUriFromChapter(uri)
        : uri;

    final response = await _client.get(targetUri);
    if (response.statusCode != 200) {
      throw Exception('MVLEMPYR: Failed to fetch novel page: ${response.statusCode}');
    }
    final html = response.body;

    final novelId = _extract(html, RegExp(r'/images/\d+/(\d+)\.webp')) ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final titleMatch = RegExp(r'<title>\s*([^|]+)').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? 'Untitled';

    final author = _extract(html, RegExp(r'Author:\s*</[^>]+>\s*<[^>]+>\s*([^<]+)'));

    final coverMatch =
        RegExp(r'<img[^>]+src="([^"]+/900/\d+\.webp)"').firstMatch(html);
    final coverUrl = coverMatch?.group(1);

    final descMatch = RegExp(
      r'Synopsis[^<]*</div>\s*<div[^>]*>\s*([\s\S]*?)\s*</div>',
    ).firstMatch(html);
    final description = descMatch?.group(1)?.trim();

    final genres = RegExp(r'href="/genre/([^"/]+)"')
        .allMatches(html)
        .map((m) => m.group(1)!)
        .where((g) => g.isNotEmpty)
        .toList();

    final statusMatch =
        RegExp(r'\b(Ongoing|Completed|Hiatus|Dropped)\b', caseSensitive: false)
            .firstMatch(html);
    final status = statusMatch?.group(1);

    final ratingMatch = RegExp(r'(\d+(?:\.\d+)?)\s*/\s*5').firstMatch(html);
    final rating =
        ratingMatch != null ? double.tryParse(ratingMatch.group(1)!) : null;

    final slug = targetUri.pathSegments.last;

    return NovelModel(
      sourceId: novelId,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      genres: genres,
      status: status,
      rating: rating,
      source: sourceName,
      sourceUrl: 'https://$_domain/novel/$slug',
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    final totalChapters = await _getTotalChapters(novel);
    final chapters = <ChapterModel>[];

    for (int i = 1; i <= totalChapters; i++) {
      final chapter = ChapterModel(
        id: '${novel.sourceId}_ch$i',
        title: 'Chapter $i',
        index: i - 1,
        contentUrl: 'https://$_domain/chapter/${novel.sourceId}-$i',
      );

      if (i <= 2) {
        try {
          chapters.add(await getChapter(chapter));
        } catch (_) {
          chapters.add(chapter);
        }
      } else {
        chapters.add(chapter);
      }
    }

    return chapters;
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;

    final uri = Uri.parse(chapter.contentUrl!);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('MVLEMPYR: Failed to fetch chapter: ${response.statusCode}');
    }

    final html = response.body;
    final chapterTitle = _extractChapterTitle(html) ?? chapter.title;
    final text = _extractChapterText(html);

    return ChapterModel(
      id: chapter.id,
      title: chapterTitle,
      index: chapter.index,
      contentUrl: chapter.contentUrl,
      content: text,
      wordCount: max(1, text.split(RegExp(r'\s+')).length),
    );
  }

  Future<Uri> _novelUriFromChapter(Uri chapterUri) async {
    final response = await _client.get(chapterUri);
    if (response.statusCode != 200) return chapterUri;

    final novelLink = RegExp(r'href="(/novel/[^"]+)"').firstMatch(response.body);
    if (novelLink != null) {
      final path = novelLink.group(1)!;
      return Uri.parse('https://$_domain$path');
    }
    return chapterUri;
  }

  Future<int> _getTotalChapters(NovelModel novel) async {
    final slug = novel.sourceUrl.split('/').last;
    if (slug.isEmpty) return _findLastChapter(novel.sourceId);

    try {
      final uri = Uri.https(
        'chap.heliosarchive.online',
        '/wp-json/wp/v2/mvl-novels',
        {'slug': slug},
      );
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['total-chapters'] is int) {
          return data[0]['total-chapters'] as int;
        }
      }
    } catch (_) {}

    return _findLastChapter(novel.sourceId);
  }

  Future<int> _findLastChapter(String novelId) async {
    const maxChapters = 10000;
    int low = 1;
    int high = 1;

    while (high <= maxChapters) {
      final uri = Uri.parse('https://$_domain/chapter/$novelId-$high');
      try {
        final response = await _client.get(uri);
        if (response.statusCode == 404) break;
        low = high;
        high *= 2;
      } catch (_) {
        break;
      }
    }

    if (high > maxChapters) high = maxChapters;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      try {
        final response =
            await _client.get(Uri.parse('https://$_domain/chapter/$novelId-$mid'));
        if (response.statusCode == 200) {
          low = mid;
        } else {
          high = mid - 1;
        }
      } catch (_) {
        high = mid - 1;
      }
    }

    return low;
  }

  String? _extractChapterTitle(String html) {
    final match = RegExp(
      r'<h[12][^>]*>\s*Chapter\s+\d+\s*(.*?)</h[12]>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    final suffix = match.group(1)?.trim();
    if (suffix != null && suffix.isNotEmpty) return 'Chapter ${_chapterNumber(html)} $suffix';
    return null;
  }

  String _chapterNumber(String html) {
    final m = RegExp(r'/chapter/\d+-(\d+)').firstMatch(html);
    return m?.group(1) ?? '?';
  }

  String _extractChapterText(String html) {
    var cleaned = html;

    cleaned = cleaned.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<nav[^>]*>[\s\S]*?</nav>', caseSensitive: false),
      '',
    );

    final entryMatch = RegExp(
      r'<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (entryMatch != null) {
      return _stripHtml(entryMatch.group(1)!);
    }

    final h2Match = RegExp(
      r'<h[12][^>]*>.*?</h[12]>\s*([\s\S]*?)(?:<div[^>]*class="[^"]*(?:nav|comment|ad|related)[^"]*"|<footer|</article)',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (h2Match != null) {
      return _stripHtml(h2Match.group(1)!);
    }

    final startIdx = cleaned.indexOf('<h2');
    if (startIdx >= 0) {
      final closeH2 = cleaned.indexOf('</h2>', startIdx);
      if (closeH2 >= 0) {
        final afterH2 = cleaned.substring(closeH2 + 5);
        final nextIdx =
            afterH2.indexOf('<h2');
        final contentEnd =
            nextIdx >= 0 ? closeH2 + 5 + nextIdx : cleaned.length;
        return _stripHtml(cleaned.substring(closeH2 + 5, contentEnd));
      }
    }

    return _stripHtml(cleaned);
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extract(String html, RegExp pattern) {
    final match = pattern.firstMatch(html);
    return match?.group(1)?.trim();
  }
}
