import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/templates/wordpress_api_template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Template for MVLEMPYR (www.mvlempyr.io), built on [WordPressApiTemplate].
///
/// The site's front-end is built with Oxygen while novel data lives in a
/// WordPress REST backend on a separate host, so neither generic selectors
/// ([HtmlTemplate]) nor the plain WordPress API template can extract content
/// as-is. This subclasses [WordPressApiTemplate] to reuse its REST URI
/// machinery, overrides [restOrigin] to point at the backend host, and keeps
/// the bespoke feed/metadata logic that previously lived in the hardcoded
/// `MvlempyrSource`, expressed against the plugin [Transport] and the shared
/// clean → normalize pipeline.
class MvlempyrTemplate extends WordPressApiTemplate {
  const MvlempyrTemplate();

  static const _domain = 'www.mvlempyr.io';
  static const _wpDomain = 'chap.heliosarchive.online';
  static const _assetsDomain = 'assets.mvlempyr.app';
  static const _wpTagMod = 1999999997;
  static const _perPage = 500;

  @override
  String get templateId => 'mvlempyr';

  /// The novel data backend is on a different host than the public site.
  @override
  String restOrigin(PluginManifest plugin) => 'https://$_wpDomain';

  /// Search is not declared: the site exposes no search endpoint the template
  /// can drive, so plugins targeting it must omit the `search` capability.
  @override
  Set<PluginCapability> get supportedCapabilities => const {
    PluginCapability.chapterList,
    PluginCapability.chapterContent,
    PluginCapability.cover,
  };

  @override
  Future<List<SearchResult>> search(PluginContext context, String query) async {
    throw const PluginCapabilityException(
      PluginCapability.search,
      'MVLEMPYR does not expose site search',
    );
  }

