import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:atlas_app/intelligence/infrastructure/persistence/ai_credentials_store.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('SecureAiCredentialsStore legacy migration', () {
    test('migrates plaintext prefs keys into secure storage and scrubs them', () async {
      SharedPreferences.setMockInitialValues({
        'atlas_intel_gemini_key': 'legacy-gemini-key',
        'atlas_intel_openai_key': 'legacy-openai-key',
        'atlas_intel_ollama_endpoint': 'http://localhost:11434', // non-secret, stays
      });

      final secure = _MockSecureStorage();
      when(() => secure.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      final store = SecureAiCredentialsStore(secureStorage: secure);
      final credentials = await store.loadCredentials();

      expect(credentials[AiSecretKey.gemini], 'legacy-gemini-key');
      expect(credentials[AiSecretKey.openai], 'legacy-openai-key');
      expect(credentials.containsKey(AiSecretKey.openrouter), isFalse);

      // Everything secret was written into secure storage...
      verify(() => secure.write(key: AiSecretKey.gemini.secureKey, value: 'legacy-gemini-key'))
          .called(1);
      verify(() => secure.write(key: AiSecretKey.openai.secureKey, value: 'legacy-openai-key'))
          .called(1);
      // ...and the legacy plaintext keys were scrubbed from prefs.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('atlas_intel_gemini_key'), isNull);
      expect(prefs.getString('atlas_intel_openai_key'), isNull);
      // The non-secret endpoint must survive (secure storage never gets it).
      expect(prefs.getString('atlas_intel_ollama_endpoint'), 'http://localhost:11434');
      verifyNever(() => secure.write(key: 'atlas_intel_ollama_endpoint', value: any(named: 'value')));
    });

    test('existing secure value wins over the legacy copy', () async {
      SharedPreferences.setMockInitialValues({
        'atlas_intel_gemini_key': 'legacy-gemini-key',
      });

      final secure = _MockSecureStorage();
      when(() => secure.read(key: any(named: 'key'))).thenAnswer((inv) async {
        final key = inv.namedArguments[#key] as String;
        return key == AiSecretKey.gemini.secureKey ? 'fresh-gemini-key' : null;
      });
      when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      final store = SecureAiCredentialsStore(secureStorage: secure);
      final credentials = await store.loadCredentials();

      expect(credentials[AiSecretKey.gemini], 'fresh-gemini-key');
      // No overwrite of the fresh secure value with the stale legacy key.
      verifyNever(() => secure.write(key: AiSecretKey.gemini.secureKey, value: 'legacy-gemini-key'));
    });

    test('saveCredential writes to secure storage only', () async {
      SharedPreferences.setMockInitialValues({});

      final secure = _MockSecureStorage();
      when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      final store = SecureAiCredentialsStore(secureStorage: secure);
      await store.saveCredential(AiSecretKey.opencodezen, 'zen-key-123');

      verify(() => secure.write(key: AiSecretKey.opencodezen.secureKey, value: 'zen-key-123'))
          .called(1);
    });

    test('saveCredential with empty value deletes the secret', () async {
      SharedPreferences.setMockInitialValues({});

      final secure = _MockSecureStorage();
      when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      final store = SecureAiCredentialsStore(secureStorage: secure);
      await store.saveCredential(AiSecretKey.anthropic, '');

      verify(() => secure.delete(key: AiSecretKey.anthropic.secureKey)).called(1);
      verifyNever(() => secure.write(key: any(named: 'key'), value: any(named: 'value')));
    });
  });

  group('InMemoryAiCredentialsStore', () {
    test('behaves like a map, trimming values', () async {
      final store = InMemoryAiCredentialsStore();
      await store.saveCredential(AiSecretKey.gemini, '  key  ');
      final loaded = await store.loadCredentials();
      expect(loaded[AiSecretKey.gemini], 'key');
    });
  });
}
