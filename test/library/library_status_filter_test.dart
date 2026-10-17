import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/view_models/library_state.dart';

BookEntity _book({
  required String id,
  double? progress,
  bool hasUpdate = false,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return BookEntity(
    id: id,
    title: 'Title $id',
    format: 'epub',
    totalChapters: 10,
    itemType: ContentCategory.novel,
    progress: progress,
    hasUpdate: hasUpdate,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  group('LibraryStatusFilterX.label', () {
    test('gives every bucket a human label', () {
      expect(LibraryStatusFilter.all.label, 'All');
      expect(LibraryStatusFilter.reading.label, 'Reading');
      expect(LibraryStatusFilter.updated.label, 'Updated');
      expect(LibraryStatusFilter.unread.label, 'Unread');
      expect(LibraryStatusFilter.finished.label, 'Finished');
    });
  });

  group('LibraryStatusFilterX.matches', () {
    test('all matches every book regardless of progress', () {
      expect(LibraryStatusFilter.all.matches(_book(id: 'a')), isTrue);
      expect(
        LibraryStatusFilter.all.matches(_book(id: 'b', progress: 0.5)),
        isTrue,
      );
    });

    test('unread matches only books with no progress', () {
      expect(LibraryStatusFilter.unread.matches(_book(id: 'a')), isTrue);
      expect(
        LibraryStatusFilter.unread.matches(_book(id: 'b', progress: 0)),
        isTrue,
      );
      expect(
        LibraryStatusFilter.unread.matches(_book(id: 'c', progress: 0.1)),
        isFalse,
      );
    });

    test('reading matches partially-read books', () {
      expect(
        LibraryStatusFilter.reading.matches(_book(id: 'a', progress: 0.5)),
        isTrue,
      );
      expect(LibraryStatusFilter.reading.matches(_book(id: 'b')), isFalse);
      expect(
        LibraryStatusFilter.reading.matches(_book(id: 'c', progress: 1)),
        isFalse,
      );
    });

    test('finished matches fully-read books only', () {
      expect(
        LibraryStatusFilter.finished.matches(_book(id: 'a', progress: 1)),
        isTrue,
      );
      expect(
        LibraryStatusFilter.finished.matches(_book(id: 'b', progress: 0.5)),
        isFalse,
      );
    });

    test('updated keys off the new-chapter flag, overlapping other buckets', () {
      final updatedUnread = _book(id: 'a', hasUpdate: true);
      expect(LibraryStatusFilter.updated.matches(updatedUnread), isTrue);
      expect(LibraryStatusFilter.unread.matches(updatedUnread), isTrue);
      expect(LibraryStatusFilter.updated.matches(_book(id: 'b')), isFalse);
    });

    test('honours the legacy 0..100 progress guard', () {
      // Rows written before schema 13 stored 0..100; 100 must read as finished.
      expect(
        LibraryStatusFilter.finished.matches(_book(id: 'a', progress: 100)),
        isTrue,
      );
    });
  });

  group('LibraryState.updated', () {
    test('updatedCount counts books with the new-chapter flag', () {
      const state = LibraryState();
      final withUpdates = state.copyWith(
        books: [
          _book(id: 'a', hasUpdate: true),
          _book(id: 'b'),
          _book(id: 'c', hasUpdate: true),
        ],
      );
      expect(withUpdates.updatedCount, 2);
    });

    test('updatedBooks is sorted by updatedAt descending', () {
      final older = _book(
        id: 'older',
        hasUpdate: true,
        updatedAt: DateTime(2026, 1, 1),
      );
      final newer = _book(
        id: 'newer',
        hasUpdate: true,
        updatedAt: DateTime(2026, 6, 1),
      );
      final state = const LibraryState().copyWith(books: [older, newer]);

      expect(
        state.updatedBooks.map((b) => b.id).toList(),
        ['newer', 'older'],
      );
    });
  });
}
