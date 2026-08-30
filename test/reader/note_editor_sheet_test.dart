import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/widgets/note_editor_sheet.dart';

void main() {
  testWidgets('NoteEditorSheet allows typing a note and saving', (tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NoteEditorSheet(
              bookId: 'b1',
              chapterId: 'c1',
              selectedText: 'The quick brown fox',
              sentence: 'The quick brown fox jumps over the lazy dog.',
              chapterTitle: 'Chapter 1: The Beginning',
            ),
          ),
        ),
      ),
    );

    // Verify excerpt and chapter title
    expect(
      find.text('“The quick brown fox jumps over the lazy dog.”'),
      findsOneWidget,
    );
    expect(find.text('Chapter 1: The Beginning'), findsOneWidget);

    // Enter note text
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'This is an important passage on speed.');

    // Select tag
    await tester.tap(find.text('Quote'));
    await tester.pump();

    // Tap Save Note
    await tester.tap(find.text('Save Note'));
    await tester.pumpAndSettle();

    // Check state in annotations provider
    final state = container.read(annotationsProvider('b1'));
    final notes = state.notes['c1'];
    expect(notes, isNotNull);
    expect(notes!.length, 1);
    expect(notes.first.text, 'This is an important passage on speed.');
    expect(notes.first.sentence, 'The quick brown fox jumps over the lazy dog.');
    expect(notes.first.tags, contains('Quote'));
  });
}

