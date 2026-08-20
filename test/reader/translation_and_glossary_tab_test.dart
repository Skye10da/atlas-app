import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/translation_repository.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/glossary_tab.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/language_selector.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageSelector', () {
    testWidgets('shows the current language and persists a change', (
      tester,
    ) async {
      final translations = InMemoryTranslationRepository();
      var changed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationRepositoryProvider.overrideWithValue(translations),
            supportedLanguagesProvider.overrideWith(
              (_) async => SupportedLanguage.defaults,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LanguageSelector(
                bookId: 'b1',
                onLanguageChanged: () => changed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('English'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<SupportedLanguage>));
      await tester.pumpAndSettle();
      final espanol = find.textContaining('Español').last;
      await tester.ensureVisible(espanol);
      await tester.pumpAndSettle();
      await tester.tap(espanol);
      await tester.pumpAndSettle();

      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      expect(await translations.loadTargetLanguage('b1'), spanish);
      expect(changed, isTrue);
    });

    testWidgets('defaults to English when nothing is saved', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportedLanguagesProvider.overrideWith(
              (_) async => SupportedLanguage.defaults,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LanguageSelector(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('English'), findsOneWidget);
    });
  });

  group('GlossaryTab', () {
    testWidgets('lists terms and opens the editor on tap', (tester) async {
      final glossary = InMemoryAtlasGlossaryRepository();
      await glossary.save('b1', [
        AtlasGlossaryEntry(
          id: 'b1:中',
          bookId: 'b1',
          term: '中',
          replacements: const ['middle', 'center'],
          createdAt: DateTime(2025, 1, 1),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atlasGlossaryRepositoryProvider.overrideWithValue(glossary),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GlossaryTab(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('中'), findsOneWidget);
      expect(find.text('middle'), findsOneWidget);
      expect(find.text('2 options'), findsOneWidget);

      await tester.tap(find.text('中'));
      await tester.pumpAndSettle();

      expect(find.text('Edit term'), findsOneWidget);
      expect(find.text('Add option'), findsOneWidget);
    });

    testWidgets('shows an empty state when no terms exist', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: GlossaryTab(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No glossary terms yet'), findsOneWidget);
      expect(find.text('Add term'), findsOneWidget);
    });

    testWidgets('adds a term through the dialog flow', (tester) async {
      final glossary = InMemoryAtlasGlossaryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atlasGlossaryRepositoryProvider.overrideWithValue(glossary),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GlossaryTab(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add term'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '正');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'just');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final entries = await glossary.load('b1');
      expect(entries, hasLength(1));
      expect(entries.single.term, '正');
      expect(entries.single.activeReplacement, 'just');
      expect(find.text('正'), findsOneWidget);
    });

    testWidgets('removes a term from its trailing delete button', (
      tester,
    ) async {
      final glossary = InMemoryAtlasGlossaryRepository();
      await glossary.save('b1', [
        AtlasGlossaryEntry(
          id: 'b1:中',
          bookId: 'b1',
          term: '中',
          replacements: const ['middle'],
          createdAt: DateTime(2025, 1, 1),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atlasGlossaryRepositoryProvider.overrideWithValue(glossary),
          ],
          child: const MaterialApp(
            home: Scaffold(body: GlossaryTab(bookId: 'b1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('中'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(await glossary.load('b1'), isEmpty);
      expect(find.text('中'), findsNothing);
      expect(find.textContaining('No glossary terms yet'), findsOneWidget);
      expect(find.textContaining('removed'), findsOneWidget);
    });
  });
}
