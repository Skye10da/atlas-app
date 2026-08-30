import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/import/epub_html_converter.dart';

void main() {
  const converter = EpubHtmlConverter();

  group('EpubHtmlConverter', () {
    test('converts paragraphs and preserves double newlines', () {
      const html = '''
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <p>First paragraph of the chapter.</p>
            <p>Second paragraph with some details.</p>
          </body>
        </html>
      ''';
      final result = converter.convert(html);
      expect(
        result,
        'First paragraph of the chapter.\n\nSecond paragraph with some details.',
      );
    });

    test('converts headings with hierarchy levels', () {
      const html = '''
        <div>
          <h1>Book Title</h1>
          <h2>Chapter 1: The Beginning</h2>
          <p>Once upon a time...</p>
        </div>
      ''';
      final result = converter.convert(html);
      expect(
        result,
        '# Book Title\n\n## Chapter 1: The Beginning\n\nOnce upon a time...',
      );
    });

    test('preserves inline typography (bold, italic, strikethrough, code)', () {
      const html = '''
        <p>This has <b>bold text</b>, <i>italic text</i>, <s>struck text</s>, and <code>inline code</code>.</p>
      ''';
      final result = converter.convert(html);
      expect(
        result,
        'This has **bold text**, *italic text*, ~~struck text~~, and `inline code`.',
      );
    });

    test('converts blockquotes with quote markers', () {
      const html = '''
        <blockquote>
          <p>To be or not to be,<br/>that is the question.</p>
        </blockquote>
      ''';
      final result = converter.convert(html);
      expect(
        result,
        '> To be or not to be,\n> that is the question.',
      );
    });

    test('converts lists (unordered and ordered)', () {
      const html = '''
        <ul>
          <li>Item Alpha</li>
          <li>Item Beta</li>
        </ul>
        <ol>
          <li>First</li>
          <li>Second</li>
        </ol>
      ''';
      final result = converter.convert(html);
      expect(
        result,
        '• Item Alpha\n• Item Beta\n\n1. First\n2. Second',
      );
    });

    test('converts images and resolves image URLs', () {
      const html = '''
        <p>Before image.</p>
        <img src="../images/map.png" alt="World Map"/>
        <p>After image.</p>
      ''';
      final result = converter.convert(
        html,
        imageResolver: (raw) => EpubHtmlConverter.normalizeImagePath('text/ch1.xhtml', raw),
      );
      expect(
        result,
        'Before image.\n\n![World Map](images/map.png)\n\nAfter image.',
      );
    });

    test('converts SVG embedded images', () {
      const html = '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <image xlink:href="cover.jpg" width="600" height="800"/>
        </svg>
      ''';
      final result = converter.convert(html);
      expect(result, '![](cover.jpg)');
    });

    test('converts horizontal rules', () {
      const html = '''
        <p>Scene one ends.</p>
        <hr/>
        <p>Scene two begins.</p>
      ''';
      final result = converter.convert(html);
      expect(result, 'Scene one ends.\n\n---\n\nScene two begins.');
    });

    test('extracts chapter title accurately', () {
      const html = '''
        <html>
          <head><title>Ignored Book Title</title></head>
          <body>
            <h1>Chapter 5: Whispers in the Dark</h1>
            <p>Story text...</p>
          </body>
        </html>
      ''';
      expect(converter.extractTitle(html), 'Chapter 5: Whispers in the Dark');
    });
  });
}

