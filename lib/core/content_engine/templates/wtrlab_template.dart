import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_exceptions.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';

/// Template for WTR-LAB (wtr-lab.com), an MTL novel aggregator whose whole
/// data layer is a JSON API; the HTML pages only carry metadata in a
/// `__NEXT_DATA__` script. Anonymous access returns the *raw* (Chinese) text,
/// matching lightnovel-crawler's `sources/multi/wtrlab.py`; the site's
/// translated ("ai") service requires an account.
///
/// * Search: `POST /api/search` `{"text": query}`.
/// * Metadata: novel page HTML → `#__NEXT_DATA__`.
/// * Chapters: `GET /api/chapters/<rawId>` — the whole list in one response.
/// * Content: `POST /api/reader/get` → AES-GCM-encrypted body (`arr:` payload)
///   decrypted with the site's hardcoded key. The `translate` field is driven
///   by the user's selected translation service for that novel (Web / WebPlus /
///   AI); the AI service additionally enforces the WTR-Lab account gate.
class WtrLabTemplate implements Template {
  const WtrLabTemplate({this.chapterProvider});

  /// Optional injection point for tests. Defaults to the process-wide
  /// [WtrChapterProvider.instance] so the app never rebuilds the template.
  final WtrChapterProvider? chapterProvider;

  static const _aesKey = 'IJAFUUxjM25hyzL2AZrn0wl7cESED6Ru';
  static const _readerPath = '/api/reader/get';

  WtrChapterProvider get _provider =>
      chapterProvider ?? WtrChapterProvider.instance;

  @override
  String get templateId => 'wtrlab';

  @override
  Set<PluginCapability> get supportedCapabilities => const {
        PluginCapability.search,
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      };

  Uri _api(PluginContext context, String path) =>
      Uri.parse(context.plugin.baseUrl).resolve(path);

  @override
  Future<List<SearchResult>> search(
    PluginContext context,
    String query,
  ) async {
    final value = await context.transport.fetchJsonPost(
      _api(context, '/api/search'),
      headers: context.plugin.requestHeaders,
      jsonBody: {'text': query},
    );
    final data = value is Map ? value['data'] : null;
    if (data is! List) return const [];
    final results = <SearchResult>[];
    for (final raw in data.whereType<Map>()) {
      final novel = Map<String, Object?>.from(raw);
      final inner = novel['data'];
      if (inner is! Map) continue;
      final fields = Map<String, Object?>.from(inner);
      final rawId = novel['raw_id'];
      final slug = novel['slug'];
      final title = fields['title'];
      if (rawId is! num || slug is! String || title is! String) continue;
      results.add(SearchResult(
        title: title,
        url: _api(context, '/en/novel/${rawId.toInt()}/$slug').toString(),
        author: fields['author'] is String ? fields['author'] as String : null,
        coverUrl: fields['image'] is String ? fields['image'] as String : null,
        description: fields['description'] is String
            ? fields['description'] as String
            : null,
        language: context.plugin.language,
      ));
    }
    return results;
  }

