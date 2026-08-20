import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/template_models.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_auth_state.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_exceptions.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_glossary_term.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_glossary_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_term_preference_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_web_translate_service.dart';

/// Template for WTR-LAB (wtr-lab.com), an MTL novel aggregator whose whole
/// data layer is a JSON API; the HTML pages only carry metadata in a
/// `__NEXT_DATA__` script. Anonymous plain-HTTP access returns the *raw*
/// (Chinese) text, and the API asks for a Cloudflare Turnstile challenge when
/// it can't see a browser session — so the app routes the reader POSTs through
/// the WebView transport, which serves them from a real browser context
/// (passing the challenge) whenever one is available. The "ai" service
/// additionally requires a WTR-Lab account.
///
/// * Search: `POST /api/search` `{"text": query}`.
/// * Metadata: novel page HTML → `#__NEXT_DATA__`.
/// * Chapters: `GET /api/chapters/<rawId>` — the whole list in one response.
/// * Content: `POST /api/reader/get` → AES-GCM-encrypted body (`arr:` payload)
///   decrypted with the site's hardcoded key. The `translate` field is driven
///   by the user's selected translation service for that novel (Web / WebPlus /
///   AI); the AI service additionally enforces the WTR-Lab account gate.
///
/// The Web and WebPlus services return the source-language (Chinese) text, so
/// Atlas mirrors the site's reader: it applies the per-novel glossary (WebPlus
/// only, like the site) and then translates the paragraphs to the plugin's
/// language through the same on-device Google endpoint the site uses. The AI
/// service returns English from the API, but its body embeds `※n⛬` name
/// placeholders that must be resolved from the response's `glossary_data`, and
/// any source-language terms the AI body leaves untranslated are then
/// substituted from the fullest glossary Atlas can build: the response's
/// `glossary_data`, the per-novel glossary (all glossaries plus community
/// replacements) and — when a WTR-Lab account is connected — the account's top
/// term preferences.
class WtrLabTemplate implements Template {
  const WtrLabTemplate({
    this.chapterProvider,
    this.glossaryService,
    this.webTranslateService,
    this.translateTransport,
    this.termPreferenceService,
  });

  /// Optional injection point for tests. Defaults to the process-wide
  /// [WtrChapterProvider.instance] so the app never rebuilds the template.
  final WtrChapterProvider? chapterProvider;

  /// Optional injection point for tests. Defaults to a per-template service
  /// with its own in-memory cache.
  final WtrGlossaryService? glossaryService;

  /// Optional injection point for tests. Defaults to the real Google endpoint.
  final WtrWebTranslateService? webTranslateService;

  /// Optional injection point for tests. Defaults to a direct HTTP transport.
  ///
  /// The on-device Google translate endpoint (`translate-pa.googleapis.com`)
  /// is a public API that only needs the API key — it must NOT ride the
  /// plugin's WebView transport, because that would navigate the background
  /// web view to a third-party host (and its same-origin fetch would fail
  /// anyway). Plain HTTP always serves it.
  final Transport? translateTransport;

  /// Optional injection point for tests. Defaults to a per-template service
  /// with its own in-memory cache.
  final WtrTermPreferenceService? termPreferenceService;

  static const _aesKey = 'IJAFUUxjM25hyzL2AZrn0wl7cESED6Ru';
  static const _readerPath = '/api/reader/get';

  WtrChapterProvider get _provider =>
      chapterProvider ?? WtrChapterProvider.instance;

  WtrGlossaryService get _glossary =>
      glossaryService ?? WtrGlossaryService();

  WtrTermPreferenceService get _termPreferences =>
      termPreferenceService ?? WtrTermPreferenceService();

  WtrWebTranslateService get _webTranslate =>
      webTranslateService ?? const WtrWebTranslateService();

  Transport get _translateTransport =>
      translateTransport ?? HttpTransport();

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

    // WTR-Lab answers `requireTurnstile` when it can't see a browser session
    // for this address (Cloudflare Turnstile, not a plain rate limit). The
    // app's re-verify flow re-establishes that session in a real browser, so
    // surface it as an expired-session wall the reader auto-recovers from.
    if (_isTurnstileChallenge(value)) {
      final origin = SessionRefreshService.originOf(context.plugin.baseUrl);
      // Open the refresh webview on the *chapter* page carrying the active
      // `?service=` param — the turnstile may only fire there. AI is the site's
      // default, so it uses no param.
      final seedUrl = translate == WtrTranslationService.ai.apiValue
          ? Uri.tryParse(chapterUrl)
          : Uri.tryParse(chapterUrl)
              ?.replace(queryParameters: {'service': translate});
      if (origin != null) {
        SessionRefreshService.instance.markInvalid(
          origin,
          seedUrl: seedUrl,
          verificationProbe: () => _readerVerificationPassed(
            context,
            rawId: rawId,
            order: order,
            translate: translate,
          ),
        );
      }
      throw const TransportException(
        'WTR-LAB requires a browser check before serving translated content; '
        're-verifying the session.',
        sessionExpired: true,
      );
    }

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

