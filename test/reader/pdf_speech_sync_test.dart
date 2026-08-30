import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';

void main() {
  test('SpeechSessionBuilder builds valid SpeechSession for PDF page content', () {
    const builder = SpeechSessionBuilder();
    const bookId = 'pdf_book_1';
    const pageNumber = 5;
    const totalPages = 20;
    const content = 'This is the first sentence of the PDF page. Here is the second sentence.';
    const coverPath = '/path/to/cover.jpg';
    const bookTitle = 'Sample PDF Document';

    const chapter = ChapterEntity(
      id: 'pdf_page_$pageNumber',
      bookId: bookId,
      title: 'Page $pageNumber of $totalPages',
      index: pageNumber - 1,
      contentPath: '',
    );

    final session = builder.build(
      bookId: bookId,
      chapter: chapter,
      content: content,
      language: 'en',
      settings: const NarrationSettings(),
      coverPath: coverPath,
      bookTitle: bookTitle,
      author: null,
    );

    expect(session.bookId, equals('pdf_book_1'));
    expect(session.chapterId, equals('pdf_page_5'));
    expect(session.bookTitle, equals('Sample PDF Document'));
    expect(session.coverPath, equals('/path/to/cover.jpg'));
    expect(session.queue.length, equals(2));
    expect(session.queue.itemAt(0)?.text, contains('first sentence'));
    expect(session.queue.itemAt(1)?.text, contains('second sentence'));
  });
}

