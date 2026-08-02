import 'dart:async';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';

/// Priorities for [DownloadManager.enqueue]. Higher priority items run first
/// when the worker pool has free slots.
enum DownloadPriority { background, normal, high }

/// Replaces the sequential [DownloadEngine]: a fixed worker pool drains a
/// priority queue, and each task retries with backoff up to [maxAttempts]
/// before it is reported failed. The public surface matches what
/// `ContentAcquisitionEngine` and `PrefetchEngine` consume.
class DownloadManager {
  DownloadManager({
    CacheManager? cacheManager,
    this.workerCount = 4,
    this.maxAttempts = 3,
    this.retryBackoff = const Duration(milliseconds: 500),
  }) : cacheManager = cacheManager ?? CacheManager();

  final CacheManager cacheManager;
  final int workerCount;
  final int maxAttempts;
  final Duration retryBackoff;

  final StreamController<DownloadEvent> _events = StreamController.broadcast();
  final List<_QueuedTask> _queue = [];
  final Map<String, _QueuedTask> _running = {};
  bool _disposed = false;

  Stream<DownloadEvent> get events => _events.stream;

  void enqueue(
    String bookId,
    ChapterModel chapter,
    SourceAdapter source, {
    DownloadPriority priority = DownloadPriority.normal,
  }) {
    final key = '$bookId:${chapter.id}';
    if (_queue.any((t) => t.key == key) || _running.containsKey(key)) return;
    final task = _QueuedTask(key, bookId, chapter, source, priority);
    _queue.add(task);
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _events.add(DownloadEvent(bookId, chapter.id, DownloadStatus.queued));
    _pump();
  }

  void enqueueMany(
    String bookId,
    List<ChapterModel> chapters,
    SourceAdapter source, {
    DownloadPriority priority = DownloadPriority.normal,
  }) {
    for (final chapter in chapters) {
      enqueue(bookId, chapter, source, priority: priority);
    }
  }

  void cancel(String bookId, String chapterId) {
    final key = '$bookId:$chapterId';
    _queue.removeWhere((t) => t.key == key);
    _events.add(DownloadEvent(bookId, chapterId, DownloadStatus.cancelled));
  }

  Future<bool> isDownloaded(String bookId, String chapterId) {
    return cacheManager.hasChapter(bookId, chapterId);
  }

  Future<void> waitForIdle() async {
    while (_running.isNotEmpty || _queue.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _pump() async {
    while (!_disposed && _running.length < workerCount && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _running[task.key] = task;
      unawaited(_run(task));
    }
  }

  Future<void> _run(_QueuedTask task) async {
    var attempts = 0;
    while (attempts < maxAttempts) {
      attempts++;
      _events.add(
        DownloadEvent(task.bookId, task.chapter.id, DownloadStatus.downloading),
      );
      try {
        final fetched = await task.source.getChapter(task.chapter);
        final content = fetched.content;
        if (content == null) throw Exception('Chapter content was empty');

        await cacheManager.saveChapter(
          task.bookId,
          ChapterCacheData(
            id: task.chapter.id,
            title: fetched.title.isNotEmpty ? fetched.title : task.chapter.title,
            index: task.chapter.index,
            content: content,
            wordCount: fetched.wordCount,
          ),
        );

        _running.remove(task.key);
        _events.add(
          DownloadEvent(task.bookId, task.chapter.id, DownloadStatus.done),
        );
        await _pump();
        return;
      } catch (e) {
        if (attempts >= maxAttempts) {
          _running.remove(task.key);
          _events.add(DownloadEvent(
            task.bookId,
            task.chapter.id,
            DownloadStatus.failed,
            error: e.toString(),
          ));
          await _pump();
          return;
        }
        await Future<void>.delayed(retryBackoff * attempts);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
    _running.clear();
    _events.close();
  }
}

class _QueuedTask {
  _QueuedTask(this.key, this.bookId, this.chapter, this.source, this.priority);

  final String key;
  final String bookId;
  final ChapterModel chapter;
  final SourceAdapter source;
  final DownloadPriority priority;
}

enum DownloadStatus { queued, downloading, done, failed, cancelled }

class DownloadEvent {
  const DownloadEvent(this.bookId, this.chapterId, this.status, {this.error});

  final String bookId;
  final String chapterId;
  final DownloadStatus status;
  final String? error;
}
