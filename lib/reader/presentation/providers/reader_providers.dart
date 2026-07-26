import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

final readerRepositoryProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return DriftReaderRepository(db);
});

final readerChapterContentProvider =
    FutureProvider.family<String, String>((ref, contentPath) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getChapterContent(contentPath);
  return switch (result) {
    Success(value: final content) => content,
    Failure() => 'Failed to load chapter content.',
  };
});

final readerLoadingProvider = StateProvider<bool>((_) => false);

final bookmarksProvider =
    FutureProvider.family<List<BookmarkEntity>, String>((ref, bookId) async {
  final repo = ref.watch(readerRepositoryProvider);
  final result = await repo.getBookmarks(bookId);
  return switch (result) {
    Success(value: final bookmarks) => bookmarks,
    Failure() => <BookmarkEntity>[],
  };
});
