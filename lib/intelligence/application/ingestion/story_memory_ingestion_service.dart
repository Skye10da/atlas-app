import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

/// Outcome of a [`StoryMemoryIngestionService.ingestChapter`] call.
sealed class IngestionDecision {
  const IngestionDecision();
}

/// Chapter text was empty or a placeholder — nothing worth extracting.
final class IngestionSkippedEmpty extends IngestionDecision {
  const IngestionSkippedEmpty();
}

/// The chapter was already extracted under identical text (idempotent hit),
/// or the identical chapter extraction is currently running in-flight.
final class IngestionSkippedAlreadyDone extends IngestionDecision {
  const IngestionSkippedAlreadyDone({required this.alreadyInFlight});
  final bool alreadyInFlight;
}

/// Full pass completed: entities/relationships/events extracted and scenes indexed.
final class IngestionCompleted extends IngestionDecision {
  const IngestionCompleted({required this.summary, required this.sceneCount});
  final ChapterExtractionSummary summary;
  final int sceneCount;
}

/// Feeds a chapter's final display text into the Layer 1 story-memory
/// pipeline (extraction + FTS5 scene indexing), idempotently.
///
/// Idempotency is keyed on `(bookId, readThroughId, chapterIndex)` plus a
/// hash of the chapter text: re-opening a chapter is a no-op, while re-runs
/// after a translation-service change (same chapter, new text) re-extract.
class StoryMemoryIngestionService {
  StoryMemoryIngestionService({
    required StoryMemoryRepository repository,
    required EntityExtractor extractor,
  }) : _repository = repository,
       _extractor = extractor;

  static const int _minSceneChars = 400;
  static const int _maxSceneChars = 1200;

  final StoryMemoryRepository _repository;
  final EntityExtractor _extractor;

  /// Chapter keys whose extraction pass is currently running or queued.
  /// Prevents two near-simultaneous provider resolutions (reader + prefetch)
  /// from racing the same chapter into double extraction.
  final Set<String> _inFlight = {};

  /// Per-book pipeline tails: chapters enqueued for the same novel run one
  /// after another instead of stampeding isolates and the database.
  final Map<String, Future<void>> _bookTails = {};

  /// Stable content hash powering the ingestion idempotency check.
  String textHash(String text) => md5.convert(utf8.encode(text)).toString();

  /// Runs the full ingestion pass for one chapter of final display text.
  Future<Result<IngestionDecision>> ingestChapter({
    required String bookId,
    String readThroughId = 'default',
    required int chapterIndex,
    required String chapterText,
    bool runInIsolate = true,
  }) async {
    final trimmed = chapterText.trim();
    if (trimmed.isEmpty) {
      return const Success(IngestionSkippedEmpty());
    }

    final key = '$bookId|$readThroughId|$chapterIndex';
    if (_inFlight.contains(key)) {
      return const Success(IngestionSkippedAlreadyDone(alreadyInFlight: true));
    }
    _inFlight.add(key);

    final hash = textHash(trimmed);
    final alreadyRes = await _repository.isChapterIngested(
      bookId,
      readThroughId,
      chapterIndex,
      hash,
    );
    if (alreadyRes is Success<bool> && alreadyRes.value) {
      _inFlight.remove(key);
      return const Success(IngestionSkippedAlreadyDone(alreadyInFlight: false));
    }

    // Serialize the remaining pipeline behind the book's current tail so
    // back-to-back chapter open / prefetch calls drain in order.
    final result = Completer<Result<IngestionDecision>>();
    final prevTail = _bookTails[bookId] ?? Future.value();
    final tail = prevTail.then(
      (_) => _runPass(
        bookId: bookId,
        readThroughId: readThroughId,
        chapterIndex: chapterIndex,
        chapterText: trimmed,
        runInIsolate: runInIsolate,
        key: key,
        result: result,
      ),
    );
    _bookTails[bookId] = tail.whenComplete(() {
      if (_bookTails[bookId] == tail) _bookTails.remove(bookId);
    });
    // The queue tail itself must never fail — it only carries other tasks.
    unawaited(
      tail.catchError(test: (_) => true, (Object _) {}),
    );
    return result.future;
  }

  Future<void> _runPass({
    required String bookId,
    required String readThroughId,
    required int chapterIndex,
    required String chapterText,
    required bool runInIsolate,
    required String key,
    required Completer<Result<IngestionDecision>> result,
  }) async {
    try {
      // 1. Extraction pass (entities, relationships, events, review queue).
      final extractionRes = await _extractor.processChapter(
        bookId: bookId,
        readThroughId: readThroughId,
        chapterIndex: chapterIndex,
        chapterText: chapterText,
        runInIsolate: runInIsolate,
      );
      if (extractionRes is Failure<ChapterExtractionSummary>) {
        result.complete(Failure(extractionRes.error, extractionRes.stackTrace));
        return;
      }
      final summary = (extractionRes as Success<ChapterExtractionSummary>).value;

      // 2. Scene indexing into FTS5 (delete-then-insert, safe on re-runs).
      final scenes = splitScenes(chapterText);
      final scenesRes = await _repository.saveScenes(bookId, chapterIndex, scenes);
      if (scenesRes is Failure<void>) {
        result.complete(Failure(scenesRes.error, scenesRes.stackTrace));
        return;
      }

      // 3. Mark ingested so the next open of this chapter short-circuits.
      final recordRes = await _repository.recordChapterIngestion(
        bookId,
        readThroughId,
        chapterIndex,
        textHash(chapterText),
      );
      if (recordRes is Failure<void>) {
        result.complete(Failure(recordRes.error, recordRes.stackTrace));
        return;
      }

      result.complete(
        Success(IngestionCompleted(summary: summary, sceneCount: scenes.length)),
      );
    } catch (e, st) {
      result.complete(
        Failure(
          DatabaseException(
            'Chapter ingestion failed for $bookId#$chapterIndex',
            e,
          ),
          st,
        ),
      );
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Chunks narrative text into scene-sized passages for FTS5 retrieval:
  /// paragraph-bounded accumulation, at least [_minSceneChars] per chunk and
  /// capped at [_maxSceneChars] so no single FTS row dwarfs relevance ranking.
  static List<String> splitScenes(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) return const [];

    final scenes = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final chunk = buffer.toString().trim();
      if (chunk.isNotEmpty) scenes.add(chunk);
      buffer.clear();
    }

    for (final line in lines) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
      final current = buffer.length;
      if (current >= _maxSceneChars || current >= _minSceneChars) {
        // Oversized: hard-cut to keep FTS rows bounded. Large-enough: close
        // the scene at this paragraph boundary.
        flush();
      }
    }
    flush();

    return scenes;
  }
}
