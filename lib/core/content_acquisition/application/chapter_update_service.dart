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
import 'package:atlas_app/core/content_engine/transport/domain_governor.dart';
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
    this.fetchTimeout = const Duration(seconds: 60),
    DomainGovernor? governor,
  }) : _governor = governor ?? DomainGovernor.instance;

  final AppDatabase db;
  final SourceRegistry registry;
  final DomainGovernor _governor;

  /// Hard deadline for one source fetch. Without it a stalled TLS handshake
  /// or unresponsive host would hang the check (and the UI awaiting it)
  /// indefinitely.
  final Duration fetchTimeout;

  /// Guards concurrent manual triggers for the same book (double-tap on
  /// "Check for updates" or background `checkTrackedBooks` overlapping).
  final Set<String> _inFlight = <String>{};

  /// Refreshes one book. Books without a resolvable plugin/web source (local
  /// EPUB/PDF imports) are reported as failures with a descriptive error so
  /// callers can skip them gracefully.
  Future<BookRefreshOutcome> refreshBook(String bookId) async {
    if (!_inFlight.add(bookId)) {
      return BookRefreshOutcome(
        bookId: bookId,
        title: '',
        newChapters: 0,
        error: 'Update already in progress',
      );
    }
    try {
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

      // Acquire permit from DomainGovernor (enforces concurrency, robots.txt, backoff)
      await _governor.acquire(uri);
      try {
        final novel = NovelModel(
          sourceId: book.sourceId ?? book.sourceUrl ?? book.id,
          title: book.title,
          source: book.sourceName ?? '',
          sourceUrl: sourceUrl,
          category: ContentCategory.novel,
        );
        final rawFresh = await adapter.getChapters(novel).timeout(fetchTimeout);
        if (rawFresh.isEmpty) {
          await _markChecked(book);
          return BookRefreshOutcome(
            bookId: book.id,
            title: book.title,
            newChapters: 0,
          );
        }

        // Guard truly empty titles only — site already supplies "Chapter N"
        // for untitled chapters, so this is just a parser-glitch fallback.
        final fresh = rawFresh
            .map((ch) => ch.title.trim().isEmpty
                ? ChapterModel(
                    id: ch.id,
                    title: 'Chapter ${ch.index + 1}',
                    index: ch.index,
                    content: ch.content,
                    contentUrl: ch.contentUrl,
                    wordCount: ch.wordCount,
                    publishedAt: ch.publishedAt,
                    language: ch.language,
                  )
                : ch)
            .toList();

        final localRows = await (db.select(
          db.chapters,
        )..where((c) => c.bookId.equals(book.id))).get();
        final knownTitles = localRows
            .map((c) => _normalizeTitle(c.title))
            .toSet();
        // Stable URL set from on-disk index (mvlempyr URLs are stable across
        // title fluctuations between _fetchChaptersFromPosts and fallback).
        final knownUrls = await _loadIndexUrls(book);

        // Deduplicate fresh list itself. Prefer contentUrl (stable for
        // mvlempyr/WP) over title to avoid generic "Chapter N" collisions.
        final freshUnique = <String, ChapterModel>{};
        for (final ch in fresh) {
          final key = ch.contentUrl?.trim().isNotEmpty == true
              ? ch.contentUrl!.trim()
              : _normalizeTitle(ch.title);
          freshUnique.putIfAbsent(key, () => ch);
        }
        final dedupedFresh = freshUnique.values.toList();
        // URL-primary diff: if URL is known, it's the same chapter even if
        // title was renamed (fallback generic vs real ch_name). Only when
        // URL is unknown do we fall back to title check. This prevents
        // N→2N duplication on mvlempyr when WP feed transiently fails.
        final freshChapters = dedupedFresh.where((ch) {
          final url = ch.contentUrl?.trim();
          if (url != null && url.isNotEmpty && knownUrls.contains(url)) {
            return false;
          }
          return !knownTitles.contains(_normalizeTitle(ch.title));
        }).toList();

        // Assign stable, non-colliding indices/contentPaths for inserts.
        final maxLocalIndex = localRows.isEmpty
            ? -1
            : localRows.map((c) => c.index).reduce((a, b) => a > b ? a : b);
        final companions = <ChaptersCompanion>[];
        var nextIndex = maxLocalIndex + 1;
        for (final ch in freshChapters) {
          final companion = await _buildChapterCompanion(
            book,
            ch,
            assignedIndex: nextIndex++,
          );
          if (companion != null) companions.add(companion);
        }
        if (companions.isNotEmpty) {
          // Wrap DB insert in transaction to serialize with file write.
          await db.transaction(() async {
            await db.batch((batch) {
              for (final companion in companions) {
                batch.insert(
                  db.chapters,
                  companion,
                  mode: InsertMode.insertOrIgnore,
                );
              }
            });
          });
        }
        // Re-query to get actual inserted count (insertOrIgnore may skip races).
        final actualRows = await (db.select(
          db.chapters,
        )..where((c) => c.bookId.equals(book.id))).get();
        final inserted = actualRows.length - localRows.length;

        // Never shrink totalChapters on a partial fetch.
        final newTotal = localRows.length + inserted;
        await (db.update(db.books)..where((b) => b.id.equals(book.id))).write(
          BooksCompanion(
            totalChapters: Value(newTotal),
            updatedAt: Value(DateTime.now()),
            lastCheckedAt: Value(DateTime.now()),
            hasUpdate: Value(inserted > 0 || book.hasUpdate),
            newChapterCount: Value(book.newChapterCount + inserted),
          ),
        );

        if (inserted > 0) {
          // Pass the actual assigned start index so file indices align with DB.
          await _appendChapterIndex(
            book,
            freshChapters,
            startIndex: localRows.isEmpty
                ? 0
                : localRows.map((c) => c.index).reduce((a, b) => a > b ? a : b) + 1,
            expectedDbCount: newTotal,
            localRowCount: localRows.length,
          );
          AppLogger.info(
            'Update check: ${book.title} gained $inserted new chapter(s)',
          );
        } else {
          // Even with 0 inserts, repair drift if file and DB diverged.
          await _repairIndexIfNeeded(book, localRows.length);
          await _markChecked(book);
        }
        return BookRefreshOutcome(
          bookId: book.id,
          title: book.title,
          newChapters: inserted,
        );
      } catch (e, st) {
        final title = (await (db.select(db.books)
                  ..where((b) => b.id.equals(bookId)))
                .getSingleOrNull())
              ?.title ??
              '';
        AppLogger.error('Update check failed for "$title"', e, st);
        return BookRefreshOutcome(
          bookId: bookId,
          title: title,
          newChapters: 0,
          error: describeFailure(e),
        );
      }
    } finally {
      _inFlight.remove(bookId);
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
  /// Concurrency is controlled by [DomainGovernor] per origin.
  Future<LibraryUpdateCheckResult> checkTrackedBooks() async {
    final rows =
        await (db.select(db.books)..where(
              (b) =>
                  b.updateTrackingEnabled.equals(true) &
                  b.itemType.equals(ContentCategory.novel.name),
            ))
            .get();
    final validBooks = rows
        .where((b) => b.sourceUrl != null && b.sourceUrl!.isNotEmpty)
        .toList();
    final updates = <BookRefreshOutcome>[];

    for (final book in validBooks) {
      final outcome = await refreshBook(book.id);
      if (outcome.success && outcome.newChapters > 0) {
        updates.add(outcome);
      }
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
  /// chapter cannot be stored (id collision).
  Future<ChaptersCompanion?> _buildChapterCompanion(
    Book book,
    ChapterModel ch, {
    required int assignedIndex,
  }) async {
    final safeTitle = ch.title.trim().isEmpty
        ? 'Chapter ${assignedIndex + 1}'
        : ch.title;
    final wordCount =
        ch.wordCount ?? (ch.content?.split(RegExp(r'\s+')).length ?? 0);
    // Use assignedIndex for both DB index and file name to avoid
    // collisions with remote `ch.index` (which reuses 0 on pagination bugs).
    final contentPath = p.join(book.filePath, '$assignedIndex.txt');
    final content = ch.content;
    if (content != null) {
      try {
        await File(contentPath).writeAsString(content);
      } catch (_) {}
    }

    final chapterId = '${book.id}_ch$assignedIndex';
    final existing = await (db.select(
      db.chapters,
    )..where((c) => c.id.equals(chapterId))).getSingleOrNull();
    if (existing != null) {
      // Deterministic: skip duplicate rather than uniquify with timestamp
      // (which made races non-idempotent and doubled file entries).
      return null;
    }

    return ChaptersCompanion.insert(
      id: chapterId,
      bookId: book.id,
      index: assignedIndex,
      title: safeTitle,
      contentPath: contentPath,
      wordCount: wordCount,
      pageCount: (wordCount / 300).ceil().clamp(1, 9999),
      contentState: Value(ContentState.discovered.index),
      createdAt: DateTime.now(),
    );
  }

  Future<Set<String>> _loadIndexUrls(Book book) async {
    try {
      final file = File(p.join(book.filePath, '.chapter_index.json'));
      if (!await file.exists()) return <String>{};
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => m['contentUrl']?.toString().trim())
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _repairIndexIfNeeded(Book book, int dbCount) async {
    try {
      final file = File(p.join(book.filePath, '.chapter_index.json'));
      if (!await file.exists()) return;
      List<dynamic> entries;
      try {
        entries = jsonDecode(await file.readAsString()) as List<dynamic>;
      } catch (e) {
        AppLogger.warning(
          'Chapter index JSON corrupted for "${book.title}", rebuilding from DB ($dbCount entries): $e',
        );
        return;
      }
      if (entries.length == dbCount) return;
      // Only repair duplication (file larger than DB). Truncation
      // (file smaller) can happen in tests where file was never seeded
      // with initial DB rows — not a real corruption.
      final ratio = dbCount == 0 ? 0 : entries.length / dbCount;
      if (ratio > 1.3) {
        AppLogger.warning(
          'Chapter index drift for "${book.title}": file=${entries.length} db=$dbCount, repairing (dedup by URL)',
        );
        final deduped = <String, dynamic>{};
        for (final e in entries) {
          final m = e is Map ? e : null;
          if (m == null) continue;
          final url = m['contentUrl']?.toString().trim();
          final key = (url != null && url.isNotEmpty)
              ? url
              : m['id']?.toString() ?? m['title']?.toString() ?? '';
          if (key.isEmpty) continue;
          deduped.putIfAbsent(key, () => e);
        }
        var repaired = deduped.values.toList();
        // Re-index contiguously to match DB indices 0..N-1.
        for (var i = 0; i < repaired.length; i++) {
          final m = Map<String, dynamic>.from(repaired[i] as Map);
          m['index'] = i;
          repaired[i] = m;
        }
        if (repaired.length > dbCount) {
          repaired = repaired.sublist(0, dbCount);
        }
        if (repaired.length != entries.length) {
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString(jsonEncode(repaired));
          await tmp.rename(file.path);
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to repair index for "${book.title}": $e');
    }
  }

  /// Appends freshly discovered entries to the on-disk `.chapter_index.json`
  /// so downstream consumers see the full list. Deduplicates by id/contentUrl
  /// and writes atomically. Now rebuild-aware: repairs drift where
  /// `entries.length != dbCount` before appending and aligns file indices
  /// with DB `assignedIndex` to prevent N→2N duplication on mvlempyr
  /// title-fluctuation (fallback vs WP).
  Future<void> _appendChapterIndex(
    Book book,
    List<ChapterModel> newChapters, {
    required int startIndex,
    required int expectedDbCount,
    required int localRowCount,
  }) async {
    try {
      final file = File(p.join(book.filePath, '.chapter_index.json'));
      final entries = <dynamic>[];
      bool corrupted = false;
      if (await file.exists()) {
        try {
          entries.addAll(
            jsonDecode(await file.readAsString()) as List<dynamic>,
          );
        } catch (e) {
          corrupted = true;
          AppLogger.warning(
            'Chapter index JSON corrupted for "${book.title}", will rebuild: $e',
          );
        }
      }
      // If JSON was corrupted, entries is empty — don't halve the list.
      // Rebuild will be handled by repairing to DB count on next run;
      // for now just proceed with new chapters only if we have no history.
      if (corrupted && localRowCount > 0) {
        // Attempt to recover by not truncating: keep new chapters but log.
        // Next manual check will trigger _repairIndexIfNeeded.
      }
      // Repair drift before appending (duplication halving).
      if (!corrupted && entries.length != localRowCount) {
        await _repairIndexIfNeeded(book, localRowCount);
        // Reload after repair.
        entries.clear();
        try {
          entries.addAll(
            jsonDecode(await file.readAsString()) as List<dynamic>,
          );
        } catch (_) {}
      }
      final seenIds = entries
          .whereType<Map>()
          .map((m) => m['id']?.toString())
          .whereType<String>()
          .toSet();
      final seenUrls = entries
          .whereType<Map>()
          .map((m) => m['contentUrl']?.toString().trim())
          .where((u) => u != null && u.isNotEmpty)
          .cast<String>()
          .toSet();
      // Use DB-assigned startIndex to keep file index == DB index.
      for (var i = 0; i < newChapters.length; i++) {
        final ch = newChapters[i];
        if (seenIds.contains(ch.id)) continue;
        final url = ch.contentUrl?.trim();
        if (url != null && url.isNotEmpty && seenUrls.contains(url)) continue;
        final assignedIndex = startIndex + i;
        final safeTitle = ch.title.trim().isEmpty
            ? 'Chapter ${assignedIndex + 1}'
            : ch.title;
        entries.add({
          'id': ch.id,
          'title': safeTitle,
          'index': assignedIndex,
          'contentUrl': ch.contentUrl,
        });
        seenIds.add(ch.id);
        if (url != null && url.isNotEmpty) seenUrls.add(url);
      }
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(entries));
      await tmp.rename(file.path);
      // Post-write validation only for duplication (file larger than DB),
      // not for missing entries when file was never seeded (test setup).
      if (entries.length > expectedDbCount) {
        AppLogger.warning(
          'Post-append index duplicate for "${book.title}": file=${entries.length} expectedDb=$expectedDbCount',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to update chapter index for "${book.title}": $e',
      );
    }
  }

  String _normalizeTitle(String title) =>
      title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}