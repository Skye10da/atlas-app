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
      controller.addHighlight(chapterId: 'c1', start: 0, end: 5, text: 'aaa', colorValue: 1);
      controller.addHighlight(chapterId: 'c1', start: 10, end: 15, text: 'bbb', colorValue: 2);

      expect(controller.state.highlights['c1'], hasLength(2));
    });

    test('eraseOverlapping removes only ranges that overlap', () {
      controller.addHighlight(chapterId: 'c1', start: 0, end: 10, text: 'aaa', colorValue: 1);
      controller.addHighlight(chapterId: 'c1', start: 20, end: 30, text: 'bbb', colorValue: 2);
      controller.addHighlight(chapterId: 'c1', start: 40, end: 50, text: 'ccc', colorValue: 3);

      controller.eraseOverlapping('c1', 8, 12);

      final surviving = controller.state.highlights['c1']!;
      expect(surviving.map((h) => h.text), ['bbb', 'ccc']);
    });

    test('eraseOverlapping removes the chapter list when nothing survives', () {
      controller.addHighlight(chapterId: 'c1', start: 0, end: 10, text: 'aaa', colorValue: 1);

      controller.eraseOverlapping('c1', 5, 15);

      expect(controller.state.highlights, isNot(contains('c1')));
    });

    test('eraseOverlapping is isolated across chapters', () {
      controller.addHighlight(chapterId: 'c1', start: 0, end: 10, text: 'aaa', colorValue: 1);
      controller.addHighlight(chapterId: 'c2', start: 0, end: 10, text: 'bbb', colorValue: 1);

      controller.eraseOverlapping('c1', 5, 15);

      expect(controller.state.highlights, isNot(contains('c1')));
      expect(controller.state.highlights['c2'], hasLength(1));
    });

    test('eraseOverlapping is a no-op for an unknown chapter', () {
      expect(() => controller.eraseOverlapping('nope', 0, 10), returnsNormally);
    });

    test('highlightsIn returns only overlapping entries', () {
      controller.addHighlight(chapterId: 'c1', start: 0, end: 10, text: 'aaa', colorValue: 1);
      controller.addHighlight(chapterId: 'c1', start: 20, end: 30, text: 'bbb', colorValue: 2);

      final found = controller.highlightsIn('c1', 8, 25);
      expect(found.map((h) => h.text), ['aaa', 'bbb']);

      final partial = controller.highlightsIn('c1', 12, 25);
      expect(partial.single.text, 'bbb');
    });

    test('family is isolated per book', () {
      final other = container.read(annotationsProvider('b-2').notifier);

      controller.addHighlight(chapterId: 'c1', start: 0, end: 10, text: 'aaa', colorValue: 1);

      expect(other.state.highlights, isEmpty);
    });

    test('addNote stores notes keyed by chapter', () {
      controller.addNote(chapterId: 'c1', text: 'my note', sentence: 'source sentence');

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
      controller.addHighlight(chapterId: 'c1', start: 0, end: 5, text: 'a', colorValue: 1);
      controller.addNote(chapterId: 'c1', text: 'n', sentence: 's');

      controller.clear();

      expect(controller.state.highlights, isEmpty);
      expect(controller.state.notes, isEmpty);
    });

    test('NoteEntry overlap semantics', () {
      const h = HighlightEntry(chapterId: 'c1', start: 10, end: 20, text: 'x', colorValue: 1);
      expect(h.overlaps(15, 25), isTrue);
      expect(h.overlaps(0, 5), isFalse);
      expect(h.overlaps(20, 30), isFalse);
      expect(h.overlaps(25, 25), isFalse);
    });
  });
}