  @override
  Future<NovelMetadata> metadata(
    PluginContext context,
    String novelUrl,
  ) async {
    final html = await context.transport.fetchHtml(
      Uri.parse(novelUrl),
      headers: context.plugin.requestHeaders,
    );
    final nextData = _parseNextData(html);
    if (nextData == null) {
      throw TransportException(
        'WTR-LAB: no __NEXT_DATA__ found on $novelUrl',
      );
    }
    final props = nextData['props'];
    if (props is! Map) {
      throw TransportException(
        'WTR-LAB: could not parse novel metadata from $novelUrl',
      );
    }
    final propsMap = Map<String, Object?>.from(props);
    final pagePropsRaw = propsMap['pageProps'];
    final pageProps = pagePropsRaw is Map
        ? Map<String, Object?>.from(pagePropsRaw)
        : null;
    final serieRaw = pageProps?['serie'];
    final serie = serieRaw is Map
        ? Map<String, Object?>.from(serieRaw)['serie_data']
        : null;
    if (serie is! Map) {
      throw TransportException(
        'WTR-LAB: could not parse novel metadata from $novelUrl',
      );
    }
    final serieMap = Map<String, Object?>.from(serie);
    final fields = serieMap['data'] is Map
        ? Map<String, Object?>.from(serieMap['data'] as Map)
        : const <String, Object?>{};
    final raw = fields['raw'] is Map
        ? Map<String, Object?>.from(fields['raw'] as Map)
        : null;

    final genres = <String>[];
    final tags = pageProps?['tags'];
    if (tags is List) {
      for (final rawTag in tags.whereType<Map>()) {
        final title = rawTag['title'];
        if (title is String && title.isNotEmpty) genres.add(title);
      }
    }

    final rawId = serieMap['raw_id'];
    final statusRaw = serieMap['status'];
    final chapterCount = serieMap['chapter_count'];
    final rating = serieMap['rating'];

    return NovelMetadata(
      // Prefer the translated title/author/description, falling back to the
      // raw (Chinese) fields.
      title: _firstString(fields['title']) ??
          _firstString(raw?['title']) ??
          'Untitled',
      author: _firstString(fields['author']) ?? _firstString(raw?['author']),
      description: _firstString(fields['description']) ??
          _firstString(raw?['description']),
      coverUrl: _firstString(fields['image']),
      language: context.plugin.language,
      chapterCount: chapterCount is num ? chapterCount.toInt() : 0,
      sourceId: rawId is num ? rawId.toInt().toString() : null,
      genres: genres,
      // Site semantics: 0 = ongoing, 1 = completed (verified live, opposite of
      // what lightnovel-crawler assumes).
      status: statusRaw is num && statusRaw.toInt() == 1
          ? 'Completed'
          : 'Ongoing',
      rating: rating is num ? rating.toDouble() : null,
    );
  }

  @override
  Future<List<ChapterRef>> chapterList(
    PluginContext context,
    String novelUrl,
  ) async {
    final rawId = _rawIdFromUrl(novelUrl);
    if (rawId == null) {
      throw TransportException(
        'WTR-LAB: could not resolve the novel id from $novelUrl',
      );
    }
    final value = await context.transport.fetchJson(
      _api(context, '/api/chapters/$rawId'),
      headers: context.plugin.requestHeaders,
    );
    final list = value is Map ? value['chapters'] : null;
    if (list is! List) {
      throw const TransportException('WTR-LAB: chapter list not found');
    }
    final cleanUrl = novelUrl.split('?').first.replaceAll(RegExp(r'/+$'), '');
    final refs = <ChapterRef>[];
    for (final raw in list.whereType<Map>()) {
      final item = Map<String, Object?>.from(raw);
      final order = item['order'];
      if (order is! num) continue;
      final title = _firstString(item['title']);
      final name = _firstString(item['name']);
      refs.add(ChapterRef(
        title: title ?? name ?? 'Chapter ${order.toInt()}',
        url: '$cleanUrl/chapter-${order.toInt()}',
        publishedAt: _parseDate(item['updated_at']),
      ));
    }
    return refs;
  }