    // Post-process the raw chapter text to mirror the site's reader:
    // * Web / WebPlus serve source-language text, so apply the glossary
    //   (WebPlus only, exactly like the site) and translate to the plugin's
    //   language on-device.
    // * AI already returns English, but its body embeds `※n⛬` name
    //   placeholders that must be resolved from the response's glossary_data.
    // Every enhancement is fail-soft: an outage keeps the decrypted text.
    final enhanced = await _enhance(
      context,
      rawId: rawId,
      translate: translate,
      paragraphs: paragraphs,
      readerValue: value,
    );

    final doc = HtmlTemplate.parser.parse(
      enhanced.map((p) => '<p>${_escapeHtml(p)}</p>').join(),
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

  /// Post-processes the decrypted chapter paragraphs to match the site's
  /// reader output for the active translation service. Always fail-soft: any
  /// enhancement error leaves the already-decrypted text unchanged.
  Future<List<String>> _enhance(
    PluginContext context, {
    required int rawId,
    required String translate,
    required List<String> paragraphs,
    required Object? readerValue,
  }) async {
    final service = WtrTranslationService.fromApiValue(translate);
    if (service == WtrTranslationService.ai) {
      final resolved = _resolveAiMarkers(paragraphs, readerValue);
      try {
        final terms = await _aiGlossaryTerms(
          context,
          rawId: rawId,
          readerValue: readerValue,
          paragraphs: resolved,
        );
        return terms.isEmpty ? resolved : _applyGlossary(resolved, terms);
      } on Object {
        return resolved;
      }
    }
    if (service == WtrTranslationService.webPlus) {
      try {
        final terms = await _glossary.load(
          context.transport,
          Uri.parse(context.plugin.baseUrl),
          rawId: rawId,
          headers: context.plugin.requestHeaders,
        );
        final withNames = _applyGlossary(paragraphs, terms);
        return await _translateToPluginLanguage(context, withNames);
      } on Object {
        return paragraphs;
      }
    }
    // `web`: source-language text, translated like the site does. No glossary
    // (the site applies it only for webplus).
    try {
      return await _translateToPluginLanguage(context, paragraphs);
    } on Object {
      return paragraphs;
    }
  }

  Future<List<String>> _translateToPluginLanguage(
    PluginContext context,
    List<String> paragraphs,
  ) {
    if (context.effectiveLanguage == 'zh') return Future.value(paragraphs);
    return _webTranslate.translateParagraphs(
      _translateTransport,
      paragraphs: paragraphs,
      from: 'zh-CN',
      to: context.effectiveLanguage,
      headers: context.plugin.requestHeaders,
    );
  }

  /// Substitutes glossary Chinese terms for their primary English alias.
  ///
  /// Builds one regex from all terms so overlapping Chinese terms resolve
  /// longest-first (the site sorts its alternatives by length the same way),
  /// and only terms present in a paragraph are actually replaced.
  List<String> _applyGlossary(
    List<String> paragraphs,
    List<WtrGlossaryTerm> terms,
  ) {
    if (terms.isEmpty) return paragraphs;
    final sorted = [...terms]
      ..sort((a, b) => b.zh.length.compareTo(a.zh.length));
    final joined = StringBuffer();
    for (final term in sorted) {
      joined.writeAll([RegExp.escape(term.zh), '|']);
    }
    final pattern = RegExp(
      joined.toString().replaceAll(RegExp(r'\|$'), ''),
      caseSensitive: false,
    );
    return paragraphs.map((p) {
      if (p.isEmpty) return p;
      return p.replaceAllMapped(pattern, (m) {
        final match = m.group(0)!;
        for (final term in sorted) {
          if (match.contains(term.zh)) return term.en;
        }
        return match;
      });
    }).toList();
  }

  /// Resolves the AI body's `※n⛬` name placeholders against the response's
  /// `glossary_data.terms` (`[en, zh]` pairs). Out-of-range or missing
  /// references are left untouched.
  List<String> _resolveAiMarkers(List<String> paragraphs, Object? value) {
    final terms = _glossaryData(value);
    if (terms.isEmpty) return paragraphs;
    final marker = RegExp('[\\u203B](\\d+)[\\u26EC\\u3013]');
    return paragraphs.map((p) {
      if (!marker.hasMatch(p)) return p;
      return p.replaceAllMapped(marker, (m) {
        final index = int.tryParse(m.group(1) ?? '');
        if (index == null || index < 0 || index >= terms.length) {
          return m.group(0)!;
        }
        return terms[index].en;
      });
    }).toList();
  }

  /// `glossary_data.terms` from the AI reader response, as glossary terms.
  List<WtrGlossaryTerm> _glossaryData(Object? value) {
    if (value is! Map) return const [];
    final data = value['data'];
    if (data is! Map) return const [];
    final inner = data['data'];
    if (inner is! Map) return const [];
    final glossaryData = inner['glossary_data'];
    if (glossaryData is! Map) return const [];
    final terms = glossaryData['terms'];
    if (terms is! List) return const [];
    return terms
        .map(WtrGlossaryTerm.fromAiTerm)
        .whereType<WtrGlossaryTerm>()
        .toList();
  }

  /// The full zh→en map for the AI cleanup pass: the response's own
  /// `glossary_data` terms, overlaid with the per-novel glossary (every
  /// glossary plus community replacements) and — for connected accounts — the
  /// account's top term preference per term. Mirrors the account-aware
  /// glossary the site renders in AI mode. Fail-soft at each layer: an
  /// unavailable glossary or preference just leaves the term unchanged.
  ///
  /// Cheap by construction: fully-English chapters skip the network entirely
  /// (no CJK → nothing to clean up), and only terms actually present in the
  /// text are looked up — the per-novel glossary holds hundreds of entries but
  /// a chapter touches a handful, so preference fetches stay parallel and few.
  Future<List<WtrGlossaryTerm>> _aiGlossaryTerms(
    PluginContext context, {
    required int rawId,
    required Object? readerValue,
    required List<String> paragraphs,
  }) async {
    if (!_containsCjk(paragraphs)) return const [];

    final perNovel = await _glossary.loadAll(
      context.transport,
      Uri.parse(context.plugin.baseUrl),
      rawId: rawId,
      headers: context.plugin.requestHeaders,
    );
    final merged = _mergeTerms(_glossaryData(readerValue), perNovel);
    final present =
        merged.where((t) => _containsTerm(paragraphs, t.zh)).toList();
    if (present.isEmpty) return present;

    final preferences = _termPreferences;
    return Future.wait(
      present.map((term) async {
        if (_provider.auth.state.value != WtrAuthState.authenticated) {
          return term;
        }
        final preferred = await preferences.topPreference(
          context.transport,
          Uri.parse(context.plugin.baseUrl),
          rawId: rawId,
          zh: term.zh,
          lang: context.plugin.language,
          headers: context.plugin.requestHeaders,
        );
        if (preferred == null || preferred.isEmpty || preferred == term.en) {
          return term;
        }
        return WtrGlossaryTerm(zh: term.zh, enAliases: [preferred]);
      }),
    );
  }

  /// Whether any paragraph still carries CJK ideographs that could be a
  /// leftover source-language term worth cleaning up.
  bool _containsCjk(List<String> paragraphs) {
    final cjk = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF]');
    return paragraphs.any((p) => cjk.hasMatch(p));
  }

