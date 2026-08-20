import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/glossary_term_sheet.dart';

void main() {
  group('GlossaryTermSheet', () {
    testWidgets('creates a term from the typed replacement', (tester) async {
      final container = ProviderContainer(
        overrides: [
          atlasGlossaryRepositoryProvider.overrideWithValue(
            InMemoryAtlasGlossaryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlossaryTermSheet(bookId: 'b1', term: '中'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'middle');
      await tester.tap(find.widgetWithText(FilledButton, 'Set as term'));
      await tester.pumpAndSettle();

      final entries = await container.read(atlasGlossaryProvider('b1').future);
      expect(entries, hasLength(1));
      expect(entries.single.term, '中');
      expect(entries.single.activeReplacement, 'middle');
      expect(find.text('middle'), findsOneWidget);
    });

    testWidgets('adds more options and shows the active one as selected', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          atlasGlossaryRepositoryProvider.overrideWithValue(
            InMemoryAtlasGlossaryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlossaryTermSheet(bookId: 'b1', term: '中'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'middle');
      await tester.tap(find.widgetWithText(FilledButton, 'Set as term'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'center');
      await tester.tap(find.text('Add option'));
      await tester.pumpAndSettle();

      var entries = await container.read(atlasGlossaryProvider('b1').future);
      expect(entries.single.replacements, ['middle', 'center']);
      expect(entries.single.activeReplacement, 'middle');

      await tester.tap(find.text('center'));
      await tester.pumpAndSettle();

      entries = await container.read(atlasGlossaryProvider('b1').future);
      expect(entries.single.activeReplacement, 'center');
    });

    testWidgets('removing a term deletes the entry', (tester) async {
      final container = ProviderContainer(
        overrides: [
          atlasGlossaryRepositoryProvider.overrideWithValue(
            InMemoryAtlasGlossaryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlossaryTermSheet(bookId: 'b1', term: '中'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'middle');
      await tester.tap(find.widgetWithText(FilledButton, 'Set as term'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove term'));
      await tester.pumpAndSettle();

      expect(await container.read(atlasGlossaryProvider('b1').future), isEmpty);
    });

    testWidgets(
      'selecting the displayed replacement opens the existing term instead '
      'of creating a new one',
      (tester) async {
        final repo = InMemoryAtlasGlossaryRepository();
        await repo.save('b1', [
          AtlasGlossaryEntry(
            id: 'b1:中',
            bookId: 'b1',
            term: '中',
            replacements: const ['middle', 'center'],
            createdAt: DateTime(2025, 1, 1),
          ),
        ]);
        final container = ProviderContainer(
          overrides: [atlasGlossaryRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: GlossaryTermSheet(bookId: 'b1', term: 'middle'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The sheet recognises 'middle' as an existing replacement, so it shows
        // the term's options and an edit affordance rather than a new-term flow.
        expect(find.text('Edit term'), findsOneWidget);
        expect(find.textContaining('Display "中" as'), findsOneWidget);
        expect(find.text('middle'), findsOneWidget);
        expect(find.text('center'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Add option'), findsOneWidget);
        expect(find.text('Remove term'), findsOneWidget);
      },
    );
  });
}
