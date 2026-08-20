import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/wtrlab_template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

import 'test_fixtures.dart';

const _base = 'https://wtr-lab.com';
const _novelUrl = '$_base/en/novel/29058/'
    'charm-is-full-i-have-become-a-male-god-since-high-school';
const _chapterUrl = '$_novelUrl/chapter-639';
const _searchUrl = '$_base/api/search';
const _readerUrl = '$_base/api/reader/get';
const _chaptersUrl = '$_base/api/chapters/29058';

const _aesKey = 'IJAFUUxjM25hyzL2AZrn0wl7cESED6Ru';

const _novelPage = '''
<html><head><title>Charm is Full</title></head><body>
<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{
  "serie":{"serie_data":{
    "id":28086,"slug":"charm-is-full-i-have-become-a-male-god-since-high-school",
    "status":0,"raw_id":29058,"chapter_count":960,"rating":3.4333334,
    "data":{"title":"Charm is Full: I Have Become a Male God Since High School",
      "author":"Dong Bei Da Ju Mao",
      "description":"[Synopsis: Short, Ugly, and Fat] Reborn in high school, Lu Yan activates his charm system.",
      "image":"https://img.wtr-lab.com/cdn/series/cover.jpg",
      "raw":{"title":"\\u9b45\\u529b\\u5347\\u6ee1\\uff1a\\u4ece\\u9ad8\\u4e2d\\u5f00\\u59cb\\u6210\\u7537\\u795e","author":"\\u4e1c\\u5317\\u5927\\u6a58\\u732b"}
    }
  }},
  "tags":[{"id":48,"title":"Male Protagonist"},{"id":95,"title":"Comedy"}]
}}}</script>
</body></html>''';

const _searchResponse = {
  'success': true,
  'data': [
    {
      'id': 86727,
      'raw_id': 90475,
      'slug': 'ten-years-behind-bars-for-him-reborn-to-bury-my-ex-husbands-family',
      'status': 1,
      'chapter_count': 290,
      'data': {
        'title': 'Ten Years Behind Bars',
        'author': 'Someone',
        'description': 'A tale of revenge.',
        'image': 'https://img.wtr-lab.com/cdn/series/thumb.jpg',
      },
    },
    {
      'id': 86506,
      'raw_id': 90254,
      'slug': 'female-dominated-world',
      'status': 0,
      'chapter_count': 527,
      'data': {
        'title': 'Female Dominated World',
        'author': 'Another',
        'description': 'A different tale.',
        'image': null,
      },
    },
  ],
};

const _chaptersResponse = {
  'chapters': [
    {
      'serie_id': 28086,
      'id': 21337972,
      'order': 1,
      'title': 'Back to high school, charm system',
      'name': '第1章',
      'updated_at': '2026-03-23 19:00:12.04+00',
    },
    {
      'serie_id': 28086,
      'id': 21337973,
      'order': 2,
      'title': 'Conflict, a test of perseverance',
      'name': '第2章',
      'updated_at': '2026-03-24 19:00:12.04+00',
    },
  ],
};

const _paragraphs = ['陆言没说话，拿起话筒，轻轻拍了拍。', '“大家安静一下，我有件事情要说。”'];

/// A WTR session auxiliary that always reports session cookies present, so the
/// auth manager can be driven to the authenticated state in tests.
class _AuthenticatedWtrAuxiliary implements WtrSessionAuxiliary {
  @override
  String get origin => 'https://wtr-lab.com';

  @override
  Future<void> captureCookies() async {}

  @override
  Future<bool> hasSessionCookies() async => true;

  @override
  Future<void> clearCookies() async {}
}

/// Wraps [paragraphs] in the site's encrypted `arr:<iv>:<tag>:<ct>` body using
/// the site's hardcoded AES-GCM key, mirroring `WtrLabTemplate._decryptBody`.
String _encryptBody(List<String> paragraphs, {bool tamperTag = false}) {
  final key = utf8.encode(_aesKey);
  final iv = Uint8List.fromList(
    List<int>.generate(12, (i) => (i * 7 + 3) % 256),
  );
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(
      KeyParameter(Uint8List.fromList(key)),
      128,
      iv,
      Uint8List(0),
    ),
  );
  final ctWithTag = cipher.process(utf8.encode(jsonEncode(paragraphs)));
  final tag = Uint8List.fromList(ctWithTag.sublist(ctWithTag.length - 16));
  final ct = Uint8List.fromList(ctWithTag.sublist(0, ctWithTag.length - 16));
  if (tamperTag) tag[0] = tag[0] ^ 0xFF;
  return 'arr:${base64Encode(iv)}:${base64Encode(tag)}:${base64Encode(ct)}';
}

