import 'dart:async';

import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_memory_ingestion_service.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

/// Live coverage snapshot for one book's story-memory backfill run.
class StoryBackfillProgress {
  const StoryBackfillProgress({
    required this.bookId,
    required this.totalChapters,
    required this.covered,
    required this.processedThisRun,
    required this.unavailable,
    required this.running,
    required this.finished,
  });

  final String bookId;

  /// Total chapter count of the novel (upper bound of coverage).
  final int totalChapters;

  /// Chapters with story memory so far (before this run + this run).
  final int covered;

  /// Chapters ingested during the current/last run.
  final int processedThisRun;

  /// Cached-but-empty or non-cached chapters skipped this run.
  final int unavailable;

  final bool running;
  final bool finished;

  /// 0.0 – 1.0 memory coverage, or null when the novel has no chapters yet.
  double? get fraction =>
      totalChapters == 0 ? null : (covered / totalChapters).clamp(0.0, 1.0);

  StoryBackfillProgress copyWith({
    int? covered,
    int? processedThisRun,
    int? unavailable,
    bool? running,
    bool? finished,
  }) {
    return StoryBackfillProgress(
      bookId: bookId,
      totalChapters: totalChapters,
      covered: covered ?? this.covered,
      processedThisRun: processedThisRun ?? this.processedThisRun,
      unavailable: unavailable ?? this.unavailable,
      running: running ?? this.running,
      finished: finished ?? this.finished,
    );
  }
}

/// Outcome of one backfill run.
enum StoryBackfillOutcome {
  /// The run ingested (or covered) everything it could.
  completed,

  /// Coverage was already above [coverageThreshold] — nothing to do.
  skippedAlreadyCovered,

  /// Another run for this book was already active.
  skippedAlreadyRunning,

  /// Cancelled midway (book deleted or user requested).
  cancelled,
}

/// Slow-and-steady pipeline that builds story memory for chapters the reader
/// never opened while they were displayed — the chapters cached by bulk
/// downloads and prefetches that the display-driven ingestion never sees.
///
/// Design constraints:
/// - Reads ONLY cached chapter files; never touches the network.
/// - Runs the same idempotent [StoryMemoryIngestionService] pass per chapter,
///   so already-ingested chapters cost one log lookup and nothing else.
/// - Rate-limited between chapters and cancellable mid-run.
class StoryBackfillService {
  StoryBackfillService({
    required StoryMemoryRepository memoryRepository,
    required StoryMemoryIngestionService ingestionService,
    this.rateLimit = const Duration(milliseconds: 150),
    this.coverageThreshold = 0.25,
  })  : _memoryRepository = memoryRepository,
        _ingestionService = ingestionService;

  final StoryMemoryRepository _memoryRepository;
  final StoryMemoryIngestionService _ingestionService;

  /// Pause between chapters so the backfill never competes with foreground
  /// work for isolate time / DB writes.
  final Duration rateLimit;

  /// A run only starts when coverage is below this fraction of the book's
  /// chapters — display-driven ingestion covers actively-read books fast.
  final double coverageThreshold;

  final Map<String, _BackfillRun> _activeRuns = {};

  bool isRunning(String bookId) =>
      _activeRuns[bookId]?.cancelled == false;

  /// Requests cancellation of the active run for [bookId], if any. The run
  /// finishes after its current chapter (never mid-extraction) and reports
  /// [StoryBackfillOutcome.cancelled].
  void cancel(String bookId) => _activeRuns[bookId]?.cancelled = true;

  /// Builds memory for the chapters of [bookId] missing from the ingestion
  /// log, from chapter 0 forward, using text produced by [chapterTextResolver]
  /// (null = chapter not cached / unavailable).
  ///
  /// Progress is published through [onProgress] after every chapter and at
  /// the end of the run. The returned future completes when the run ends.
  Future<StoryBackfillOutcome> backfillBook({
    required String bookId,
    required String readThroughId,
    required int totalChapters,
    required Future<String?> Function(int chapterIndex) chapterTextResolver,
    void Function(StoryBackfillProgress)? onProgress,
  }) async {
    if (totalChapters <= 0) return StoryBackfillOutcome.skippedAlreadyCovered;
    if (isRunning(bookId)) return StoryBackfillOutcome.skippedAlreadyRunning;

    final run = _BackfillRun();
    _activeRuns[bookId] = run;

    void publish(StoryBackfillProgress progress) => onProgress?.call(progress);

    try {
      // 1. Coverage snapshot from the ingestion log.
      final indexesRes = await _memoryRepository.ingestedChapterIndexes(
        bookId: bookId,
        readThroughId: readThroughId,
      );
      final logIndexes =
          indexesRes is Success<Set<int>> ? indexesRes.value : <int>{};

      final progress = StoryBackfillProgress(
        bookId: bookId,
        totalChapters: totalChapters,
        covered: logIndexes.length,
        processedThisRun: 0,
        unavailable: 0,
        running: true,
        finished: false,
      );
      publish(progress);

      // 2. Active reads already build memory while displaying — only ragged
      // books are worth a background pass.
      if (logIndexes.length / totalChapters >= coverageThreshold) {
        publish(progress.copyWith(running: false, finished: true));
        return StoryBackfillOutcome.skippedAlreadyCovered;
      }

      // 3. Walk the book from the beginning: summaries and recap contexts
      //    need the earliest chapters first, not whatever was cached last.
      for (int i = 0; i < totalChapters; i++) {
        if (run.cancelled) {
          publish(progress.copyWith(running: false, finished: true));
          return StoryBackfillOutcome.cancelled;
        }
        if (logIndexes.contains(i)) continue;

        final text = await chapterTextResolver(i);
        if (text == null || text.trim().isEmpty) {
          publish(progress.copyWith(unavailable: progress.unavailable + 1));
          continue;
        }

        await _ingestionService.ingestChapter(
          bookId: bookId,
          readThroughId: readThroughId,
          chapterIndex: i,
          chapterText: text,
        );
        logIndexes.add(i);

        if (run.cancelled) {
          publish(progress.copyWith(running: false, finished: true));
          return StoryBackfillOutcome.cancelled;
        }

        publish(progress.copyWith(
          covered: logIndexes.length,
          processedThisRun: progress.processedThisRun + 1,
        ));

        await Future<void>.delayed(rateLimit);
      }

      publish(progress.copyWith(
        covered: logIndexes.length,
        running: false,
        finished: true,
      ));
      return StoryBackfillOutcome.completed;
    } finally {
      _activeRuns.remove(bookId);
    }
  }
}

class _BackfillRun {
  bool cancelled = false;
}
