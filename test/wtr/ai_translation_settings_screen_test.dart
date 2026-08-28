import 'package:atlas_app/settings/presentation/screens/ai_translation_settings_screen.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_ai_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saving a key persists the selected provider together with it', (
    tester,
  ) async {
    // Regression: switching providers only updated local UI state, so a
    // saved key landed under e.g. openRouter while `provider` stayed
    // gemini — and translation always reported "No API key configured".
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AiTranslationSettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownMenu<WtrAiProviderId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRouter').last);
    await tester.pumpAndSettle();

    final keyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'OpenRouter API key',
    );
    await tester.enterText(keyField, 'sk-or-test');

    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();

    expect(
      (await SharedPreferences.getInstance()).getString('wtr_ai_provider'),
      'openrouter',
    );

    final settings = await const SharedPrefsWtrAiSettingsRepository().load();
    expect(settings.provider.id, 'openrouter');
    expect(settings.activeApiKey, 'sk-or-test');
  });
}
