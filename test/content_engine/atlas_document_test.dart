import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/models/atlas_document.dart';

void main() {
  group('AtlasDocument JSON codec', () {
    test('round-trips a document with every block type', () {
      const doc = AtlasDocument(
        title: 'Chapter One',
        metadata: DocumentMetadata(
          sourceUrl: 'https://example.com/chapter/1',
          sourceName: 'Example',
          language: 'en',
          publishedAt: null,
          tags: ['fantasy'],
          author: 'A. Author',
        ),
        blocks: [
          ParagraphBlock(text: 'Plain paragraph.'),
          HeadingBlock(text: 'Chapter One', level: 2),
          QuoteBlock(text: 'A quote.'),
          ListBlock(text: 'Item'),
          PreBlock(text: 'code'),
          ImageBlock(src: 'a.jpg', alt: 'alt', caption: 'cap'),
          FootnoteBlock(id: 'fn1', text: 'A note.'),
        ],
        annotations: [Annotation(text: 'note', type: 'x', target: 'y')],
      );

      final decoded = AtlasDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, Object?>,
      );

      expect(decoded.title, 'Chapter One');
      expect(decoded.metadata.sourceUrl, 'https://example.com/chapter/1');
      expect(decoded.metadata.sourceName, 'Example');
      expect(decoded.metadata.language, 'en');
      expect(decoded.metadata.tags, ['fantasy']);
      expect(decoded.metadata.author, 'A. Author');

      expect(decoded.blocks, hasLength(7));
      expect(
        decoded.blocks[0],
        isA<ParagraphBlock>().having((b) => b.text, 'text', 'Plain paragraph.'),
      );
      expect(
        decoded.blocks[1],
        isA<HeadingBlock>()
            .having((b) => b.text, 'text', 'Chapter One')
            .having((b) => b.level, 'level', 2),
      );
      expect(
        decoded.blocks[2],
        isA<QuoteBlock>().having((b) => b.text, 'text', 'A quote.'),
      );
      expect(
        decoded.blocks[3],
        isA<ListBlock>().having((b) => b.text, 'text', 'Item'),
      );
      expect(
        decoded.blocks[4],
        isA<PreBlock>().having((b) => b.text, 'text', 'code'),
      );
      expect(
        decoded.blocks[5],
        isA<ImageBlock>()
            .having((b) => b.src, 'src', 'a.jpg')
            .having((b) => b.alt, 'alt', 'alt')
            .having((b) => b.caption, 'caption', 'cap'),
      );
      expect(
        decoded.blocks[6],
        isA<FootnoteBlock>()
            .having((b) => b.id, 'id', 'fn1')
            .having((b) => b.text, 'text', 'A note.'),
      );

      expect(decoded.annotations.single.text, 'note');
      expect(decoded.wordCount, decoded.blocks
          .whereType<TextBlock>()
          .fold(0, (n, b) => n + b.text.split(RegExp(r'\s+')).length));
    });

    test('unknown block type throws', () {
      expect(
        () => ContentBlock.fromJson(const {'type': 'nope', 'text': 'x'}),
        throwsFormatException,
      );
    });

    test('missing or null fields decode defensively', () {
      final doc = AtlasDocument.fromJson(const {
        'title': 42,
        'blocks': 'not-a-list',
        'annotations': null,
        'metadata': null,
      });

      expect(doc.title, '');
      expect(doc.blocks, isEmpty);
      expect(doc.annotations, isEmpty);
      expect(doc.metadata.tags, isEmpty);
    });
  });
}
