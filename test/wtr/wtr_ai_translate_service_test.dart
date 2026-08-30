import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_glossary_term.dart';
import 'package:atlas_app/wtr/domain/services/ai_chat_client.dart';
import 'package:atlas_app/wtr/domain/services/wtr_ai_translate_service.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_ai_settings_repository.dart';

/// Scripted [AiChatClient]: each call pops the next behavior — a returned
/// String is a completion, a thrown object is a failure. Records every
/// request and every injected sleep so retry policy is assertable.
class _ScriptedClient implements AiChatClient {
  _ScriptedClient(this._behaviors);

  final List<Object> _behaviors;
  var _cursor = 0;
  final requests = <({String system, String prompt})>[];
  final sleeps = <Duration>[];

  @override
  Future<String> complete(
    Transport transport, {
    required String apiKey,
    required String model,
    required String system,
    required String prompt,
  }) async {
    requests.add((system: system, prompt: prompt));
    if (_cursor >= _behaviors.length) {
      throw StateError('No scripted behavior left');
    }
    final behavior = _behaviors[_cursor++];
    if (behavior is String) return behavior;
    throw behavior;
  }

  @override
  Future<List<String>> listModels(
    Transport transport, {
    required String apiKey,
  }) async => const [];
}

class _RecordingDelay {
  final sleeps = <Duration>[];
  Future<void> call(Duration duration) async => sleeps.add(duration);
}

