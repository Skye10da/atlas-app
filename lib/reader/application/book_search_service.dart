import 'dart:io';

import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/domain/entities/book_search_result.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';

/// Full-text search across all chapters of a book.
class BookSearchService {
  const BookSearchService(this._repo);

  final ReaderRepositoryInterface _repo;

  /// Searches for [query] across all chapters of [bookId].
  ///
  /// Returns a list of [BookSearchResult]s with context snippets and character offsets.
  Future<Result<List<BookSearchResult>>> searchBook({
    required String bookId,
    required String query,
    int maxResults = 200,
    int snippetRadius = 45,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const Success([]);
    }

    final chaptersResult = await _repo.getChapters(bookId);
    if (chaptersResult is! Success<List<ChapterEntity>>) {
      return const Success([]);
    }

    final chapters = chaptersResult.value;
    final results = <BookSearchResult>[];
    final lowerQuery = cleanQuery.toLowerCase();

    for (var chIdx = 0; chIdx < chapters.length; chIdx++) {
      if (results.length >= maxResults) break;
      final chapter = chapters[chIdx];

      String? content;
      if (chapter.contentPath.isNotEmpty) {
        try {
          final file = File(chapter.contentPath);
          if (await file.exists()) {
            content = await file.readAsString();
          }
        } catch (_) {}
      }

      if (content == null || content.isEmpty) {
        final contentRes = await _repo.getChapterContent(chapter.contentPath);
        if (contentRes is Success<String>) {
          content = contentRes.value;
        }
      }

      if (content == null || content.isEmpty) continue;

      final lowerContent = content.toLowerCase();
      var startIndex = 0;

      while (startIndex < lowerContent.length && results.length < maxResults) {
        final matchIdx = lowerContent.indexOf(lowerQuery, startIndex);
        if (matchIdx == -1) break;

        // Build context snippet
        final snippetStart = (matchIdx - snippetRadius).clamp(0, content.length);
        final snippetEnd = (matchIdx + cleanQuery.length + snippetRadius).clamp(0, content.length);

        final rawSnippet = content.substring(snippetStart, snippetEnd);
        final prefix = snippetStart > 0 ? '…' : '';
        final suffix = snippetEnd < content.length ? '…' : '';
        final cleanSnippet = '$prefix${rawSnippet.replaceAll(RegExp(r'\s+'), ' ')}$suffix';

        // Calculate match position within the formatted snippet
        final matchInSnippet = (matchIdx - snippetStart) + prefix.length;

        results.add(
          BookSearchResult(
            chapterId: chapter.id,
            chapterIndex: chIdx,
            chapterTitle: chapter.title,
            snippet: cleanSnippet,
            matchStartInSnippet: matchInSnippet.clamp(0, cleanSnippet.length),
            matchLength: cleanQuery.length,
            charOffset: matchIdx,
          ),
        );

        startIndex = matchIdx + cleanQuery.length;
      }
    }

    return Success(results);
  }
}