  bool _containsTerm(List<String> paragraphs, String zh) =>
      paragraphs.any((p) => p.contains(zh));

  /// Merges the chapter's `glossary_data` terms with the per-novel glossary,
  /// later sources overriding earlier ones for the same Chinese term.
  List<WtrGlossaryTerm> _mergeTerms(
    List<WtrGlossaryTerm> chapter,
    List<WtrGlossaryTerm> perNovel,
  ) {
    if (perNovel.isEmpty) return chapter;
    final byZh = <String, WtrGlossaryTerm>{
      for (final term in chapter) term.zh: term,
    };
    for (final term in perNovel) {
      byZh[term.zh] = term;
    }
    return byZh.values.toList();
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

  /// The WTR reader API answers `{"success":false,"requireTurnstile":true, ...}`
  /// when it demands a Cloudflare Turnstile solve before serving content.
  bool _isTurnstileChallenge(Object? value) =>
      value is Map && value['requireTurnstile'] == true;

  /// Probe for the re-verify webview: the WTR reader API stops answering
  /// `requireTurnstile` only after the challenge has really been solved, which
  /// is a much stronger "verification passed" signal than "the origin now has
  /// cookies" (WTR-LAB sets cookies immediately). Re-runs the same reader POST
  /// and reports whether the challenge has cleared.
  Future<bool> _readerVerificationPassed(
    PluginContext context, {
    required int rawId,
    required int order,
    required String translate,
  }) async {
    try {
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
      return !_isTurnstileChallenge(value);
    } on Object {
      // Any failure (transport, network, still challenging) means "not yet" —
      // keep the refresh webview up until the challenge actually clears.
      return false;
    }
  }

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

  /// A user-facing reason when the reader call fails: the API's own `message`
  /// (e.g. an account-required notice for the AI service). The Turnstile
  /// challenge is handled earlier as a session wall.
  String? _readerFailureMessage(Object? value) {
    if (value is! Map) return null;
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
