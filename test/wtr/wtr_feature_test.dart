import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'package:atlas_app/core/content_engine/templates/wtrlab_template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_auth_state.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_exceptions.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_glossary_term.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_session_record.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_glossary_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';
import 'package:atlas_app/wtr/domain/services/wtr_web_translate_service.dart';

import '../content_engine/test_fixtures.dart';

const _base = 'https://wtr-lab.com';
const _novelUrl =
    '$_base/en/novel/29058/'
    'charm-is-full-i-have-become-a-male-god-since-high-school';
const _chapterUrl = '$_novelUrl/chapter-639';
const _readerUrl = '$_base/api/reader/get';

const _aesKey = 'IJAFUUxjM25hyzL2AZrn0wl7cESED6Ru';
const _paragraphs = ['陆言没说话，拿起话筒，轻轻拍了拍。', '“大家安静一下，我有件事情要说。”'];

/// Test translate service: a key must be injected, otherwise the production
/// default reads the build-time define (empty in tests) and fails soft.
const _testTranslate = WtrWebTranslateService(key: 'test-key');

/// Fake [WtrSessionAuxiliary] whose cookie probe result is controllable.
class _FakeAuxiliary implements WtrSessionAuxiliary {
  _FakeAuxiliary({this.hasCookies = true});

  bool hasCookies;
  bool captured = false;
  bool cleared = false;

  @override
  String get origin => 'https://wtr-lab.com';

  @override
  Future<void> captureCookies() async {
    captured = true;
  }

  @override
  Future<bool> hasSessionCookies() async => hasCookies;

  @override
  Future<void> clearCookies() async {
    cleared = true;
    hasCookies = false;
  }
}

/// Drives the AI enhancement path signed out by skipping `resolveTranslate`'s
/// AI auth gate, so the term-preferences auth-guard can be tested directly.
class _AuthBypassingProvider extends WtrChapterProvider {
  _AuthBypassingProvider()
    : super(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );

  @override
  Future<String> resolveTranslate(int rawId) async => 'ai';
}

/// Wraps [paragraphs] in the site's encrypted `arr:<iv>:<tag>:<ct>` body.
String _encryptBody(List<String> paragraphs) {
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
  return 'arr:${base64Encode(iv)}:${base64Encode(tag)}:${base64Encode(ct)}';
}

Map<String, Object?> _readerResponse(String body) => {
  'success': true,
  'chapter': {'id': 33607609, 'title': 'Chapter 638: He wrote both of them!?'},
  'data': {
    'raw_id': 29058,
    'data': {'body': body},
  },
};

/// Records the JSON body of every `fetchJsonPost` so tests can assert what
/// `translate` value the template actually POSTs, plus every GET so glossary
/// fetches can be asserted.
class _RecordingTransport implements Transport {
  _RecordingTransport(this.inner);

  final Transport inner;
  Object? lastJsonBody;
  Object? readerJsonBody;
  int jsonPostCalls = 0;
  final List<String> jsonGetPaths = [];
  final List<String> jsonGetUrls = [];

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      inner.fetchHtml(url, headers: headers);

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) => inner.fetchHtmlPost(url, headers: headers, form: form);

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) async {
    jsonGetPaths.add(url.path);
    jsonGetUrls.add(url.toString());
    return inner.fetchJson(url, headers: headers);
  }

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    jsonPostCalls++;
    lastJsonBody = jsonBody;
    if (url.path == '/api/reader/get') {
      readerJsonBody = jsonBody;
    }
    return inner.fetchJsonPost(url, headers: headers, jsonBody: jsonBody);
  }

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) =>
      inner.fetchBytes(url, headers: headers);
}

