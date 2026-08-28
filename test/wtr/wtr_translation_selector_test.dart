import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_ai_status_tracker.dart';
import 'package:atlas_app/wtr/domain/services/wtr_ai_translate_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

void main() {
  group('WtrTranslationSelector', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      WtrAiStatusTracker.instance.reset();
    });

    tearDown(WtrAiStatusTracker.instance.reset);

    Future<void> pumpSelector(
      WidgetTester tester, {
      List<Override> overrides = const [],
      FutureOr<void> Function()? onServiceChanged,
    }) async {
      final provider = WtrChapterProvider(
        preferenceRepository: InMemoryWtrPreferenceRepository(),
        authManager: WtrAuthenticationManager(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wtrRuntimeProvider.overrideWith((ref) async => provider),
            ...overrides,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WtrTranslationSelector(
                rawId: 29058,
                onServiceChanged: onServiceChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'fires onServiceChanged only when the service actually changes',
      (tester) async {
        var changes = 0;

        await pumpSelector(tester, onServiceChanged: () => changes++);

        // Starts on WebPlus (the signed-out default).
        expect(find.text('Web'), findsOneWidget);

        // Switch WebPlus -> Web fires the callback.
        await tester.tap(find.text('Web'));
        await tester.pumpAndSettle();
        expect(changes, 1);

        // Re-tapping the already-selected service does not fire again.
        await tester.tap(find.text('Web'));
        await tester.pumpAndSettle();
        expect(changes, 1);

        // Web -> AI fires the callback.
        await tester.tap(find.text('AI'));
        await tester.pumpAndSettle();
        expect(changes, 2);
      },
    );

    testWidgets('offers AI+ and prompts for setup while unconfigured', (
      tester,
    ) async {
      await pumpSelector(tester);

      await tester.tap(find.text('AI+'));
      await tester.pumpAndSettle();

      expect(find.text('Set up AI+'), findsOneWidget);
    });

    testWidgets('AI+ row shows the active provider and model once configured', (
      tester,
    ) async {
      await pumpSelector(
        tester,
        overrides: [
          wtrAiSettingsProvider.overrideWith(
            (ref) async => const WtrAiSettings()
                .withProvider(WtrAiProviderId.openRouter)
                .withApiKey(WtrAiProviderId.openRouter, 'sk-or')
                .withModel(WtrAiProviderId.openRouter, 'z-ai/glm-4.5-air'),
          ),
        ],
      );

      await tester.tap(find.text('AI+'));
      await tester.pumpAndSettle();

      expect(find.text('OpenRouter · z-ai/glm-4.5-air'), findsOneWidget);
    });

    testWidgets('AI+ row surfaces the fallback notice from the tracker', (
      tester,
    ) async {
      WtrAiStatusTracker.instance.reportFallback(
        29058,
        WtrAiFailureReason.rateLimited,
      );

      await pumpSelector(
        tester,
        overrides: [
          wtrAiSettingsProvider.overrideWith(
            (ref) async =>
                const WtrAiSettings().withApiKey(WtrAiProviderId.gemini, 'k'),
          ),
        ],
      );

      await tester.tap(find.text('AI+'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Web translation was used'), findsOneWidget);
      expect(find.text('Check setup'), findsOneWidget);
    });
  });
}
