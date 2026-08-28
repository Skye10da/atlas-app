import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/logging/logger.dart';

/// Outcome of refreshing a single book's chapter list from its source.
class BookRefreshOutcome {
  const BookRefreshOutcome({
    required this.bookId,
    required this.title,
    required this.newChapters,
    this.error,
  });

  final String bookId;
  final String title;
  final int newChapters;
  final String? error;

  bool get success => error == null;
}

/// Aggregate result of checking every tracked ongoing novel.
class LibraryUpdateCheckResult {
  const LibraryUpdateCheckResult({required this.updates});

  /// One entry per book that gained new chapters.
  final List<BookRefreshOutcome> updates;

  int get booksWithUpdates => updates.length;
  int get totalNewChapters => updates.fold(0, (sum, u) => sum + u.newChapters);
}

/// Re-fetches the chapter list of a saved novel from its source and stores
/// newly discovered chapters.
///
/// Diffing is title-based: a remote chapter counts as "new" only when no
/// local chapter with the same normalized title exists yet. This tolerates
/// sources that renumber or shift existing entries when inserting chapters
/// mid-list, at the cost of under-detecting chapters whose titles repeat.
class ChapterUpdateService {
  ChapterUpdateService({
    required this.db,
    required this.registry,
    this.fetchTimeout = const Duration(seconds: 30),
  });

  final AppDatabase db;
  final SourceRegistry registry;

  /// Hard deadline for one source fetch. Without it a stalled TLS handshake
  /// or unresponsive host would hang the check (and the UI awaiting it)
  /// indefinitely.
  final Duration fetchTimeout;