void main() {
  group('WtrTranslationService', () {
    test('maps services to their api/translate values', () {
      expect(WtrTranslationService.web.apiValue, 'web');
      expect(WtrTranslationService.webPlus.apiValue, 'webplus');
      expect(WtrTranslationService.ai.apiValue, 'ai');
      expect(
        WtrTranslationService.fromApiValue('ai'),
        WtrTranslationService.ai,
      );
      expect(
        WtrTranslationService.fromApiValue('web'),
        WtrTranslationService.web,
      );
      expect(WtrTranslationService.fromApiValue('unknown'), isNull);
    });
  });

  group('WtrAuthenticationManager', () {
    test('starts unauthenticated and stays so when no record exists', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
      );
      expect(auth.state.value, WtrAuthState.notAuthenticated);
      await auth.initialize();
      expect(auth.state.value, WtrAuthState.notAuthenticated);
    });

    test(
      'restores authenticated when the stored session is provable',
      () async {
        final repo = InMemoryWtrSessionRepository();
        await repo.save(
          WtrSessionRecord(authenticated: true, connectedAt: DateTime.now()),
        );
        final auth = WtrAuthenticationManager(
          sessionRepository: repo,
          auxiliary: _FakeAuxiliary(hasCookies: true),
        );
        await auth.initialize();
        expect(auth.state.value, WtrAuthState.authenticated);
      },
    );

    test('downgrades an unprovable stored session to expired', () async {
      final repo = InMemoryWtrSessionRepository();
      await repo.save(const WtrSessionRecord(authenticated: true));
      final auth = WtrAuthenticationManager(
        sessionRepository: repo,
        auxiliary: _FakeAuxiliary(hasCookies: false),
      );
      await auth.initialize();
      expect(auth.state.value, WtrAuthState.sessionExpired);
    });

    test('completeLogin captures, validates and records the session', () async {
      final repo = InMemoryWtrSessionRepository();
      final aux = _FakeAuxiliary(hasCookies: true);
      final auth = WtrAuthenticationManager(
        sessionRepository: repo,
        auxiliary: aux,
      );
      auth.beginLogin();
      expect(auth.state.value, WtrAuthState.authenticating);

      final ok = await auth.completeLogin();

      expect(ok, isTrue);
      expect(aux.captured, isTrue);
      expect(auth.state.value, WtrAuthState.authenticated);
      final saved = await repo.load();
      expect(saved?.authenticated, isTrue);
    });

    test('completeLogin fails when no cookies can be captured', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(hasCookies: false),
      );
      final ok = await auth.completeLogin();
      expect(ok, isFalse);
      expect(auth.state.value, WtrAuthState.authenticationFailed);
    });

    test('markSessionExpired clears the persisted record', () async {
      final repo = InMemoryWtrSessionRepository();
      await repo.save(const WtrSessionRecord(authenticated: true));
      final auth = WtrAuthenticationManager(
        sessionRepository: repo,
        auxiliary: _FakeAuxiliary(),
      );
      auth.markSessionExpired();
      expect(auth.state.value, WtrAuthState.sessionExpired);
      expect(await repo.load(), isNull);
    });

    test('clearSession wipes cookies and returns to unauthenticated', () async {
      final aux = _FakeAuxiliary(hasCookies: true);
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: aux,
      );
      await auth.completeLogin();
      await auth.clearSession();
      expect(aux.cleared, isTrue);
      expect(auth.state.value, WtrAuthState.notAuthenticated);
    });

    test('ensureAuthenticatedOrThrow gates every unauthenticated state', () {
      for (final state in WtrAuthState.values) {
        final auth = WtrAuthenticationManager();
        if (state == WtrAuthState.authenticated) {
          // No public way to fabricate a cookie-backed session — the closest is
          // completing a login with a cookie-proving auxiliary.
          continue;
        }
        auth.state.value = state;
        expect(
          auth.ensureAuthenticatedOrThrow,
          throwsA(isA<WtrAuthException>()),
          reason: 'state $state must be gated',
        );
      }
    });
  });

  group('WtrChapterProvider', () {
    test(
      'defaults by account: WebPlus signed out, AI signed in; persists selection',
      () async {
        final signedOut = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: WtrAuthenticationManager(),
        );
        expect(
          await signedOut.serviceFor(29058),
          WtrTranslationService.webPlus,
        );
        expect(await signedOut.serviceFor(9999), WtrTranslationService.webPlus);

        await signedOut.setService(29058, WtrTranslationService.web);
        expect(await signedOut.serviceFor(29058), WtrTranslationService.web);
        expect(await signedOut.serviceFor(9999), WtrTranslationService.webPlus);

        final auth = WtrAuthenticationManager(
          sessionRepository: InMemoryWtrSessionRepository(),
          auxiliary: _FakeAuxiliary(),
        );
        await auth.completeLogin();
        final signedIn = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: auth,
        );
        expect(await signedIn.serviceFor(29058), WtrTranslationService.ai);
        expect(await signedIn.serviceFor(7777), WtrTranslationService.ai);
      },
    );

    test('resolveTranslate defaults to webplus when signed out', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      expect(await provider.resolveTranslate(29058), 'webplus');
    });

    test('resolveTranslate reflects the selected service', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      expect(await provider.resolveTranslate(29058), 'ai');
      await provider.setService(29058, WtrTranslationService.webPlus);
      expect(await provider.resolveTranslate(29058), 'webplus');
      await provider.setService(29058, WtrTranslationService.web);
      expect(await provider.resolveTranslate(29058), 'web');
    });

    test(
      'AI resolveTranslate throws before network when unauthenticated',
      () async {
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: WtrAuthenticationManager(),
        );
        await provider.setService(29058, WtrTranslationService.ai);
        expect(
          provider.resolveTranslate(29058),
          throwsA(isA<WtrAuthRequiredException>()),
        );
      },
    );

    test(
      'AI resolveTranslate passes when a session is authenticated',
      () async {
        final auth = WtrAuthenticationManager(
          sessionRepository: InMemoryWtrSessionRepository(),
          auxiliary: _FakeAuxiliary(hasCookies: true),
        );
        await auth.completeLogin();
        expect(auth.ensureAuthenticatedOrThrow, returnsNormally);
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: auth,
        );
        await provider.setService(29058, WtrTranslationService.ai);
        expect(await provider.resolveTranslate(29058), 'ai');
      },
    );
  });

  group('WtrLabTemplate translation routing', () {
    test('default template POSTs translate=ai', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      final recording = _RecordingTransport(
        FakeTransport()
          ..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      final body = recording.readerJsonBody! as Map;
      expect(body['translate'], 'ai');
      expect(doc.renderToText(), contains('陆言没说话'));
    });

    test('POSTs the selected webplus service', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.webPlus);
      final recording = _RecordingTransport(
        FakeTransport()
          ..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      await template.chapterContent(context, _chapterUrl);

      expect((recording.readerJsonBody! as Map)['translate'], 'webplus');
    });

    test('AI without a session fails before any network call', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
      );
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      await provider.setService(29058, WtrTranslationService.ai);
      final recording = _RecordingTransport(FakeTransport());
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      await expectLater(
        template.chapterContent(context, _chapterUrl),
        throwsA(isA<WtrAuthRequiredException>()),
      );
      expect(recording.jsonPostCalls, 0);
    });

    test('POSTs translate=ai with a valid session', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(hasCookies: true),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      await provider.setService(29058, WtrTranslationService.ai);
      final recording = _RecordingTransport(
        FakeTransport()
          ..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect((recording.readerJsonBody! as Map)['translate'], 'ai');
      expect(doc.renderToText(), contains('大家安静一下'));
    });

    test(
      'maps the 1401 not-logged-in response to a WTR session failure',
      () async {
        final auth = WtrAuthenticationManager(
          sessionRepository: InMemoryWtrSessionRepository(),
          auxiliary: _FakeAuxiliary(hasCookies: true),
        );
        await auth.completeLogin();
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: auth,
        );
        await provider.setService(29058, WtrTranslationService.ai);
        final recording = _RecordingTransport(
          FakeTransport()..addPostJson(_readerUrl, {
            'code': 1401,
            'error': 'You are not logged in!',
          }),
        );
        final template = WtrLabTemplate(chapterProvider: provider);
        final context = buildContext(
          manifest: buildManifest(baseUrl: _base),
          transport: recording,
        );

        await expectLater(
          template.chapterContent(context, _chapterUrl),
          throwsA(isA<WtrSessionExpiredException>()),
        );
        // The expired session is reflected in the auth state for the UI.
        expect(auth.state.value, WtrAuthState.sessionExpired);
      },
    );
  });

  group('WtrGlossaryTerm', () {
    test('parses a public-glossary term shape', () {
      final term = WtrGlossaryTerm.fromPublicTerm([
        ['Lin Qingqing', 'Lin Qing-Qing'],
        '林青青',
        1,
        2,
        1860,
      ]);
      expect(term, isNotNull);
      expect(term!.zh, '林青青');
      expect(term.enAliases, ['Lin Qingqing', 'Lin Qing-Qing']);
      expect(term.en, 'Lin Qingqing');
    });

    test('parses an AI glossary_data term shape', () {
      final term = WtrGlossaryTerm.fromAiTerm(['Great-grandfather', '太爷爷']);
      expect(term, isNotNull);
      expect(term!.zh, '太爷爷');
      expect(term.en, 'Great-grandfather');
    });

    test('rejects malformed terms', () {
      expect(WtrGlossaryTerm.fromPublicTerm(null), isNull);
      expect(WtrGlossaryTerm.fromPublicTerm(['no zh']), isNull);
      expect(WtrGlossaryTerm.fromPublicTerm([[], '林青青', 1]), isNull);
      expect(WtrGlossaryTerm.fromAiTerm(['only en']), isNull);
      expect(WtrGlossaryTerm.fromAiTerm(['', '太爷爷']), isNull);
    });

    test(
      'parses the object-wrapped alias shape used by some AI glossaries',
      () {
        final term = WtrGlossaryTerm.fromPublicTerm([
          [
            {
              'value': ['Sheng Huaian'],
              'Count': 1,
            },
            {
              'value': ['Sheng Huai-An'],
              'Count': 2,
            },
          ],
          '沈怀安',
          1,
          1,
          6295,
        ]);
        expect(term, isNotNull);
        expect(term!.zh, '沈怀安');
        expect(term.enAliases, ['Sheng Huaian', 'Sheng Huai-An']);
        expect(term.en, 'Sheng Huaian');
      },
    );
  });

  group('WtrGlossaryService', () {
    const glossaryUrl = '$_base/api/v2/reader/terms/29058.json';
    const glossaryResponse = {
      'success': true,
      'raw_id': 29058,
      'glossaries': [
        {
          'data': {
            'terms': [
              [
                ['Lin Qingqing'],
                '林青青',
                1,
                2,
                1860,
              ],
              [
                ['Lu Yichen'],
                '陆逸尘',
                1,
                1,
                1295,
              ],
            ],
          },
        },
      ],
    };

    test('loads and parses the public glossary', () async {
      final transport = FakeTransport()..addJson(glossaryUrl, glossaryResponse);
      final service = WtrGlossaryService();

      final terms = await service.load(
        transport,
        Uri.parse(_base),
        rawId: 29058,
      );

      expect(terms, hasLength(2));
      expect(terms.first.zh, '林青青');
      expect(terms.first.en, 'Lin Qingqing');
      expect(transport.jsonCalls, 1);
    });

    test('caches per rawId across loads', () async {
      final transport = FakeTransport()..addJson(glossaryUrl, glossaryResponse);
      final service = WtrGlossaryService();

      await service.load(transport, Uri.parse(_base), rawId: 29058);
      await service.load(transport, Uri.parse(_base), rawId: 29058);

      expect(transport.jsonCalls, 1);
    });

    test('is fail-soft when the glossary fetch fails', () async {
      final service = WtrGlossaryService();

      final terms = await service.load(
        FakeTransport(),
        Uri.parse(_base),
        rawId: 29058,
      );

      expect(terms, isEmpty);
    });

    test('clear() forces a refetch', () async {
      final transport = FakeTransport()..addJson(glossaryUrl, glossaryResponse);
      final service = WtrGlossaryService();

      await service.load(transport, Uri.parse(_base), rawId: 29058);
      service.clear();
      await service.load(transport, Uri.parse(_base), rawId: 29058);

      expect(transport.jsonCalls, 2);
    });

    test('loadAll merges every glossary plus the AI replacements', () async {
      final transport = FakeTransport()
        ..addJson(glossaryUrl, {
          'glossaries': [
            {
              'data': {
                'terms': [
                  [
                    ['Lin Qingqing'],
                    '林青青',
                    1,
                    2,
                    1860,
                  ],
                ],
              },
            },
            {
              'data': {
                'terms': [
                  [
                    ['Sutra Library'],
                    '藏经阁',
                    1,
                    1,
                    51,
                  ],
                ],
                'replacements': [
                  {
                    'value': [
                      ['Library of Sutras'],
                      '藏经阁',
                    ],
                    'Count': 2,
                  },
                ],
              },
            },
          ],
        });
      final service = WtrGlossaryService();

      final terms = await service.loadAll(
        transport,
        Uri.parse(_base),
        rawId: 29058,
      );

      expect(terms, hasLength(3));
      expect(terms.map((t) => t.zh), containsAll(['林青青', '藏经阁']));
      // The community replacement parses as its own entry after the terms.
      final sutra = terms.lastWhere((t) => t.zh == '藏经阁');
      expect(sutra.enAliases, ['Library of Sutras']);
      expect(transport.jsonCalls, 1);
    });

    test('loadAll caches per rawId independently of load', () async {
      final transport = FakeTransport()..addJson(glossaryUrl, glossaryResponse);
      final service = WtrGlossaryService();

      await service.load(transport, Uri.parse(_base), rawId: 29058);
      await service.loadAll(transport, Uri.parse(_base), rawId: 29058);
      await service.loadAll(transport, Uri.parse(_base), rawId: 29058);

      expect(transport.jsonCalls, 2);
    });

    test('loadAll is fail-soft when the glossary fetch fails', () async {
      final service = WtrGlossaryService();

      final terms = await service.loadAll(
        FakeTransport(),
        Uri.parse(_base),
        rawId: 29058,
      );

      expect(terms, isEmpty);
    });
  });

  group('WtrWebTranslateService', () {
    const translateUrl = 'https://translate-pa.googleapis.com/v1/translateHtml';

    test(
      'posts all paragraphs in one batch and returns translations',
      () async {
        final transport = FakeTransport()
          ..addPostJson(translateUrl, [
            ['Lu Yan didn\u0027t speak.', 'Please be quiet.'],
          ]);
        const service = WtrWebTranslateService(key: 'test-key');

        final out = await service.translateParagraphs(
          transport,
          paragraphs: ['陆言没说话。', '大家安静一下。'],
        );

        expect(out, ['Lu Yan didn\u0027t speak.', 'Please be quiet.']);
        expect(transport.jsonCalls, 1);
      },
    );

    test('decodes the endpoint\u0027s HTML entities', () async {
      final transport = FakeTransport()
        ..addPostJson(translateUrl, [
          ['He said &#39;hello&#39; &amp; left.'],
        ]);
      const service = WtrWebTranslateService(key: 'test-key');

      final out = await service.translateParagraphs(
        transport,
        paragraphs: ['他说了「你好」然后走了。'],
      );

      expect(out, ["He said 'hello' & left."]);
    });

    test('is fail-soft when the translate endpoint errors', () async {
      const service = WtrWebTranslateService(key: 'test-key');

      final out = await service.translateParagraphs(
        FakeTransport(),
        paragraphs: ['原文。', '第二段。'],
      );

      expect(out, ['原文。', '第二段。']);
    });

    test(
      'returns source text without calling the network when no key is set',
      () async {
        const service = WtrWebTranslateService(key: '');
        final transport = _RecordingTransport(FakeTransport());

        final out = await service.translateParagraphs(
          transport,
          paragraphs: ['原文。', '第二段。'],
        );

        expect(out, ['原文。', '第二段。']);
        expect(transport.jsonPostCalls, 0);
      },
    );

    test('chunks oversized batches into multiple requests', () async {
      var calls = 0;
      final transport = _ChunkingTransport((chunk) {
        calls++;
        return chunk.map((s) => 'translated($s)').toList();
      });
      const service = WtrWebTranslateService(key: 'test-key');

      final paragraphs = List<String>.generate(20, (i) => '段落$i' * 400);
      final out = await service.translateParagraphs(
        transport,
        paragraphs: paragraphs,
      );

      expect(calls, greaterThan(1));
      expect(out, hasLength(20));
      expect(out[0], startsWith('translated('));
      // Chunked paths keep the original text when an index is missing.
      expect(out, containsAllInOrder(out));
    });
  });

  group('WtrLabTemplate glossary + translate', () {
    const glossaryUrl = '$_base/api/v2/reader/terms/29058.json';
    const translateUrl = 'https://translate-pa.googleapis.com/v1/translateHtml';
    const chapterWithNames = '林青青看了一眼陆逸尘，轻轻叹了口气。';

    test('webplus applies the glossary then translates to English', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.webPlus);
      final transport = FakeTransport()
        ..addPostJson(
          _readerUrl,
          _readerResponse(_encryptBody([chapterWithNames])),
        )
        ..addJson(glossaryUrl, {
          'glossaries': [
            {
              'data': {
                'terms': [
                  [
                    ['Lin Qingqing'],
                    '林青青',
                    1,
                    2,
                    1,
                  ],
                  [
                    ['Lu Yichen'],
                    '陆逸尘',
                    1,
                    1,
                    1,
                  ],
                ],
              },
            },
          ],
        })
        ..addPostJson(translateUrl, [
          ['Lin Qingqing looked at Lu Yichen and sighed softly.'],
        ]);
      final template = WtrLabTemplate(
        chapterProvider: provider,
        webTranslateService: _testTranslate,
        translateTransport: transport,
      );
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect(
        doc.renderToText(),
        contains('Lin Qingqing looked at Lu Yichen and sighed softly.'),
      );
    });

    test('web translates without applying the glossary', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.web);
      final transport = _RecordingTransport(
        FakeTransport()
          ..addPostJson(
            _readerUrl,
            _readerResponse(_encryptBody([chapterWithNames])),
          )
          ..addPostJson(translateUrl, [
            ['Lin Qingqing looked at the scene and sighed.'],
          ]),
      );
      final template = WtrLabTemplate(
        chapterProvider: provider,
        webTranslateService: _testTranslate,
        translateTransport: transport,
      );
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      // web translates, but does NOT hit the glossary endpoint.
      expect(
        doc.renderToText(),
        contains('Lin Qingqing looked at the scene and sighed.'),
      );
      expect(
        transport.jsonGetPaths,
        isNot(contains('/api/v2/reader/terms/29058.json')),
      );
    });

    test('AI resolves ※n⛬ markers from glossary_data', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(hasCookies: true),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      await provider.setService(29058, WtrTranslationService.ai);
      final transport = FakeTransport()
        ..addPostJson(
          _readerUrl,
          _aiReaderResponse(['"Zhenni, \u203B5\u26EC is still young."']),
        );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect(doc.renderToText(), contains('"Zhenni, Xiaoxi is still young."'));
    });

    test('AI leaves an out-of-range marker untouched', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(hasCookies: true),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      await provider.setService(29058, WtrTranslationService.ai);
      final transport = FakeTransport()
        ..addPostJson(
          _readerUrl,
          _aiReaderResponse(['"He saw \u203B99\u26EC ahead."']),
        );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect(doc.renderToText(), contains('\u203B99\u26EC'));
    });

    test(
      'AI substitutes leftover source terms from the per-novel glossary',
      () async {
        final auth = WtrAuthenticationManager(
          sessionRepository: InMemoryWtrSessionRepository(),
          auxiliary: _FakeAuxiliary(hasCookies: true),
        );
        await auth.completeLogin();
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: auth,
        );
        await provider.setService(29058, WtrTranslationService.ai);
        final transport = FakeTransport()
          ..addPostJson(
            _readerUrl,
            _aiReaderResponse([
              '"Zhenni, \u203B5\u26EC is still young." 小夕 left.',
            ]),
          )
          ..addJson(glossaryUrl, {
            'glossaries': [
              {
                'data': {
                  'terms': [
                    [
                      ['Xiaoxi'],
                      '小夕',
                      1,
                      1,
                      1,
                    ],
                  ],
                },
              },
            ],
          });
        final template = WtrLabTemplate(chapterProvider: provider);
        final context = buildContext(
          manifest: buildManifest(baseUrl: _base),
          transport: transport,
        );

        final doc = await template.chapterContent(context, _chapterUrl);

        // Marker 5 resolves via glossary_data; the literal 小夕 comes from the
        // per-novel glossary (no account preference is registered).
        expect(
          doc.renderToText(),
          contains('"Zhenni, Xiaoxi is still young." Xiaoxi left.'),
        );
      },
    );

    test(
      'AI applies the account term preference over the glossary value',
      () async {
        final auth = WtrAuthenticationManager(
          sessionRepository: InMemoryWtrSessionRepository(),
          auxiliary: _FakeAuxiliary(hasCookies: true),
        );
        await auth.completeLogin();
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: auth,
        );
        await provider.setService(29058, WtrTranslationService.ai);
        final transport = FakeTransport()
          ..addPostJson(
            _readerUrl,
            _aiReaderResponse([
              '"Zhenni, \u203B5\u26EC is still young." 小夕 arrived.',
            ]),
          )
          ..addJson(glossaryUrl, {
            'glossaries': [
              {
                'data': {
                  'terms': [
                    [
                      ['Xiaoxi'],
                      '小夕',
                      1,
                      1,
                      1,
                    ],
                  ],
                },
              },
            ],
          });
        // Every merged term gets an explicit term-preferences fixture so the
        // path-based FakeTransport fallback can't leak one term's answer to
        // another; only 小夕 carries a preference.
        const terms = ['太爷爷', '林青青', '林子祥', '苏珍妮', '子祥', '小夕', '林泽', '陆言'];
        for (final zh in terms) {
          transport.addJson(
            Uri.parse('$_base/api/v2/term-preferences')
                .replace(
                  queryParameters: {
                    'source_id': 'id.raw.29058',
                    'hash': zh,
                    'lang': 'en',
                  },
                )
                .toString(),
            zh == '小夕'
                ? {
                    'success': true,
                    'data': [
                      {'replacement': 'Xiao Xi', 'count': 7},
                    ],
                  }
                : {'success': true, 'data': []},
          );
        }
        final template = WtrLabTemplate(chapterProvider: provider);
        final context = buildContext(
          manifest: buildManifest(baseUrl: _base),
          transport: transport,
        );

        final doc = await template.chapterContent(context, _chapterUrl);

        // Marker 5 still uses glossary_data; the literal 小夕 gets the account's
        // preferred replacement.
        expect(
          doc.renderToText(),
          contains('"Zhenni, Xiaoxi is still young." Xiao Xi arrived.'),
        );
      },
    );

    test(
      'AI skips term-preferences without an account but still cleans up',
      () async {
        // Bypass `resolveTranslate`'s AI auth gate so the anonymous enhancement
        // path can be exercised: the term-preferences pass must be auth-gated
        // even if the reader routing somehow reaches AI signed out.
        final provider = _AuthBypassingProvider();
        final transport = _RecordingTransport(
          FakeTransport()
            ..addPostJson(
              _readerUrl,
              _aiReaderResponse([
                '"Zhenni, \u203B5\u26EC is still young." 小夕 left.',
              ]),
            )
            ..addJson(glossaryUrl, {
              'glossaries': [
                {
                  'data': {
                    'terms': [
                      [
                        ['Xiaoxi'],
                        '小夕',
                        1,
                        1,
                        1,
                      ],
                    ],
                  },
                },
              ],
            }),
        );
        final template = WtrLabTemplate(chapterProvider: provider);
        final context = buildContext(
          manifest: buildManifest(baseUrl: _base),
          transport: transport,
        );

        final doc = await template.chapterContent(context, _chapterUrl);

        expect(
          doc.renderToText(),
          contains('"Zhenni, Xiaoxi is still young." Xiaoxi left.'),
        );
        expect(
          transport.jsonGetUrls.where(
            (u) => u.contains('/api/v2/term-preferences'),
          ),
          isEmpty,
        );
      },
    );

    test('AI with no leftover CJK skips the glossary network calls', () async {
      final auth = WtrAuthenticationManager(
        sessionRepository: InMemoryWtrSessionRepository(),
        auxiliary: _FakeAuxiliary(hasCookies: true),
      );
      await auth.completeLogin();
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: auth,
      );
      await provider.setService(29058, WtrTranslationService.ai);
      final transport = _RecordingTransport(
        FakeTransport()..addPostJson(
          _readerUrl,
          _aiReaderResponse(['"Zhenni, \u203B5\u26EC is still young."']),
        ),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect(doc.renderToText(), contains('"Zhenni, Xiaoxi is still young."'));
      // Fully-English text needs no glossary or term-preferences GETs, so a
      // chapter stays as fast as it was before the account-glossary pass.
      expect(transport.jsonGetUrls, isEmpty);
    });

    test('webplus stays readable when glossary and translate fail', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.webPlus);
      final transport = FakeTransport()
        ..addPostJson(
          _readerUrl,
          _readerResponse(_encryptBody([chapterWithNames])),
        );
      final template = WtrLabTemplate(
        chapterProvider: provider,
        webTranslateService: _testTranslate,
        translateTransport: FakeTransport(),
      );
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: transport,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect(doc.renderToText(), contains(chapterWithNames));
    });
  });
}