Future<WtrAiTranslateService> _service({
  required Map<WtrAiProviderId, AiChatClient> clients,
  _RecordingDelay? delay,
}) async {
  SharedPreferences.setMockInitialValues({
    'wtr_ai_provider': WtrAiProviderId.gemini.id,
    'wtr_ai_api_key_${WtrAiProviderId.gemini.id}': 'test-key',
  });
  return WtrAiTranslateService(
    settingsRepository: const SharedPrefsWtrAiSettingsRepository(),
    clients: clients,
    delay: delay?.call,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WtrAiTranslateService', () {
    test('translates numbered paragraphs in order', () async {
      final client = _ScriptedClient(['<1>one\n<2>two\n<3>three']);
      final service = await _service(clients: {WtrAiProviderId.gemini: client});

      final out = await service.translateParagraphs(
        _NoTransport(),
        paragraphs: const ['一', '二', '三'],
      );

      expect(out, ['one', 'two', 'three']);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.prompt, '<1>一\n<2>二\n<3>三');
    });

    test('system prompt carries glossary rules and target language', () async {
      final client = _ScriptedClient(['<1>ok']);
      final service = await _service(clients: {WtrAiProviderId.gemini: client});
      await service.translateParagraphs(
        _NoTransport(),
        paragraphs: const ['一'],
        terms: const [
          WtrGlossaryTerm(zh: '张三', enAliases: ['Zhang San']),
        ],
        to: 'en',
      );

      final system = client.requests.single.system;
      expect(system, contains('English'));
      expect(system, contains('张三 = Zhang San'));
      expect(system, contains('<1>'));
    });

    test(
      'throws notConfigured before any network when no key is stored',
      () async {
        SharedPreferences.setMockInitialValues(const {});
        final client = _ScriptedClient(['<1>x']);
        final service = WtrAiTranslateService(
          settingsRepository: const SharedPrefsWtrAiSettingsRepository(),
          clients: {WtrAiProviderId.gemini: client},
        );

        await expectLater(
          service.translateParagraphs(_NoTransport(), paragraphs: const ['一']),
          throwsA(
            isA<WtrAiTranslateException>().having(
              (e) => e.reason,
              'reason',
              WtrAiFailureReason.notConfigured,
            ),
          ),
        );
        expect(client.requests, isEmpty);
      },
    );

    test(
      'honors Retry-After on 429 and succeeds on the second attempt',
      () async {
        final delay = _RecordingDelay();
        final client = _ScriptedClient([
          const TransportException(
            'rate limited',
            statusCode: 429,
            retryAfter: Duration(seconds: 7),
          ),
          '<1>recovered',
        ]);
        final service = await _service(
          clients: {WtrAiProviderId.gemini: client},
          delay: delay,
        );

        final out = await service.translateParagraphs(
          _NoTransport(),
          paragraphs: const ['一'],
        );

        expect(out, ['recovered']);
        expect(client.requests, hasLength(2));
        expect(delay.sleeps, [const Duration(seconds: 7)]);
      },
    );

    test(
      'ignores an oversized Retry-After in favor of linear backoff',
      () async {
        final delay = _RecordingDelay();
        final client = _ScriptedClient([
          const TransportException(
            'rate limited',
            statusCode: 429,
            retryAfter: Duration(minutes: 5),
          ),
          '<1>ok',
        ]);
        final service = await _service(
          clients: {WtrAiProviderId.gemini: client},
          delay: delay,
        );

        await service.translateParagraphs(
          _NoTransport(),
          paragraphs: const ['一'],
        );

        // A five-minute cooldown would stall reading; fall back to backoff.
        expect(delay.sleeps, [const Duration(seconds: 2)]);
      },
    );

    test('gives up after maxAttempts with rateLimited reason', () async {
      final delay = _RecordingDelay();
      final client = _ScriptedClient([
        const TransportException('rate limited', statusCode: 429),
        const TransportException('rate limited', statusCode: 429),
        const TransportException('rate limited', statusCode: 429),
      ]);
      final service = await _service(
        clients: {WtrAiProviderId.gemini: client},
        delay: delay,
      );

      await expectLater(
        service.translateParagraphs(_NoTransport(), paragraphs: const ['一']),
        throwsA(
          isA<WtrAiTranslateException>()
              .having((e) => e.reason, 'reason', WtrAiFailureReason.rateLimited)
              .having((e) => e.message, 'message', contains('Rate limited')),
        ),
      );
      expect(client.requests, hasLength(3));
      // No Retry-After hints → linear backoff 2s then 4s.
      expect(delay.sleeps, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('auth failures fail immediately without retries', () async {
      final delay = _RecordingDelay();
      final client = _ScriptedClient([
        const TransportException('denied', statusCode: 401),
        '<1>never reached',
      ]);
      final service = await _service(
        clients: {WtrAiProviderId.gemini: client},
        delay: delay,
      );

      await expectLater(
        service.translateParagraphs(_NoTransport(), paragraphs: const ['一']),
        throwsA(
          isA<WtrAiTranslateException>().having(
            (e) => e.reason,
            'reason',
            WtrAiFailureReason.auth,
          ),
        ),
      );
      expect(client.requests, hasLength(1));
      expect(delay.sleeps, isEmpty);
    });

    test('network-level failures are transient and retried', () async {
      final delay = _RecordingDelay();
      final client = _ScriptedClient([
        const TransportException('socket closed'),
        '<1>fine',
      ]);
      final service = await _service(
        clients: {WtrAiProviderId.gemini: client},
        delay: delay,
      );

      final out = await service.translateParagraphs(
        _NoTransport(),
        paragraphs: const ['一'],
      );
      expect(out, ['fine']);
      expect(delay.sleeps, [const Duration(seconds: 2)]);
    });

    test('a wrong paragraph count fails loudly as badResponse', () async {
      final client = _ScriptedClient(['<1>only one']);
      final service = await _service(clients: {WtrAiProviderId.gemini: client});

      await expectLater(
        service.translateParagraphs(
          _NoTransport(),
          paragraphs: const ['一', '二'],
        ),
        throwsA(
          isA<WtrAiTranslateException>().having(
            (e) => e.reason,
            'reason',
            WtrAiFailureReason.badResponse,
          ),
        ),
      );
    });

    test('translates multiple chunks in order', () async {
      // Two ~2000-char paragraphs exceed the 2500-char budget → 2 chunks,
      // each answered by its own scripted completion.
      final client = _ScriptedClient(['<1>AA', '<2>BB']);
      final service = await _service(clients: {WtrAiProviderId.gemini: client});

      final out = await service.translateParagraphs(
        _NoTransport(),
        paragraphs: ['x' * 2000, 'y' * 2000],
      );

      expect(out, ['AA', 'BB']);
      expect(client.requests, hasLength(2));
      expect(client.requests[0].prompt, startsWith('<1>xxx'));
      expect(client.requests[1].prompt, startsWith('<2>yyy'));
    });

    test('chunk keeps an oversized paragraph intact in its own chunk', () {
      final service = WtrAiTranslateService();

      final huge = 'z' * 5000;
      final chunks = service.chunk(['small', huge, 'also small']);

      expect(chunks.map((c) => c.paragraphs), [
        ['small'],
        [huge],
        ['also small'],
      ]);
    });

    test(
      'parseNumbered tolerates whitespace and reordering but not loss',
      () async {
        final service = WtrAiTranslateService();

        expect(service.parseNumbered(' <2> two \n<1>one', expectedCount: 2), [
          'one',
          'two',
        ]);
        expect(
          () => service.parseNumbered('<1>one', expectedCount: 2),
          throwsA(isA<WtrAiTranslateException>()),
        );
      },
    );

    test('parseNumbered preserves multi-line paragraphs and continuation lines', () {
      final service = WtrAiTranslateService();
      const raw = '''
<1> This is line 1 of paragraph 1.
And this is continuation line 2 of paragraph 1.
<2> Paragraph 2 line 1.
Paragraph 2 line 2.
''';
      final result = service.parseNumbered(raw, expectedCount: 2);
      expect(result, [
        'This is line 1 of paragraph 1.\nAnd this is continuation line 2 of paragraph 1.',
        'Paragraph 2 line 1.\nParagraph 2 line 2.',
      ]);
    });
  });
}

/// Never called by [_ScriptedClient]; satisfies the interface.
class _NoTransport implements Transport {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
