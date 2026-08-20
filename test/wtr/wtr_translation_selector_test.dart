import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

void main() {
  group('WtrTranslationSelector', () {
    testWidgets(
      'fires onServiceChanged only when the service actually changes',
      (tester) async {
        final provider = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: WtrAuthenticationManager(),
        );
        var changes = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wtrRuntimeProvider.overrideWith((ref) async => provider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: WtrTranslationSelector(
                  rawId: 29058,
                  onServiceChanged: () => changes++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Starts on WebPlus (the signed-out default).
        expect(find.text('Web'), findsOneWidget);

        // Switch WebPlus -> Web fires the callback.
        await tester.tap(find.text('Web'));
        await tester.pumpAndSettle();
        expect(changes, 1);
        expect(await provider.serviceFor(29058), WtrTranslationService.web);

        // Re-tapping the already-selected service does not fire again.
        await tester.tap(find.text('Web'));
        await tester.pumpAndSettle();
        expect(changes, 1);

        // Web -> AI fires the callback.
        await tester.tap(find.text('AI'));
        await tester.pumpAndSettle();
        expect(changes, 2);

        // AI -> WebPlus fires the callback.
        await tester.tap(find.text('WebPlus'));
        await tester.pumpAndSettle();
        expect(changes, 3);
        expect(await provider.serviceFor(29058), WtrTranslationService.webPlus);
      },
    );
  });
}
