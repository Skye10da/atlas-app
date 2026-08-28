import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_ai_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = SharedPrefsWtrAiSettingsRepository();

  group('SharedPrefsWtrAiSettingsRepository', () {
    test('load returns defaults on an empty store', () async {
      SharedPreferences.setMockInitialValues(const {});

      final settings = await repository.load();

      expect(settings.provider, WtrAiProviderId.gemini);
      expect(settings.activeApiKey, isNull);
      expect(settings.isConfigured, isFalse);
    });

    test('save then load round-trips provider, keys and models', () async {
      SharedPreferences.setMockInitialValues(const {});

      final original = const WtrAiSettings()
          .withProvider(WtrAiProviderId.openRouter)
          .withApiKey(WtrAiProviderId.openRouter, 'sk-or-1')
          .withApiKey(WtrAiProviderId.gemini, 'g-key')
          .withModel(WtrAiProviderId.openRouter, 'z-ai/glm-4.5-air');
      await repository.save(original);

      final loaded = await repository.load();

      expect(loaded.provider, WtrAiProviderId.openRouter);
      expect(loaded.apiKeyFor(WtrAiProviderId.openRouter), 'sk-or-1');
      expect(loaded.apiKeyFor(WtrAiProviderId.gemini), 'g-key');
      expect(loaded.modelFor(WtrAiProviderId.openRouter), 'z-ai/glm-4.5-air');
      // Unset model resolves to the provider default.
      expect(
        loaded.modelFor(WtrAiProviderId.gemini),
        WtrAiProviderId.gemini.defaultModel,
      );
      expect(loaded.isConfigured, isTrue);
    });

    test(
      'a provider-default model is not persisted as an explicit choice',
      () async {
        SharedPreferences.setMockInitialValues(const {});
        final defaultModel = WtrAiProviderId.gemini.defaultModel;

        await repository.save(
          const WtrAiSettings()
              .withApiKey(WtrAiProviderId.gemini, 'k')
              .withModel(WtrAiProviderId.gemini, defaultModel),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('wtr_ai_model_gemini'), isNull);

        final loaded = await repository.load();
        expect(loaded.storedModelFor(WtrAiProviderId.gemini), isNull);
        expect(loaded.modelFor(WtrAiProviderId.gemini), defaultModel);
      },
    );

    test('clear drops every stored AI preference', () async {
      SharedPreferences.setMockInitialValues(const {});
      await repository.save(
        const WtrAiSettings()
            .withApiKey(WtrAiProviderId.anthropic, 'ak')
            .withModel(WtrAiProviderId.anthropic, 'claude-sonnet-4-6'),
      );

      await repository.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wtr_ai_provider'), isNull);
      expect(prefs.getString('wtr_ai_api_key_anthropic'), isNull);
      expect(prefs.getString('wtr_ai_model_anthropic'), isNull);
    });
  });
}