Map<String, Object?> _readerResponse(
        {String? body, bool requireTurnstile = false}) =>
    requireTurnstile
        ? {'requireTurnstile': true}
        : {
            'success': true,
            'chapter': {
              'id': 33607609,
              'title': 'Chapter 638: He wrote both of them!?',
            },
            'data': {
              'raw_id': 29058,
              'data': {'body': body},
            },
          };

void main() {
  const template = WtrLabTemplate();

  final session = SessionRefreshService.instance;

  setUp(() async {
    session.clearInvalid();
    // The default translation service is now AI (English), which requires an
    // authenticated WTR-Lab session — provide one so template tests that hit
    // `/api/reader/get` pass through the sign-in gate.
    final auth = WtrAuthenticationManager(
      sessionRepository: InMemoryWtrSessionRepository(),
      auxiliary: _AuthenticatedWtrAuxiliary(),
    );
    await auth.completeLogin();
    WtrChapterProvider.overrideForTest(WtrChapterProvider(authManager: auth));
  });
  tearDown(() {
    session.clearInvalid();
    WtrChapterProvider.reset();
  });

  PluginContext contextWith(Transport transport) => buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

  group('WtrLabTemplate.search', () {
    test('POSTs the query and maps results to novel URLs', () async {
      final transport = FakeTransport()
        ..addPostJson(_searchUrl, _searchResponse);
      final context = contextWith(transport);

      final results = await template.search(context, 'male god');

      expect(transport.jsonCalls, 1);
      expect(results, hasLength(2));
      expect(results.first.title, 'Ten Years Behind Bars');
      expect(
        results.first.url,
        '$_base/en/novel/90475/'
            'ten-years-behind-bars-for-him-reborn-to-bury-my-ex-husbands-family',
      );
      expect(results.first.author, 'Someone');
      expect(results.first.coverUrl,
          'https://img.wtr-lab.com/cdn/series/thumb.jpg');
      expect(results.first.description, 'A tale of revenge.');
    });

    test('returns empty when the API answers without a data list', () async {
      final transport = FakeTransport()
        ..addPostJson(_searchUrl, {'success': true});
      final results = await template.search(contextWith(transport), 'x');
      expect(results, isEmpty);
    });
  });

  group('WtrLabTemplate.metadata', () {
    test('parses the __NEXT_DATA__ script', () async {
      final transport = FakeTransport()..addHtml(_novelUrl, _novelPage);
      final context = contextWith(transport);

      final meta = await template.metadata(context, _novelUrl);

      expect(meta.title, 'Charm is Full: I Have Become a Male God Since High School');
      expect(meta.author, 'Dong Bei Da Ju Mao');
      expect(meta.description, contains('Reborn in high school, Lu Yan'));
      expect(meta.coverUrl, 'https://img.wtr-lab.com/cdn/series/cover.jpg');
      expect(meta.chapterCount, 960);
      expect(meta.sourceId, '29058');
      expect(meta.status, 'Ongoing');
      expect(meta.rating, closeTo(3.43, 0.01));
      expect(meta.genres, ['Male Protagonist', 'Comedy']);
      expect(meta.language, 'en');
    });

    test('throws TransportException when __NEXT_DATA__ is missing', () async {
      final transport = FakeTransport()
        ..addHtml(_novelUrl, '<html><body>no data here</body></html>');
      expect(
        template.metadata(contextWith(transport), _novelUrl),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('WtrLabTemplate.chapterList', () {
    test('maps the full chapters API response to chapter URLs', () async {
      final transport = FakeTransport()..addJson(_chaptersUrl, _chaptersResponse);
      final context = contextWith(transport);

      final refs = await template.chapterList(context, _novelUrl);

      expect(transport.jsonCalls, 1);
      expect(refs, hasLength(2));
      expect(refs.first.title, 'Back to high school, charm system');
      expect(refs.first.url, '$_novelUrl/chapter-1');
      expect(refs.last.url, '$_novelUrl/chapter-2');
      expect(refs.first.publishedAt, isNotNull);
    });

    test('throws when the URL does not carry a novel id', () async {
      expect(
        template.chapterList(
            contextWith(FakeTransport()), '$_base/some/other/path'),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('WtrLabTemplate.chapterContent', () {
    test('POSTs reader/get, decrypts the body and renders paragraphs', () async {
      final transport = FakeTransport()
        ..addPostJson(_readerUrl, _readerResponse(body: _encryptBody(_paragraphs)));
      final context = contextWith(transport);

      final doc = await template.chapterContent(context, _chapterUrl);

      // One reader POST plus the per-novel glossary GET the AI cleanup pass
      // attempts for source-language text (missing fixture -> fail-soft).
      expect(transport.jsonCalls, 2);
      expect(doc.title, 'Chapter 638: He wrote both of them!?');
      final text = doc.renderToText();
      expect(text, contains('陆言没说话，拿起话筒，轻轻拍了拍。'));
      expect(text, contains('大家安静一下，我有件事情要说。'));
    });

    test('treats requireTurnstile as a session wall for the origin', () async {
      final transport = FakeTransport()
        ..addPostJson(_readerUrl, _readerResponse(requireTurnstile: true));

      await expectLater(
        template.chapterContent(contextWith(transport), _chapterUrl),
        throwsA(isA<TransportException>()
            .having((e) => e.sessionExpired, 'sessionExpired', isTrue)),
      );
      expect(
        session.lastInvalidOrigin.value,
        Uri.parse('https://wtr-lab.com/'),
        reason: 'the challenge latches the origin so the re-verify flow runs',
      );
      expect(
        session.lastInvalidSeedUrl.value,
        Uri.parse(_chapterUrl),
        reason: 'the re-verify webview opens the chapter page (AI = no param)',
      );
    });

    test('requireTurnstile latches a probe that clears only once the reader '
        'stops demanding it', () async {
      final transport = FakeTransport()
        ..addPostJson(_readerUrl, _readerResponse(requireTurnstile: true));
      final context = contextWith(transport);

      await expectLater(
        template.chapterContent(context, _chapterUrl),
        throwsA(isA<TransportException>()),
      );
      final probe = session.lastInvalidVerificationProbe;
      expect(probe, isNotNull,
          reason: 'the refresh webview must wait for the real challenge to '
              'clear, not just for cookies to appear');

      // Still challenging -> not verified yet.
      expect(await probe!(), isFalse);

      // The challenge clears: the same reader POST now serves content.
      transport.addPostJson(
        _readerUrl,
        _readerResponse(body: _encryptBody(_paragraphs)),
      );
      expect(await probe(), isTrue);
    });

    test('requireTurnstile seeds the chapter page with the active service param',
        () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.webPlus);
      final localTemplate = WtrLabTemplate(chapterProvider: provider);
      final transport = FakeTransport()
        ..addPostJson(_readerUrl, _readerResponse(requireTurnstile: true));

      await expectLater(
        localTemplate.chapterContent(contextWith(transport), _chapterUrl),
        throwsA(isA<TransportException>()
            .having((e) => e.sessionExpired, 'sessionExpired', isTrue)),
      );
      expect(
        session.lastInvalidSeedUrl.value,
        Uri.parse('$_chapterUrl?service=webplus'),
        reason: 'webplus carries its ?service= param onto the chapter page',
      );
    });

    test('throws TransportException on a tampered tag', () async {
      final transport = FakeTransport()
        ..addPostJson(
            _readerUrl,
            _readerResponse(
                body: _encryptBody(_paragraphs, tamperTag: true)));
      expect(
        template.chapterContent(contextWith(transport), _chapterUrl),
        throwsA(isA<TransportException>()),
      );
    });

    test('throws TransportException on a malformed body', () async {
      final transport = FakeTransport()
        ..addPostJson(_readerUrl, _readerResponse(body: 'not-an-arr-payload'));
      expect(
        template.chapterContent(contextWith(transport), _chapterUrl),
        throwsA(isA<TransportException>()),
      );
    });

    test('throws when the chapter URL lacks the order', () async {
      expect(
        template.chapterContent(
            contextWith(FakeTransport()), '$_novelUrl/not-a-chapter'),
        throwsA(isA<TransportException>()),
      );
    });
  });

  group('WtrLabTemplate contract', () {
    test('declares the capabilities it implements', () {
      expect(template.templateId, 'wtrlab');
      expect(template.supportedCapabilities, {
        PluginCapability.search,
        PluginCapability.chapterList,
        PluginCapability.chapterContent,
        PluginCapability.cover,
      });
    });
  });
}