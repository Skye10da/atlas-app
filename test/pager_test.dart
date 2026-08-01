import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/widgets/pager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 16, height: 1.5);
  const pageWidth = 320.0;
  const pageHeight = 480.0;

  bool fitsWithin(String page, {TextStyle? textStyle}) {
    final painter = TextPainter(
      text: TextSpan(text: page, style: textStyle ?? style),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: pageWidth);
    return painter.height <= pageHeight + 0.001;
  }

  group('Pager.paginate', () {
    test('returns a single empty page for empty text', () {
      final pages = Pager.paginate(
        text: '',
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );
      expect(pages, ['']);
    });

    test('returns the whole text as one page when it fits', () {
      const text = 'A short sentence that fits on a single page.';
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );
      expect(pages, [text]);
    });

    test('splits long text into pages that fit and round-trip to the original',
        () {
      final text = List.generate(400, (i) => 'word$i').join(' ');
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(pages.length, greaterThan(1));
      expect(pages.join(), text);
      for (final page in pages) {
        expect(fitsWithin(page), isTrue,
            reason: 'page should fit within the page area');
      }
    });

    test('never splits a word across pages', () {
      final text = List.generate(400, (i) => 'word$i').join(' ');
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      for (var i = 0; i < pages.length - 1; i++) {
        expect(pages[i].endsWith(' '), isTrue,
            reason: 'page ${i + 1} should end on a word boundary');
      }
    });

    test('preserves paragraph breaks across pages', () {
      final paragraph = List.generate(60, (i) => 'sentence_$i').join(' ');
      final text = List.generate(8, (i) => 'Chapter $i. $paragraph').join('\n\n');
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(pages.length, greaterThan(1));
      expect(pages.join(), text,
          reason: 'newlines and paragraph breaks must survive pagination');
      expect(text.contains('\n'), isTrue);
    });

    test('makes progress even on an unbreakable token', () {
      final text = 'x' * 5000;
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(pages.length, greaterThan(1));
      expect(pages.join(), text);
      for (final page in pages) {
        expect(fitsWithin(page), isTrue);
      }
    });

    test('handles mixed unbreakable tokens and normal text', () {
      final text = '${'z' * 3000} tail words that page normally';
      final pages = Pager.paginate(
        text: text,
        textStyle: style,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );

      expect(pages.join(), text);
      for (final page in pages) {
        expect(fitsWithin(page), isTrue);
      }
    });
  });
}
