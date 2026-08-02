import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

/// Talks to a site's `/wp-json/wp/v2/*` REST endpoints instead of scraping
/// rendered HTML where available, and falls back to [HtmlTemplate] scraping
/// for anything the REST API doesn't expose (search, chapter lists — which
/// are site-specific and need a bespoke template or selector config).
class WordPressApiTemplate implements Template {
  const WordPressApiTemplate();

  static const _fallback = HtmlTemplate();

  @override
  String get templateId => 'wordpress-api';

  @override
  Set<PluginCapability> get supportedCapabilities =>
      PluginCapability.values.toSet();

  /// The `scheme://authority` of the site's WordPress REST backend. Defaults
  /// to the manifest's [PluginManifest.baseUrl]; a subclass whose REST API
  /// lives on a different host than its public site overrides this.
  String restOrigin(PluginManifest plugin) {
    final base = Uri.parse(plugin.baseUrl);
    return '${base.scheme}://${base.authority}';
  }

  /// Builds a `<restOrigin>/wp-json/wp/v2<path>?<query>` URI against the
  /// site's WordPress REST API.
  Uri restUri(
    PluginManifest plugin,
    String path, [
    Map<String, String> query = const {},
  ]) =>
      Uri.parse('${restOrigin(plugin)}/wp-json/wp/v2$path')
          .replace(queryParameters: query);

  String? _slugOf(String url) {
    final segments =
        Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.last;
  }

  String? _stringPath(Map<String, Object?> map, List<String> keys) {
    Object? current = map;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current is String && current.isNotEmpty ? current : null;
  }

  /// Fetches the post via REST (`posts?slug=...&_fields=title,content`), using
  /// `content.rendered` when the post is exposed; falls back to scraping the
  /// rendered chapter page otherwise.
  @override
  Future<AtlasDocument> chapterContent(
    PluginContext context,
    String chapterUrl,
  ) async {
    final slug = _slugOf(chapterUrl);
    if (slug != null) {
      try {
        final uri = restUri(context.plugin, '/posts', {
          'slug': slug,
          'per_page': '1',
          '_fields': 'title,content,date,link',
        });
        final value = await context.transport
            .fetchJson(uri, headers: context.plugin.requestHeaders);
        final posts = value is List ? value.whereType<Map>().toList() : null;
        if (posts != null && posts.isNotEmpty) {
          final post = Map<String, Object?>.from(posts.first);
          final contentHtml = _stringPath(post, ['content', 'rendered']);
          final title = _stringPath(post, ['title', 'rendered']);
          if (contentHtml != null) {
            final doc = HtmlTemplate.parser.parse(contentHtml);
            final root = doc.body;
            if (root != null) {
              return HtmlTemplate.pipeline.run(
                root,
                title: title,
                metadata: DocumentMetadata(
                  sourceUrl: chapterUrl,
                  sourceName: context.plugin.sourceName,
                  publishedAt: _tryParseDate(_stringPath(post, ['date'])),
                ),
                filters: context.filters,
              );
            }
          }
        }
      } on TransportException {
        // REST unavailable (offline cache miss, 404, blocked, ...) → scrape.
      } on FormatException {
        // Response wasn't JSON → scrape.
      }
    }
    return _fallback.chapterContent(context, chapterUrl);
  }

  /// Best-effort metadata via the post's REST entry; falls back to scraping.
  @override
  Future<NovelMetadata> metadata(
    PluginContext context,
    String novelUrl,
  ) async {
    final slug = _slugOf(novelUrl);
    if (slug != null) {
      try {
        final uri = restUri(context.plugin, '/posts', {
          'slug': slug,
          'per_page': '1',
          '_fields': 'title,date,link',
        });
        final value = await context.transport
            .fetchJson(uri, headers: context.plugin.requestHeaders);
        final posts = value is List ? value.whereType<Map>().toList() : null;
        if (posts != null && posts.isNotEmpty) {
          final post = Map<String, Object?>.from(posts.first);
          final title = _stringPath(post, ['title', 'rendered']);
          if (title != null) {
            return NovelMetadata(
              title: title,
              language: context.plugin.language,
              sourceId: _stringPath(post, ['link']),
            );
          }
        }
      } on TransportException {
        // fall through to scraping
      } on FormatException {
        // fall through to scraping
      }
    }
    return _fallback.metadata(context, novelUrl);
  }

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) =>
      _fallback.chapterList(context, novelUrl);

  @override
  Future<List<SearchResult>> search(
    PluginContext context,
    String query,
  ) =>
      _fallback.search(context, query);

  DateTime? _tryParseDate(String? raw) => raw == null ? null : DateTime.tryParse(raw);
}
