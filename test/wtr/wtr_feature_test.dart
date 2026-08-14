import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'package:atlas_app/core/content_engine/templates/wtrlab_template.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_auth_state.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_exceptions.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_session_record.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

import '../content_engine/test_fixtures.dart';

const _base = 'https://wtr-lab.com';
const _novelUrl = '$_base/en/novel/29058/'
    'charm-is-full-i-have-become-a-male-god-since-high-school';
const _chapterUrl = '$_novelUrl/chapter-639';
const _readerUrl = '$_base/api/reader/get';

const _aesKey = 'IJAFUUxjM25hyzL2AZrn0wl7cESED6Ru';
const _paragraphs = ['陆言没说话，拿起话筒，轻轻拍了拍。', '“大家安静一下，我有件事情要说。”'];

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

/// Wraps [paragraphs] in the site's encrypted `arr:<iv>:<tag>:<ct>` body.
String _encryptBody(List<String> paragraphs) {
  final key = utf8.encode(_aesKey);
  final iv = Uint8List.fromList(
    List<int>.generate(12, (i) => (i * 7 + 3) % 256),
  );
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(KeyParameter(Uint8List.fromList(key)), 128, iv, Uint8List(0)),
  );
  final ctWithTag = cipher.process(utf8.encode(jsonEncode(paragraphs)));
  final tag = Uint8List.fromList(ctWithTag.sublist(ctWithTag.length - 16));
  final ct = Uint8List.fromList(ctWithTag.sublist(0, ctWithTag.length - 16));
  return 'arr:${base64Encode(iv)}:${base64Encode(tag)}:${base64Encode(ct)}';
}

Map<String, Object?> _readerResponse(String body) => {
      'success': true,
      'chapter': {'id': 33607609, 'title': 'Chapter 638: He wrote both of them!?'},
      'data': {'raw_id': 29058, 'data': {'body': body}},
    };

/// Records the JSON body of every `fetchJsonPost` so tests can assert what
/// `translate` value the template actually POSTs.
class _RecordingTransport implements Transport {
  _RecordingTransport(this.inner);

  final Transport inner;
  Object? lastJsonBody;
  int jsonPostCalls = 0;

  @override
  Future<String> fetchHtml(Uri url, {Map<String, String>? headers}) =>
      inner.fetchHtml(url, headers: headers);

  @override
  Future<String> fetchHtmlPost(
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
  }) =>
      inner.fetchHtmlPost(url, headers: headers, form: form);

  @override
  Future<Object?> fetchJson(Uri url, {Map<String, String>? headers}) =>
      inner.fetchJson(url, headers: headers);

  @override
  Future<Object?> fetchJsonPost(
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    jsonPostCalls++;
    lastJsonBody = jsonBody;
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
      expect(WtrTranslationService.fromApiValue('ai'), WtrTranslationService.ai);
      expect(WtrTranslationService.fromApiValue('web'), WtrTranslationService.web);
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

    test('restores authenticated when the stored session is provable', () async {
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
    });

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
        expect(auth.ensureAuthenticatedOrThrow, throwsA(isA<WtrAuthException>()),
            reason: 'state $state must be gated');
      }
    });
  });

  group('WtrChapterProvider', () {
    test('defaults to Web and persists the selection per rawId', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      expect(await provider.serviceFor(29058), WtrTranslationService.web);

      await provider.setService(29058, WtrTranslationService.webPlus);
      expect(await provider.serviceFor(29058), WtrTranslationService.webPlus);
      expect(await provider.serviceFor(9999), WtrTranslationService.web);
    });

    test('resolveTranslate reflects the selected service', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      expect(await provider.resolveTranslate(29058), 'web');
      await provider.setService(29058, WtrTranslationService.webPlus);
      expect(await provider.resolveTranslate(29058), 'webplus');
    });

    test('AI resolveTranslate throws before network when unauthenticated',
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
    });

    test('AI resolveTranslate passes when a session is authenticated', () async {
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
    });
  });

  group('WtrLabTemplate translation routing', () {
    test('default template still POSTs translate=web', () async {
      final recording = _RecordingTransport(
        FakeTransport()..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      const template = WtrLabTemplate();
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      final body = recording.lastJsonBody! as Map;
      expect(body['translate'], 'web');
      expect(doc.renderToText(), contains('陆言没说话'));
    });

    test('POSTs the selected webplus service', () async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await provider.setService(29058, WtrTranslationService.webPlus);
      final recording = _RecordingTransport(
        FakeTransport()..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      await template.chapterContent(context, _chapterUrl);

      expect((recording.lastJsonBody! as Map)['translate'], 'webplus');
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
        FakeTransport()..addPostJson(_readerUrl, _readerResponse(_encryptBody(_paragraphs))),
      );
      final template = WtrLabTemplate(chapterProvider: provider);
      final context = buildContext(
        manifest: buildManifest(baseUrl: _base),
        transport: recording,
      );

      final doc = await template.chapterContent(context, _chapterUrl);

      expect((recording.lastJsonBody! as Map)['translate'], 'ai');
      expect(doc.renderToText(), contains('大家安静一下'));
    });

    test('maps the 1401 not-logged-in response to a WTR session failure',
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
        FakeTransport()
          ..addPostJson(_readerUrl, {'code': 1401, 'error': 'You are not logged in!'}),
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
    });
  });
}
