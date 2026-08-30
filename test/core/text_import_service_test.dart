import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/import/text_import_service.dart';

void main() {
  group('TextImportService.splitChapters', () {
    test('splits text with standard English chapter headings', () {
      const text = '''
Chapter 1: The Beginning
This is the first chapter content. It talks about the start of the adventure.

Chapter 2: The Journey
This is the second chapter. The adventure continues into the unknown.
''';

      final chapters = TextImportService.splitChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Chapter 1: The Beginning');
      expect(chapters[0].content, contains('This is the first chapter content.'));
      expect(chapters[1].title, 'Chapter 2: The Journey');
      expect(chapters[1].content, contains('This is the second chapter.'));
    });

    test('preserves Introduction before first chapter heading', () {
      const text = '''
In a hole in the ground there lived a hobbit. Not a nasty, dirty, wet hole.

Chapter 1: An Unexpected Party
Gandalf arrived at the door of Bilbo Baggins.

Chapter 2: Roast Mutton
They traveled across the lone-lands.
''';

      final chapters = TextImportService.splitChapters(text);
      expect(chapters.length, 3);
      expect(chapters[0].title, 'Introduction');
      expect(chapters[0].content, contains('In a hole in the ground'));
      expect(chapters[1].title, 'Chapter 1: An Unexpected Party');
      expect(chapters[2].title, 'Chapter 2: Roast Mutton');
    });

    test('splits markdown headings cleanly stripping hash signs', () {
      const text = '''
# Act I - Awakening
The hero opened their eyes to a glowing blue interface.

## Act II - Departure
They left the quiet village behind forever.
''';

      final chapters = TextImportService.splitChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Act I - Awakening');
      expect(chapters[0].content, contains('The hero opened their eyes'));
      expect(chapters[1].title, 'Act II - Departure');
      expect(chapters[1].content, contains('They left the quiet village'));
    });

    test('splits Chinese and CJK chapter markers', () {
      const text = '''
第一章 穿越异界
主角睁开了双眼，发现自己来到了一个陌生的修真世界。

第二章 宗门大选
今天是一年一度的青云宗弟子招募大会。
''';

      final chapters = TextImportService.splitChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章 穿越异界');
      expect(chapters[0].content, contains('主角睁开了双眼'));
      expect(chapters[1].title, '第二章 宗门大选');
      expect(chapters[1].content, contains('今天是一年一度'));
    });

    test('returns single chapter for short unstructured text', () {
      const text = 'A short story with just a few paragraphs and no chapter headings.';
      final chapters = TextImportService.splitChapters(text, fallbackTitle: 'Short Story');
      expect(chapters.length, 1);
      expect(chapters[0].title, 'Short Story');
      expect(chapters[0].content, text);
    });

    test('chunks long unstructured text by paragraph boundaries', () {
      final paragraph = 'Word ' * 300; // ~1500 chars
      final paragraphs = List.generate(20, (i) => 'Paragraph $i: $paragraph').join('\n\n');

      final chapters = TextImportService.splitChapters(paragraphs, fallbackTitle: 'Long Book');
      expect(chapters.length, greaterThan(1));
      expect(chapters[0].title, 'Chapter 1');
      expect(chapters[1].title, 'Chapter 2');
    });
  });
}

