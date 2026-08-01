import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';

class MvlempyrSource implements SourceAdapter {
  MvlempyrSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _domain = 'www.mvlempyr.io';
  static const _wpDomain = 'chap.heliosarchive.online';
  static const _assetsDomain = 'assets.mvlempyr.app';
  static const _wpTagMod = 1999999997;
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  @override
  String get sourceName => 'MVLEMPYR';

  @override
  ContentCategory get contentCategory => ContentCategory.novel;

  @override
  bool canHandle(Uri uri) {
    return uri.host == _domain ||
        uri.host == 'mvlempyr.io' ||
        uri.host == _wpDomain;
  }

  Map<String, String> get _headers => {'User-Agent': _userAgent};

  @override
  Future<NovelModel> getMetadata(Uri uri) async {
    final targetUri = uri.path.startsWith('/chapter/')
        ? await _novelUriFromChapter(uri)
        : uri;

    final response = await _client.get(targetUri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'MVLEMPYR: Failed to fetch novel page: ${response.statusCode}');
    }
    final html = response.body;
    _checkCloudflare(html);

    final novelCode =
        _extract(html, RegExp(r'id="novel-code">\s*(\d+)')) ?? '';
    final slug = targetUri.pathSegments.last;

    var title = _extract(
      html,
      RegExp(r'<h1[^>]*class="[^"]*novel-title[^"]*"[^>]*>\s*([^<]+)'),
    );
    var author =
        _extract(html, RegExp(r'class="fieldtext">Author:</div>\s*<div>([^<]+)</div>'));
    final descriptionHtml = _extract(
      html,
      RegExp(r'<div[^>]*class="[^"]*synopsis[^"]*w-richtext[^"]*"[^>]*>([\s\S]*?)</div>'),
    );
    var description =
        descriptionHtml != null ? _htmlToText(descriptionHtml) : null;
    if (description == null || description.isEmpty) {
      description = _extract(
        html,
        RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]*)"'),
      );
    }
    var status =
        _extract(html, RegExp(r'class="novelstatustextlarge">\s*([^<]+)'));
    final coverUrl = _extract(
      html,
      RegExp(r'<img[^>]*src="([^"]+)"[^>]*class="[^"]*novel-image[^"]*"'),
    );
    final genres = RegExp(r'class="genre-tags">\s*([^<]+)')
        .allMatches(html)
        .map((m) => m.group(1)!.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    double? rating;
    int? chapterCount;
    DateTime? lastUpdated;

    final rest = await _fetchNovelBySlug(slug);
    if (rest != null) {
      final restTitle = rest['name'] as String?;
      final restAuthor = rest['author-name'] as String?;
      final restDescription = rest['synopsis-text'] as String?;
      final restStatus = rest['status'] as String?;
      final restGenres = rest['genre'];
      final avg = rest['average-review'];
      final total = rest['total-chapters'];
      final created = rest['createdOn'];

      rating = avg is num ? avg.toDouble() : null;
      chapterCount = total is num ? total.toInt() : null;
      lastUpdated = created is String ? DateTime.tryParse(created) : null;
      if (title == null && restTitle != null && restTitle.isNotEmpty) {
        title = restTitle;
      }
      if (author == null && restAuthor != null && restAuthor.isNotEmpty) {
        author = restAuthor;
      }
      if (description == null &&
          restDescription != null &&
          restDescription.isNotEmpty) {
        description = restDescription;
      }
      if (status == null && restStatus != null && restStatus.isNotEmpty) {
        status = restStatus;
      }
      if (genres.isEmpty && restGenres is List) {
        genres.addAll(restGenres.cast<String>());
      }
    }

    return NovelModel(
      sourceId: novelCode.isNotEmpty ? novelCode : _fallbackId(uri),
      title: title?.trim() ?? 'Untitled',
      author: author,
      description: description,
      coverUrl: coverUrl ??
          (novelCode.isNotEmpty
              ? 'https://$_assetsDomain/images/900/$novelCode.webp'
              : null),
      genres: genres,
      status: status,
      rating: rating,
      source: sourceName,
      sourceUrl: 'https://$_domain/novel/$slug',
      category: ContentCategory.novel,
      chapterCount: chapterCount ?? 0,
      lastUpdated: lastUpdated,
    );
  }

  @override
  Future<List<ChapterModel>> getChapters(NovelModel novel) async {
    final chapters = await _fetchChaptersFromPosts(novel.sourceId);
    if (chapters == null) {
      return _buildFallbackChapters(novel);
    }

    for (var i = 0; i < chapters.length && i < 2; i++) {
      try {
        chapters[i] = await getChapter(chapters[i]);
      } catch (_) {}
    }
    return chapters;
  }

  @override
  Future<ChapterModel> getChapter(ChapterModel chapter) async {
    if (chapter.content != null) return chapter;

    final uri = Uri.parse(chapter.contentUrl!);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'MVLEMPYR: Failed to fetch chapter: ${response.statusCode}');
    }

    final html = response.body;
    _checkCloudflare(html);

    final chapterTitle = _extractChapterTitle(html) ?? chapter.title;
    final text = _extractChapterText(html);

    return ChapterModel(
      id: chapter.id,
      title: chapterTitle,
      index: chapter.index,
      contentUrl: chapter.contentUrl,
      content: text,
      wordCount: max(1, text.split(RegExp(r'\s+')).length),
      publishedAt: chapter.publishedAt,
    );
  }

  Future<List<ChapterModel>?> _fetchChaptersFromPosts(String novelCode) async {
    final code = int.tryParse(novelCode);
    if (code == null) return null;

    try {
      final tagId = _modPow(7, code, _wpTagMod);
      final posts = <Map<String, dynamic>>[];
      var page = 1;
      var totalPages = 1;

      while (page <= totalPages) {
        final uri = Uri.https(_wpDomain, '/wp-json/wp/v2/posts', {
          'tags': '$tagId',
          'per_page': '500',
          'page': '$page',
        });
        final response = await _client.get(uri, headers: _headers);
        if (response.statusCode != 200) break;
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) break;
        posts.addAll(data.cast<Map<String, dynamic>>());
        totalPages =
            int.tryParse(response.headers['x-wp-totalpages'] ?? '') ?? page;
        page++;
      }

      if (posts.isEmpty) return null;

      final chapters = <ChapterModel>[];
      for (final post in posts) {
        final acf = post['acf'];
        if (acf is! Map) continue;
        final rawNumber = acf['chapter_number'];
        if (rawNumber is! num || rawNumber.toInt() <= 0) continue;
        final number = rawNumber.toInt();
        final postCode = acf['novel_code']?.toString() ?? novelCode;
        final chName = acf['ch_name'] as String?;
        final date = post['date'] as String?;

        chapters.add(ChapterModel(
          id: '${postCode}_ch$number',
          title: chName ?? 'Chapter $number',
          index: number - 1,
          contentUrl: 'https://$_domain/chapter/$postCode-$number',
          publishedAt: date != null ? DateTime.tryParse(date) : null,
        ));
      }

      chapters.sort((a, b) => a.index.compareTo(b.index));
      return chapters.isEmpty ? null : chapters;
    } catch (_) {
      return null;
    }
  }

  Future<List<ChapterModel>> _buildFallbackChapters(NovelModel novel) async {
    final totalChapters = await _getTotalChapters(novel);
    final chapters = <ChapterModel>[];

    for (var i = 1; i <= totalChapters; i++) {
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

  Future<Map<String, dynamic>?> _fetchNovelBySlug(String slug) async {
    if (slug.isEmpty) return null;
    try {
      final uri = Uri.https(
        _wpDomain,
        '/wp-json/wp/v2/mvl-novels',
        {'slug': slug},
      );
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) return null;
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty || data[0] is! Map) return null;
      return data[0] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Uri> _novelUriFromChapter(Uri chapterUri) async {
    final response = await _client.get(chapterUri, headers: _headers);
    if (response.statusCode != 200) return chapterUri;

    final novelLink =
        RegExp(r'href="(/novel/[^"]+)"').firstMatch(response.body);
    if (novelLink != null) {
      final path = novelLink.group(1)!;
      return Uri.parse('https://$_domain$path');
    }
    return chapterUri;
  }

  Future<int> _getTotalChapters(NovelModel novel) async {
    final slug = novel.sourceUrl.split('/').last;
    if (slug.isEmpty) return _findLastChapter(novel.sourceId);

    final rest = await _fetchNovelBySlug(slug);
    if (rest != null) {
      final total = rest['total-chapters'];
      if (total is num && total.toInt() > 0) return total.toInt();
    }

    return _findLastChapter(novel.sourceId);
  }

  Future<int> _findLastChapter(String novelId) async {
    const maxChapters = 10000;
    int low = 1;
    int high = 1;

    while (high <= maxChapters) {
      final uri = Uri.parse('https://$_domain/chapter/$novelId-$high');
      try {
        final response = await _client.get(uri, headers: _headers);
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
        final response = await _client.get(
          Uri.parse('https://$_domain/chapter/$novelId-$mid'),
          headers: _headers,
        );
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
    final spanMatch = RegExp(
      r'<h2[^>]*id="chapter-name"[^>]*>[\s\S]*?<span[^>]*>([\s\S]*?)</span>',
    ).firstMatch(html);
    final title = spanMatch?.group(1)?.trim();
    if (title != null && title.isNotEmpty) return title;

    final legacyMatch = RegExp(
      r'<h[12][^>]*>\s*Chapter\s+\d+\s*(.*?)</h[12]>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final suffix = legacyMatch?.group(1)?.trim();
    if (suffix != null && suffix.isNotEmpty) {
      return 'Chapter ${_chapterNumber(html)} $suffix';
    }
    return null;
  }

  String _chapterNumber(String html) {
    final m = RegExp(r'/chapter/\d+-(\d+)').firstMatch(html);
    return m?.group(1) ?? '?';
  }

  String _extractChapterText(String html) {
    final spanMatch = RegExp(
      r'<span[^>]*class="[^"]*oxy-stock-content-styles[^"]*"[^>]*>([\s\S]*?)</span>',
    ).firstMatch(html);
    final body = spanMatch?.group(1);

    if (body == null || body.trim().isEmpty) {
      throw Exception('MVLEMPYR: chapter content not found');
    }

    return _htmlToText(body);
  }

  String _htmlToText(String html) {
    var text = html
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&rsquo;', '\u2019')
        .replaceAll('&lsquo;', '\u2018')
        .replaceAll('&ldquo;', '\u201C')
        .replaceAll('&rdquo;', '\u201D')
        .replaceAll('&hellip;', '\u2026')
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
            (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
        .replaceAllMapped(RegExp(r'&#(\d+);'),
            (m) => String.fromCharCode(int.parse(m.group(1)!)));

    final lines = text.split('\n').map((l) => l.trim()).toList();
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  void _checkCloudflare(String html) {
    final titleMatch = RegExp(r'<title>\s*([^<]*)').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '';
    if (title == 'Attention Required! | Cloudflare' ||
        title == 'Just a moment...') {
      throw Exception('MVLEMPYR: Cloudflare challenge detected, please retry');
    }
  }

  int _modPow(int base, int exp, int mod) {
    var result = 1 % mod;
    var b = base % mod;
    var e = exp;
    while (e > 0) {
      if (e.isOdd) result = (result * b) % mod;
      b = (b * b) % mod;
      e >>= 1;
    }
    return result;
  }

  String _fallbackId(Uri uri) =>
      '${DateTime.now().millisecondsSinceEpoch}_${uri.pathSegments.last}';

  String? _extract(String html, RegExp pattern) {
    final match = pattern.firstMatch(html);
    return match?.group(1)?.trim();
  }
}
