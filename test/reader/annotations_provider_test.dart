import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';

void main() {
  late ProviderContainer container;
  late ReaderAnnotationsController controller;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(annotationsProvider('book-1').notifier);
  });

  tearDown(() => container.dispose());

  group('ReaderAnnotationsController', () {
    test('addHighlight stores a highlight keyed by chapter', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 10,
        end: 20,
        text: 'selected words',
        colorValue: 0xFFFFF176,
      );

      final state = controller.state;
      final highlights = state.highlights['c1'];
      expect(highlights, hasLength(1));
      expect(highlights!.single.start, 10);
      expect(highlights.single.end, 20);
      expect(highlights.single.text, 'selected words');
      expect(highlights.single.color, const Color(0xFFFFF176));
      expect(state.highlights, isNot(contains('c2')));
    });

    test('rejects degenerate ranges', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 5,
        end: 5,
        text: '',
        colorValue: 0,
      );
      expect(controller.state.highlights, isEmpty);
    });

    test('adds highlights to the same chapter, keeping both', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 5,
        text: 'aaa',
        colorValue: 1,
      );
      controller.addHighlight(
        chapterId: 'c1',
        start: 10,
        end: 15,
        text: 'bbb',
        colorValue: 2,
      );

      expect(controller.state.highlights['c1'], hasLength(2));
    });

    test('eraseOverlapping removes only ranges that overlap', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 10,
        text: 'aaa',
        colorValue: 1,
      );
      controller.addHighlight(
        chapterId: 'c1',
        start: 20,
        end: 30,
        text: 'bbb',
        colorValue: 2,
      );
      controller.addHighlight(
        chapterId: 'c1',
        start: 40,
        end: 50,
        text: 'ccc',
        colorValue: 3,
      );

      controller.eraseOverlapping('c1', 8, 12);

      final surviving = controller.state.highlights['c1']!;
      expect(surviving.map((h) => h.text), ['bbb', 'ccc']);
    });

    test('eraseOverlapping removes the chapter list when nothing survives', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 10,
        text: 'aaa',
        colorValue: 1,
      );

      controller.eraseOverlapping('c1', 5, 15);

      expect(controller.state.highlights, isNot(contains('c1')));
    });

    test('eraseOverlapping is isolated across chapters', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 10,
        text: 'aaa',
        colorValue: 1,
      );
      controller.addHighlight(
        chapterId: 'c2',
        start: 0,
        end: 10,
        text: 'bbb',
        colorValue: 1,
      );

      controller.eraseOverlapping('c1', 5, 15);

      expect(controller.state.highlights, isNot(contains('c1')));
      expect(controller.state.highlights['c2'], hasLength(1));
    });

    test('eraseOverlapping is a no-op for an unknown chapter', () {
      expect(() => controller.eraseOverlapping('nope', 0, 10), returnsNormally);
    });

    test('highlightsIn returns only overlapping entries', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 10,
        text: 'aaa',
        colorValue: 1,
      );
      controller.addHighlight(
        chapterId: 'c1',
        start: 20,
        end: 30,
        text: 'bbb',
        colorValue: 2,
      );

      final found = controller.highlightsIn('c1', 8, 25);
      expect(found.map((h) => h.text), ['aaa', 'bbb']);

      final partial = controller.highlightsIn('c1', 12, 25);
      expect(partial.single.text, 'bbb');
    });

    test('family is isolated per book', () {
      final other = container.read(annotationsProvider('b-2').notifier);

      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 10,
        text: 'aaa',
        colorValue: 1,
      );

      expect(other.state.highlights, isEmpty);
    });

    test('addNote stores notes keyed by chapter', () {
      controller.addNote(
        chapterId: 'c1',
        text: 'my note',
        sentence: 'source sentence',
      );

      final notes = controller.state.notes['c1'];
      expect(notes, hasLength(1));
      expect(notes!.single.text, 'my note');
      expect(notes.single.sentence, 'source sentence');
      expect(notes.single.id, isNotEmpty);
    });

    test('deleteNote removes a single note by id', () {
      controller.addNote(chapterId: 'c1', text: 'first', sentence: 's1');
      controller.addNote(chapterId: 'c1', text: 'second', sentence: 's2');
      final id = controller.state.notes['c1']!.first.id;

      controller.deleteNote('c1', id);

      final remaining = controller.state.notes['c1']!;
      expect(remaining.single.text, 'second');
    });

    test('deleteNote drops the chapter list when empty', () {
      controller.addNote(chapterId: 'c1', text: 'only', sentence: 's1');
      final id = controller.state.notes['c1']!.single.id;

      controller.deleteNote('c1', id);

      expect(controller.state.notes, isNot(contains('c1')));
    });

    test('clear resets everything', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 0,
        end: 5,
        text: 'a',
        colorValue: 1,
      );
      controller.addNote(chapterId: 'c1', text: 'n', sentence: 's');

      controller.clear();

      expect(controller.state.highlights, isEmpty);
      expect(controller.state.notes, isEmpty);
    });

    test('addHighlight with styleType stores and preserves style', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 10,
        end: 25,
        text: 'wavy words',
        colorValue: 0xFF00FF00,
        styleType: HighlightStyleType.wavy,
      );

      final hl = controller.state.highlights['c1']!.single;
      expect(hl.styleType, HighlightStyleType.wavy);
      expect(controller.totalHighlightsCount, 1);
    });

    test('updateHighlight updates color, and styleType', () {
      controller.addHighlight(
        chapterId: 'c1',
        start: 10,
        end: 20,
        text: 'original',
        colorValue: 0xFF112233,
        styleType: HighlightStyleType.solid,
      );

      controller.updateHighlight(
        chapterId: 'c1',
        start: 10,
        end: 20,
        colorValue: 0xFFAABBCC,
        styleType: HighlightStyleType.underline,
      );

      final updated = controller.state.highlights['c1']!.single;
      expect(updated.colorValue, 0xFFAABBCC);
      expect(updated.styleType, HighlightStyleType.underline);
    });

    test('addNote with tags and colorValue, and updateNote', () {
      controller.addNote(
        chapterId: 'c1',
        text: 'My tag note',
        sentence: 'Sample context',
        colorValue: 0xFFFF5500,
        tags: ['Quote', 'Favorite'],
      );

      final note = controller.state.notes['c1']!.single;
      expect(note.tags, ['Quote', 'Favorite']);
      expect(note.colorValue, 0xFFFF5500);
      expect(controller.totalNotesCount, 1);

      controller.updateNote(
        chapterId: 'c1',
        noteId: note.id,
        text: 'Updated note text',
        tags: ['Idea'],
      );

      final updated = controller.state.notes['c1']!.single;
      expect(updated.text, 'Updated note text');
      expect(updated.tags, ['Idea']);
    });

    test('NoteEntry overlap semantics', () {
      const h = HighlightEntry(
        chapterId: 'c1',
        start: 10,
        end: 20,
        text: 'x',
        colorValue: 1,
      );
      expect(h.overlaps(15, 25), isTrue);
      expect(h.overlaps(0, 5), isFalse);
      expect(h.overlaps(20, 30), isFalse);
      expect(h.overlaps(25, 25), isFalse);
    });

    test('HighlightEntry and NoteEntry JSON serialization round-trip', () {
      const highlight = HighlightEntry(
        chapterId: 'pdf_page_3',
        start: 120,
        end: 180,
        text: 'Important PDF paragraph',
        colorValue: 0xFFFFD54F,
        styleType: HighlightStyleType.wavy,
        bounds: [10.0, 20.0, 300.0, 220.0],
      );

      final hlJson = highlight.toJson();
      final hlRestored = HighlightEntry.fromJson(hlJson);

      expect(hlRestored.chapterId, 'pdf_page_3');
      expect(hlRestored.start, 120);
      expect(hlRestored.end, 180);
      expect(hlRestored.text, 'Important PDF paragraph');
      expect(hlRestored.colorValue, 0xFFFFD54F);
      expect(hlRestored.styleType, HighlightStyleType.wavy);
      expect(hlRestored.bounds, [10.0, 20.0, 300.0, 220.0]);

      final note = NoteEntry(
        id: 'note_1',
        chapterId: 'pdf_page_3',
        text: 'Crucial observation',
        sentence: 'Important PDF paragraph',
        createdAt: DateTime(2026, 8, 29, 10, 0),
        colorValue: 0xFF81C784,
        tags: const ['Research', 'Key'],
        styleType: HighlightStyleType.bold,
      );

      final noteJson = note.toJson();
      final noteRestored = NoteEntry.fromJson(noteJson);

      expect(noteRestored.id, 'note_1');
      expect(noteRestored.chapterId, 'pdf_page_3');
      expect(noteRestored.text, 'Crucial observation');
      expect(noteRestored.sentence, 'Important PDF paragraph');
      expect(noteRestored.colorValue, 0xFF81C784);
      expect(noteRestored.tags, ['Research', 'Key']);
      expect(noteRestored.styleType, HighlightStyleType.bold);
    });

    test('PDF highlights and notes stored with page keys', () {
      controller.addHighlight(
        chapterId: 'pdf_page_1',
        start: 0,
        end: 50,
        text: 'PDF Page 1 Header text',
        colorValue: 0xFF64B5F6,
        styleType: HighlightStyleType.underline,
        bounds: [50.0, 100.0, 400.0, 120.0],
      );

      controller.addNote(
        chapterId: 'pdf_page_1',
        text: 'Page 1 marginalia',
        sentence: 'PDF Page 1 Header text',
        tags: ['Intro'],
      );

      expect(controller.state.highlights['pdf_page_1'], hasLength(1));
      expect(controller.state.notes['pdf_page_1'], hasLength(1));

      final marker = controller.state.highlights['pdf_page_1']!.first;
      expect(marker.bounds, [50.0, 100.0, 400.0, 120.0]);
      expect(marker.styleType, HighlightStyleType.underline);
    });
  });
}
