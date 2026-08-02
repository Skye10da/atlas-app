import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/normalizer/content_normalizer.dart';

void main() {
  const normalizer = ContentNormalizer();

  group('ContentNormalizer', () {
    test('emits typed blocks for paragraph/heading/quote/list/pre in order',
        () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <h2>Chapter One</h2>
          <p>First paragraph.</p>
          <blockquote>A quote.</blockquote>
          <ul><li>Item one</li></ul>
          <pre>Code block</pre>
        </body></html>
      ''');

      expect(doc.blocks, hasLength(5));
      expect(
        doc.blocks[0],
        isA<HeadingBlock>()
            .having((b) => b.text, 'text', 'Chapter One')
            .having((b) => b.level, 'level', 2),
      );
      expect(
        doc.blocks[1],
        isA<ParagraphBlock>().having((b) => b.text, 'text', 'First paragraph.'),
      );
      expect(
        doc.blocks[2],
        isA<QuoteBlock>().having((b) => b.text, 'text', 'A quote.'),
      );
      expect(
        doc.blocks[3],
        isA<ListBlock>().having((b) => b.text, 'text', 'Item one'),
      );
      expect(
        doc.blocks[4],
        isA<PreBlock>().having((b) => b.text, 'text', 'Code block'),
      );

      expect(doc.textBlocks, hasLength(5));
      expect(doc.wordCount, 10);
    });

    test('nested block is owned by the outer block, not double-counted', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <blockquote><p>Some quote</p></blockquote>
          <li><p>Item</p></li>
        </body></html>
      ''');

      expect(doc.blocks, hasLength(2));
      expect(
        doc.blocks[0],
        isA<QuoteBlock>().having((b) => b.text, 'text', 'Some quote'),
      );
      expect(
        doc.blocks[1],
        isA<ListBlock>().having((b) => b.text, 'text', 'Item'),
      );
    });

    test('loose inline text next to a nested block is preserved', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <li>Intro text <p>nested</p></li>
        </body></html>
      ''');

      expect(doc.blocks, hasLength(1));
      expect(
        doc.blocks.single,
        isA<ListBlock>().having((b) => b.text, 'text', 'Intro text nested'),
      );
    });

    test('extracts images without figure/figcaption', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <p>Intro</p>
          <img src="https://example.com/a.jpg" alt="Alt text">
          <p>Outro</p>
        </body></html>
      ''');

      expect(doc.images, hasLength(1));
      expect(doc.images.single.src, 'https://example.com/a.jpg');
      expect(doc.images.single.alt, 'Alt text');
      expect(doc.images.single.caption, isNull);
      expect(doc.blocks[1], same(doc.images.single));
    });

    test('captures figcaption as the image caption', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <figure>
            <img src="cover.jpg" alt="Cover">
            <figcaption>The cover art</figcaption>
          </figure>
        </body></html>
      ''');

      expect(doc.images, hasLength(1));
      expect(doc.images.single.src, 'cover.jpg');
      expect(doc.images.single.alt, 'Cover');
      expect(doc.images.single.caption, 'The cover art');
    });

    test('falls back to data-src for lazy-loaded images', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <img data-src="lazy.jpg">
        </body></html>
      ''');

      expect(doc.images.single.src, 'lazy.jpg');
    });

    test('detects footnotes via #anchor, rel, and footnote class', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <p>Paragraph.</p>
          <a href="#fn1">1</a>
          <a href="/notes/2" rel="footnote">2</a>
          <a href="http://x/3" class="footnote">3</a>
        </body></html>
      ''');

      expect(
        doc.footnotes.map((f) => f.id),
        ['fn1', '/notes/2', 'http://x/3'],
      );
      expect(doc.footnotes.map((f) => f.text), ['1', '2', '3']);
    });

    test('renderToText joins text blocks with blank lines', () {
      final doc = normalizer.normalizeFromHtml('''
        <html><body>
          <h2>Title</h2>
          <p>First.</p>
          <img src="x.jpg" alt="ignored for text">
          <p>Second.</p>
          <a href="#fn1">1</a>
        </body></html>
      ''');

      expect(doc.renderToText(), 'Title\n\nFirst.\n\nSecond.');
    });
  });
}