  @override
  Future<AtlasDocument> chapterContent(
    PluginContext context,
    String chapterUrl,
  ) async {
    final rawId = _rawIdFromUrl(chapterUrl);
    final order = _orderFromUrl(chapterUrl);
    if (rawId == null || order == null) {
      throw TransportException(
        'WTR-LAB: could not parse the chapter id from $chapterUrl',
      );
    }
    // The user-selected translation service decides the request strategy. For
    // AI this enforces the WTR-Lab auth gate *before* any network call and
    // never silently falls back to another service.
    final translate = await _provider.resolveTranslate(rawId);

    final value = await context.transport.fetchJsonPost(
      _api(context, _readerPath),
      headers: context.plugin.requestHeaders,
      jsonBody: {
        'translate': translate,
        'language': context.plugin.language,
        'raw_id': rawId,
        'chapter_no': order,
        'retry': false,
        'force_retry': false,
      },
    );

    // WTR-Lab rejects an expired/revoked AI session with `code: 1401` —
    // surface it as a WTR session failure so the UI asks for a re-login.
    if (_isNotLoggedIn(value)) {
      _provider.auth.markSessionExpired();
      throw const WtrSessionExpiredException();
    }

    final body = _extractBody(value);
    if (body == null) {
      throw TransportException(
        _readerFailureMessage(value) ??
            'WTR-LAB: chapter content not found for $chapterUrl',
      );
    }
    final paragraphs = _decryptBody(body);

    final doc = HtmlTemplate.parser.parse(
      paragraphs.map((p) => '<p>${_escapeHtml(p)}</p>').join(),
    );
    String? title;
    final chapter = value is Map ? value['chapter'] : null;
    if (chapter is Map) {
      title = _firstString(chapter['title']);
    }
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

  /// The reader body is `arr:<iv>:<tag>:<ciphertext>` (or `str:` for a single
  /// string), AES-GCM-encrypted with a hardcoded 32-byte key; the decrypted
  /// payload is a JSON array of paragraphs for `arr:`.
  List<String> _decryptBody(Object? encrypted) {
    if (encrypted is List) {
      return encrypted.map((e) => '$e').toList();
    }
    if (encrypted is! String) {
      throw const TransportException(
        'WTR-LAB: unknown chapter content type',
      );
    }
    var payload = encrypted;
    var isArray = false;
    if (payload.startsWith('arr:')) {
      isArray = true;
      payload = payload.substring(4);
    } else if (payload.startsWith('str:')) {
      payload = payload.substring(4);
    } else {
      throw const TransportException(
        'WTR-LAB: unknown chapter content format',
      );
    }
    final parts = payload.split(':');
    if (parts.length != 3) {
      throw const TransportException(
        'WTR-LAB: invalid encrypted data format',
      );
    }
    final iv = base64Decode(parts[0]);
    final tag = base64Decode(parts[1]);
    final ciphertext = base64Decode(parts[2]);
    final plaintext = _aesGcmDecrypt(utf8.encode(_aesKey), iv, [
      ...ciphertext,
      ...tag,
    ]);
    final text = utf8.decode(plaintext);
    if (!isArray) return [text];
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      throw const TransportException(
        'WTR-LAB: chapter content is not a paragraph list',
      );
    }
    return decoded.map((e) => '$e').toList();
  }

  Uint8List _aesGcmDecrypt(
    List<int> key,
    List<int> iv,
    List<int> ciphertextAndTag,
  ) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(
        KeyParameter(Uint8List.fromList(key)),
        128,
        Uint8List.fromList(iv),
        Uint8List(0),
      ),
    );
    try {
      return cipher.process(Uint8List.fromList(ciphertextAndTag));
    } on InvalidCipherTextException {
      throw const TransportException(
        'WTR-LAB: chapter body failed authentication (bad key or tampered data)',
      );
    }
  }

  Map<String, Object?>? _parseNextData(String html) {
    final match = RegExp(
      r'<script[^>]*id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
    ).firstMatch(html);
    if (match == null) return null;
    final decoded = jsonDecode(match.group(1)!);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  }

  /// The WTR reader API answers `{"code":1401,"error":"You are not logged in!"}`
  /// when the request lacks a valid authenticated session (the AI service, or
  /// an expired/rejected stored session).
  bool _isNotLoggedIn(Object? value) =>
      value is Map && value['code'] == 1401;

  /// `{data: {data: {body: ...}}}` in the reader response, plus the top-level
  /// `success` flag.
  Object? _extractBody(Object? value) {
    if (value is! Map || value['success'] == false) return null;
    final data = value['data'];
    if (data is! Map) return null;
    final inner = data['data'];
    if (inner is! Map) return null;
    return inner['body'];
  }

  /// A user-facing reason when the reader call fails: the rate-limit
  /// `requireTurnstile` signal (mirrors lightnovel-crawler's rotation trigger)
  /// or the API's own `message`.
  String? _readerFailureMessage(Object? value) {
    if (value is! Map) return null;
    if (value['requireTurnstile'] == true) {
      return 'WTR-LAB is rate-limiting this address; wait a while and retry.';
    }
    final message = value['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
  }

  int? _rawIdFromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    final idx = segments.indexOf('novel');
    if (idx < 0 || idx + 1 >= segments.length) return null;
    return int.tryParse(segments[idx + 1]);
  }

  int? _orderFromUrl(String url) {
    final match = RegExp(r'/chapter-(\d+)').firstMatch(Uri.parse(url).path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  String? _firstString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