/// Reader response that carries the AI `glossary_data` the site uses to
/// resolve `※n⛬` name placeholders.
Map<String, Object?> _aiReaderResponse(List<String> paragraphs) => {
  'success': true,
  'chapter': {'id': 33607609, 'title': 'Chapter 638: He wrote both of them!?'},
  'data': {
    'raw_id': 29058,
    'data': {
      'body': paragraphs,
      'glossary_data': {
        'terms': [
          ['Great-grandfather', '太爷爷'],
          ['Lin Qingqing', '林青青'],
          ['Lin Zixiang', '林子祥'],
          ['Su Zhenni', '苏珍妮'],
          ['Zixiang', '子祥'],
          ['Xiaoxi', '小夕'],
          ['Lin Ze', '林泽'],
        ],
      },
    },
  },
};

/// Transport whose JSON POSTs translate each chunk into a synthetic
/// `[[translated...]]` response so chunking can be asserted.
class _ChunkingTransport implements Transport {
  _ChunkingTransport(this._translate);

  final List<String> Function(List<String> chunk) _translate;

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    final payload = jsonBody;
    if (payload is! List || payload.isEmpty || payload[0] is! List) {
      throw const TransportException('unexpected translate payload');
    }
    final chunk = (payload[0] as List).map((e) => '$e').toList();
    return [_translate(chunk)];
  }

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) => throw UnimplementedError();

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<List<int>> fetchBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
}
