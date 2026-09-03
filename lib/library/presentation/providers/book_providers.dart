import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

/// Reactive stream provider for a single book's details and reading progress.
final bookDetailsProvider = StreamProvider.family<BookEntity, String>((ref, bookId) {
  final db = ref.watch(databaseProvider);
  final repo = DriftLibraryRepository(db);

  return repo.watchBookById(bookId).map((result) {
    return switch (result) {
      Success(value: final book) => book,
      Failure(error: final error) => throw Exception(error.userMessage),
    };
  });
});

/// Reactive stream provider for a book's chapters.
final bookChaptersProvider = StreamProvider.family<List<ChapterEntity>, String>((ref, bookId) {
  final db = ref.watch(databaseProvider);
  final repo = DriftReaderRepository(db);
  return repo.watchChaptersForBook(bookId);
});