  /// Refreshes one book. Books without a resolvable plugin/web source (local
  /// EPUB/PDF imports) are reported as failures with a descriptive error so
  /// callers can skip them gracefully.
  Future<BookRefreshOutcome> refreshBook(String bookId) async {
    final book = await (db.select(
      db.books,
    )..where((b) => b.id.equals(bookId))).getSingleOrNull();
    if (book == null) {
      return BookRefreshOutcome(
        bookId: bookId,
        title: '',
        newChapters: 0,
        error: 'Book not found',
      );
    }

    try {
      if (book.itemType != ContentCategory.novel.name) {
        return _skipped(book.id, book.title, 'Not a novel import');
      }
      final sourceUrl = book.sourceUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        return _skipped(book.id, book.title, 'No source URL stored');
      }
      final uri = Uri.tryParse(sourceUrl);
      if (uri == null) {
        return _skipped(book.id, book.title, 'Invalid source URL');
      }
      final adapter = registry.resolve(uri);
      if (adapter == null) {
        return _skipped(book.id, book.title, 'Source not available');
      }

      final novel = NovelModel(
        sourceId: book.sourceId ?? book.sourceUrl ?? book.id,
        title: book.title,
        source: book.sourceName ?? '',
        sourceUrl: sourceUrl,
        category: ContentCategory.novel,
      );
      final fresh = await adapter.getChapters(novel).timeout(fetchTimeout);
      if (fresh.isEmpty) {
        await _markChecked(book);
        return BookRefreshOutcome(
          bookId: book.id,
          title: book.title,
          newChapters: 0,
        );
      }

      final localRows = await (db.select(
        db.chapters,
      )..where((c) => c.bookId.equals(book.id))).get();
      final knownTitles = localRows
          .map((c) => _normalizeTitle(c.title))
          .toSet();

      final freshChapters = fresh
          .where((ch) => !knownTitles.contains(_normalizeTitle(ch.title)))
          .toList();

      final companions = <ChaptersCompanion>[];
      for (final ch in freshChapters) {
        final companion = await _buildChapterCompanion(book, ch);
        if (companion != null) companions.add(companion);
      }
      if (companions.isNotEmpty) {
        // One transaction instead of a row-by-row insert storm on the UI
        // isolate.
        await db.batch((batch) {
          for (final companion in companions) {
            batch.insert(db.chapters, companion);
          }
        });
      }
      final inserted = companions.length;

      await (db.update(db.books)..where((b) => b.id.equals(book.id))).write(
        BooksCompanion(
          totalChapters: Value(fresh.length),
          updatedAt: Value(DateTime.now()),
          lastCheckedAt: Value(DateTime.now()),
          hasUpdate: Value(inserted > 0 || book.hasUpdate),
          newChapterCount: Value(book.newChapterCount + inserted),
        ),
      );

      if (inserted > 0) {
        await _appendChapterIndex(book, freshChapters);
        AppLogger.info(
          'Update check: ${book.title} gained $inserted new chapter(s)',
        );
      }
      return BookRefreshOutcome(
        bookId: book.id,
        title: book.title,
        newChapters: inserted,
      );
    } catch (e, st) {
      AppLogger.error('Update check failed for "${book.title}"', e, st);
      return BookRefreshOutcome(
        bookId: book.id,
        title: book.title,
        newChapters: 0,
        error: describeFailure(e),
      );
    }
  }

  /// Maps raw network errors to short, user-facing reasons.
  static String describeFailure(Object error) {
    if (error is TimeoutException) {
      return 'The source took too long to respond.';
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('handshake') ||
        msg.contains('tls') ||
        msg.contains('certificate')) {
      return 'Could not establish a secure connection to the source.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset')) {
      return 'Could not reach the source. Check your connection.';
    }
    return error.toString();
  }

  /// Refreshes every novel that has update tracking enabled and a usable
  /// source. Returns only the books that actually gained new chapters.
  Future<LibraryUpdateCheckResult> checkTrackedBooks() async {
    final rows =
        await (db.select(db.books)..where(
              (b) =>
                  b.updateTrackingEnabled.equals(true) &
                  b.itemType.equals(ContentCategory.novel.name),
            ))
            .get();
    final updates = <BookRefreshOutcome>[];
    for (final book in rows) {
      if (book.sourceUrl == null || book.sourceUrl!.isEmpty) continue;
      final outcome = await refreshBook(book.id);
      if (outcome.success && outcome.newChapters > 0) {
        updates.add(outcome);
      }
      // Give the UI isolate a frame between books so a long check-all run
      // doesn't starve rendering.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return LibraryUpdateCheckResult(updates: updates);
  }

  BookRefreshOutcome _skipped(String id, String title, String reason) {
    return BookRefreshOutcome(
      bookId: id,
      title: title,
      newChapters: 0,
      error: reason,
    );
  }

  Future<void> _markChecked(Book book) async {
    await (db.update(db.books)..where((b) => b.id.equals(book.id))).write(
      BooksCompanion(lastCheckedAt: Value(DateTime.now())),
    );
  }

  /// Builds the insert companion for one new chapter, or null when the
  /// chapter cannot be stored (id collision that can't be uniquified).
  Future<ChaptersCompanion?> _buildChapterCompanion(
    Book book,
    ChapterModel ch,
  ) async {
    final wordCount =
        ch.wordCount ?? (ch.content?.split(RegExp(r'\s+')).length ?? 0);
    final contentPath = p.join(book.filePath, '${ch.index}.txt');
    final content = ch.content;
    if (content != null) {
      try {
        await File(contentPath).writeAsString(content);
      } catch (_) {}
    }

    var chapterId = '${book.id}_ch${ch.index}';
    final existing = await (db.select(
      db.chapters,
    )..where((c) => c.id.equals(chapterId))).getSingleOrNull();
    if (existing != null) {
      // Index shifted by an insertion; keep ids unique per row.
      chapterId =
          '${book.id}_u${DateTime.now().millisecondsSinceEpoch}_${ch.index}';
    }

    return ChaptersCompanion.insert(
      id: chapterId,
      bookId: book.id,
      index: ch.index,
      title: ch.title,
      contentPath: contentPath,
      wordCount: wordCount,
      pageCount: (wordCount / 300).ceil().clamp(1, 9999),
      contentState: Value(ContentState.discovered.index),
      createdAt: DateTime.now(),
    );
  }

  /// Appends freshly discovered entries to the on-disk `.chapter_index.json`
  /// so downstream consumers see the full list.
  Future<void> _appendChapterIndex(
    Book book,
    List<ChapterModel> newChapters,
  ) async {
    try {
      final file = File(p.join(book.filePath, '.chapter_index.json'));
      final entries = <dynamic>[];
      if (await file.exists()) {
        try {
          entries.addAll(
            jsonDecode(await file.readAsString()) as List<dynamic>,
          );
        } catch (_) {}
      }
      for (final ch in newChapters) {
        entries.add({
          'id': ch.id,
          'title': ch.title,
          'index': ch.index,
          'contentUrl': ch.contentUrl,
        });
      }
      await file.writeAsString(jsonEncode(entries));
    } catch (e) {
      AppLogger.warning(
        'Failed to update chapter index for "${book.title}": $e',
      );
    }
  }

  String _normalizeTitle(String title) =>
      title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
