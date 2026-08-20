import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/speech/speech_models.dart';
import 'package:atlas_app/reader/speech/speech_queue.dart';

SpeechItem _item(int p, int s) => SpeechItem(
  bookId: 'b1',
  chapterId: 'c1',
  paragraphIndex: p,
  sentenceIndex: s,
  text: 'p$p s$s',
  language: 'en-US',
);

void main() {
  group('SpeechQueue', () {
    test('current/itemAt respect bounds', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1)]);
      expect(q.current!.text, 'p0 s0');
      expect(q.itemAt(0)!.text, 'p0 s0');
      expect(q.itemAt(5), isNull);
      expect(q.itemAt(-1), isNull);
    });

    test('next/previous advance the cursor and clamp at the edges', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1), _item(1, 0)]);
      expect(q.next()!.text, 'p0 s1');
      expect(q.next()!.text, 'p1 s0');
      expect(q.next(), isNull); // already at end
      expect(q.cursor, 2);

      expect(q.previous()!.text, 'p0 s1');
      expect(q.previous()!.text, 'p0 s0');
      expect(q.previous(), isNull); // already at start
      expect(q.cursor, 0);
    });

    test('peekNext/peekPrevious do not move the cursor', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1), _item(1, 0)]);
      expect(q.peekNext()!.text, 'p0 s1');
      expect(q.cursor, 0);
      expect(q.peekPrevious(), isNull);
      q.seekTo(2);
      expect(q.peekPrevious()!.text, 'p0 s1');
      expect(q.cursor, 2);
    });

    test('seekTo jumps and reports failure for invalid indexes', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1)]);
      expect(q.seekTo(1), isTrue);
      expect(q.current!.text, 'p0 s1');
      expect(q.seekTo(9), isFalse);
      expect(q.seekTo(-1), isFalse);
      expect(q.cursor, 1);
    });

    test('reset returns to the start', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1)]);
      q.seekTo(1);
      q.reset();
      expect(q.cursor, 0);
    });

    test('remaining returns items from the cursor', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1), _item(1, 0)]);
      q.seekTo(1);
      expect(q.remaining().map((i) => i.text).toList(), ['p0 s1', 'p1 s0']);
    });

    test('isLastInParagraph is true only at a paragraph boundary', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1), _item(1, 0)]);
      expect(q.isLastInParagraph(q.itemAt(0)!), isFalse);
      expect(q.isLastInParagraph(q.itemAt(1)!), isTrue);
      expect(q.isLastInParagraph(q.itemAt(2)!), isTrue);
    });

    test('isAtStart/isAtEnd reflect cursor position', () {
      final q = SpeechQueue([_item(0, 0), _item(0, 1)]);
      expect(q.isAtStart, isTrue);
      expect(q.isAtEnd, isFalse);
      q.seekTo(1);
      expect(q.isAtStart, isFalse);
      expect(q.isAtEnd, isTrue);
    });
  });
}