  @override
  Future<NovelMetadata> metadata(PluginContext context, String novelUrl) async {
    final uri = Uri.parse(novelUrl);
    final targetUri = uri.path.startsWith('/chapter/')
        ? await _novelUriFromChapter(context, uri)
        : uri;
    final html = await context.transport.fetchHtml(
      targetUri,
      headers: context.plugin.requestHeaders,
    );
    _checkCloudflare(html);

    final novelCode = _extract(html, RegExp(r'id="novel-code">\s*(\d+)')) ?? '';
    final slug = targetUri.pathSegments.last;

    var title = _extract(
      html,
      RegExp(r'<h1[^>]*class="[^"]*novel-title[^"]*"[^>]*>\s*([^<]+)'),
    );
    var author = _extract(
      html,
      RegExp(r'class="fieldtext">Author:</div>\s*<div>([^<]+)</div>'),
    );
    final descriptionHtml = _extract(
      html,
      RegExp(
        r'<div[^>]*class="[^"]*synopsis[^"]*w-richtext[^"]*"[^>]*>([\s\S]*?)</div>',
      ),
    );
    var description = descriptionHtml != null
        ? _htmlToText(descriptionHtml)
        : null;
    if (description == null || description.isEmpty) {
      description = _extract(
        html,
        RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]*)"'),
      );
    }
    var status = _extract(
      html,
      RegExp(r'class="novelstatustextlarge">\s*([^<]+)'),
    );
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

    final rest = await _fetchNovelBySlug(context, slug);
    if (rest != null) {
      final avg = rest['average-review'];
      final total = rest['total-chapters'];
      final created = rest['createdOn'];
      rating = avg is num ? avg.toDouble() : null;
      chapterCount = total is num ? total.toInt() : null;
      lastUpdated = created is String ? DateTime.tryParse(created) : null;
      title ??= rest['name'] as String?;
      author ??= rest['author-name'] as String?;
      description ??= rest['synopsis-text'] as String?;
      status ??= rest['status'] as String?;
      final restGenres = rest['genre'];
      if (genres.isEmpty && restGenres is List) {
        genres.addAll(restGenres.cast<String>());
      }
    }

    return NovelMetadata(
      title: title?.trim() ?? 'Untitled',
      author: author,
      description: description,
      coverUrl:
          coverUrl ??
          (novelCode.isNotEmpty
              ? 'https://$_assetsDomain/images/900/$novelCode.webp'
              : null),
      language: context.plugin.language,
      chapterCount: chapterCount ?? 0,
      sourceId: novelCode.isNotEmpty ? novelCode : null,
      genres: genres,
      status: status,
      rating: rating,
      lastUpdated: lastUpdated,
    );
  }

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) async {
    final code = await _novelCodeFor(context, novelUrl);
    if (code == null || code.isEmpty) {
      throw TransportException(
        'MVLEMPYR: could not resolve novel code from $novelUrl',
      );
    }
    final posts = await _fetchChaptersFromPosts(context, code);
    if (posts != null) return posts;
    return _buildFallbackChapters(context, novelUrl, code);
  }

  @override
  Future<AtlasDocument> chapterContent(
    PluginContext context,
    String chapterUrl,
  ) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(chapterUrl),
      headers: context.plugin.requestHeaders,
    );
    _checkCloudflare(html);
    final title = _extractChapterTitle(html);
    final bodyHtml = _extractChapterBody(html);
    final doc = HtmlTemplate.parser.parse(bodyHtml);
    final root = doc.body;
    if (root == null) {
      return AtlasDocument(
        title: title ?? '',
        metadata: DocumentMetadata(
          sourceUrl: chapterUrl,
          sourceName: context.plugin.sourceName,
        ),
      );
    }
    return HtmlTemplate.pipeline.run(
      root,
      title: title,
      metadata: DocumentMetadata(
        sourceUrl: chapterUrl,
        sourceName: context.plugin.sourceName,
      ),
      filters: context.filters,
    );
  }

  Future<String?> _novelCodeFor(PluginContext context, String novelUrl) async {
    final uri = Uri.parse(novelUrl);
    final target = uri.path.startsWith('/chapter/')
        ? await _novelUriFromChapter(context, uri)
        : uri;
    try {
      final html = await context.transport.fetchHtml(
        target,
        headers: context.plugin.requestHeaders,
      );
      return _extract(html, RegExp(r'id="novel-code">\s*(\d+)'));
    } on TransportException {
      return null;
    }
  }

  /// The novel's chapter feed is a WordPress posts list filtered by a tag id
  /// derived from the novel code, paginated at [_perPage] per request. A page
  /// shorter than [_perPage] (or an HTTP error past the last page) ends the
  /// loop, keeping the request count bounded without needing the
  /// `x-wp-totalpages` header.
  Future<List<ChapterRef>?> _fetchChaptersFromPosts(
    PluginContext context,
    String novelCode,
  ) async {
    final code = int.tryParse(novelCode);
    if (code == null) return null;
    try {
      final tagId = _modPow(7, code, _wpTagMod);
      final entries = <(int, ChapterRef)>[];
      var page = 1;
      while (true) {
        try {
          final uri = restUri(context.plugin, '/posts', {
            'tags': '$tagId',
            'per_page': '$_perPage',
            'page': '$page',
          });
          final value = await context.transport.fetchJson(
            uri,
            headers: context.plugin.requestHeaders,
          );
          final posts = value is List
              ? value.whereType<Map>().toList()
              : <Map>[];
          for (final raw in posts) {
            final post = Map<String, Object?>.from(raw);
            final acf = post['acf'];
            if (acf is! Map) continue;
            final rawNumber = acf['chapter_number'];
            if (rawNumber is! num || rawNumber.toInt() <= 0) continue;
            final number = rawNumber.toInt();
            final postCode = acf['novel_code']?.toString() ?? novelCode;
            final chName = acf['ch_name'] as String?;
            final date = post['date'] as String?;
            entries.add((
              number,
              ChapterRef(
                title: chName ?? 'Chapter $number',
                url: 'https://$_domain/chapter/$postCode-$number',
                publishedAt: date != null ? DateTime.tryParse(date) : null,
              ),
            ));
          }
          if (posts.length < _perPage) break;
          page++;
        } on TransportException {
          break;
        }
      }
      entries.sort((a, b) => a.$1.compareTo(b.$1));
      final refs = entries.map((e) => e.$2).toList();
      return refs.isEmpty ? null : refs;
    } catch (_) {
      return null;
    }
  }

  Future<List<ChapterRef>> _buildFallbackChapters(
    PluginContext context,
    String novelUrl,
    String novelCode,
  ) async {
    final slug = Uri.parse(novelUrl).pathSegments.last;
    final total = await _getTotalChapters(context, slug, novelCode);
    return List.generate(
      total,
      (i) => ChapterRef(
        title: 'Chapter ${i + 1}',
        url: 'https://$_domain/chapter/$novelCode-${i + 1}',
      ),
    );
  }

  Future<int> _getTotalChapters(
    PluginContext context,
    String slug,
    String novelCode,
  ) async {
    if (slug.isNotEmpty) {
      final rest = await _fetchNovelBySlug(context, slug);
      final total = rest?['total-chapters'];
      if (total is num && total.toInt() > 0) return total.toInt();
    }
    return _findLastChapter(context, novelCode);
  }

  /// Binary search over the public chapter URLs to find the last existing
  /// chapter — the fallback when the REST feed is unreachable.
  Future<int> _findLastChapter(PluginContext context, String novelCode) async {
    const maxChapters = 10000;
    int low = 1;
    int high = 1;
    while (high <= maxChapters) {
      try {
        await context.transport.fetchHtml(
          Uri.parse('https://$_domain/chapter/$novelCode-$high'),
          headers: context.plugin.requestHeaders,
        );
        low = high;
        high *= 2;
      } on TransportException {
        break;
      }
    }
    if (high > maxChapters) high = maxChapters;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      try {
        await context.transport.fetchHtml(
          Uri.parse('https://$_domain/chapter/$novelCode-$mid'),
          headers: context.plugin.requestHeaders,
        );
        low = mid;
      } on TransportException {
        high = mid - 1;
      }
    }
    return low;
  }

  Future<Map<String, Object?>?> _fetchNovelBySlug(
    PluginContext context,
    String slug,
  ) async {
    if (slug.isEmpty) return null;
    try {
      final uri = restUri(context.plugin, '/mvl-novels', {'slug': slug});
      final value = await context.transport.fetchJson(
        uri,
        headers: context.plugin.requestHeaders,
      );
      final list = value is List ? value.whereType<Map>().toList() : <Map>[];
      if (list.isEmpty) return null;
      return Map<String, Object?>.from(list.first);
    } catch (_) {
      return null;
    }
  }

  Future<Uri> _novelUriFromChapter(
    PluginContext context,
    Uri chapterUri,
  ) async {
    try {
      final html = await context.transport.fetchHtml(
        chapterUri,
        headers: context.plugin.requestHeaders,
      );
      final novelLink = RegExp(r'href="(/novel/[^"]+)"').firstMatch(html);
      if (novelLink != null) {
        return Uri.parse('https://$_domain${novelLink.group(1)}');
      }
    } on TransportException {
      // fall through to the chapter URL itself
    }
    return chapterUri;
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

  String _extractChapterBody(String html) {
    final match = RegExp(
      r'<span[^>]*class="[^"]*oxy-stock-content-styles[^"]*"[^>]*>([\s\S]*?)</span>',
    ).firstMatch(html);
    final body = match?.group(1);
    if (body == null || body.trim().isEmpty) {
      throw const TransportException('MVLEMPYR: chapter content not found');
    }
    return body;
  }

  String _htmlToText(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
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
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        )
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        );

    final lines = text.split('\n').map((l) => l.trim()).toList();
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  void _checkCloudflare(String html) {
    final title =
        RegExp(r'<title>\s*([^<]*)').firstMatch(html)?.group(1)?.trim() ?? '';
    if (title == 'Attention Required! | Cloudflare' ||
        title == 'Just a moment...') {
      throw const TransportException(
        'MVLEMPYR: Cloudflare challenge detected, please retry',
      );
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

  String? _extract(String html, RegExp pattern) {
    final match = pattern.firstMatch(html);
    return match?.group(1)?.trim();
  }
}
