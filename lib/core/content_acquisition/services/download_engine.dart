import 'dart:async';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';

class DownloadEngine {
  DownloadEngine({
    required this.cacheManager,
  });

  final CacheManager cacheManager;
  final StreamController<DownloadEvent> _events = StreamController.broadcast();
  final Map<String, DownloadTask> _queue = {};
  bool _processing = false;

  Stream<DownloadEvent> get events => _events.stream;

  void enqueue(String bookId, ChapterModel chapter, SourceAdapter source) {
    final key = '$bookId:${chapter.id}';
    if (_queue.containsKey(key)) return;
    _queue[key] = DownloadTask(bookId: bookId, chapter: chapter, source: source, status: DownloadStatus.queued);
    _events.add(DownloadEvent(bookId, chapter.id, DownloadStatus.queued));
    _process();
  }

  void enqueueMany(String bookId, List<ChapterModel> chapters, SourceAdapter source) {
    for (final c in chapters) {
      enqueue(bookId, c, source);
    }
  }

  void cancel(String bookId, String chapterId) {
    final key = '$bookId:$chapterId';
    _queue.remove(key);
    _events.add(DownloadEvent(bookId, chapterId, DownloadStatus.cancelled));
  }

  Future<bool> isDownloaded(String bookId, String chapterId) async {
    return cacheManager.hasChapter(bookId, chapterId);
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final entry = _queue.entries.first;
      final key = entry.key;
      final task = entry.value;

      _queue[key] = task.copyWith(status: DownloadStatus.downloading);
      _events.add(DownloadEvent(task.bookId, task.chapter.id, DownloadStatus.downloading));

      try {
        final fetched = await task.source.getChapter(task.chapter);
        final content = fetched.content;
        if (content == null) throw Exception('Chapter content was empty');

        await cacheManager.saveChapter(
          task.bookId,
          ChapterCacheData(
            id: task.chapter.id,
            title: task.chapter.title,
            index: task.chapter.index,
            content: content,
            wordCount: content.split(RegExp(r'\s+')).length,
          ),
        );

        _queue.remove(key);
        _events.add(DownloadEvent(task.bookId, task.chapter.id, DownloadStatus.done));
      } catch (e) {
        _queue[key] = task.copyWith(status: DownloadStatus.failed, error: e.toString());
        _events.add(DownloadEvent(task.bookId, task.chapter.id, DownloadStatus.failed, error: e.toString()));
      }
    }

    _processing = false;
  }

  void dispose() => _events.close();
}

class DownloadTask {
  const DownloadTask({
    required this.bookId,
    required this.chapter,
    required this.source,
    required this.status,
    this.error,
  });

  final String bookId;
  final ChapterModel chapter;
  final SourceAdapter source;
  final DownloadStatus status;
  final String? error;

  DownloadTask copyWith({DownloadStatus? status, String? error}) {
    return DownloadTask(
      bookId: bookId,
      chapter: chapter,
      source: source,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

enum DownloadStatus { queued, downloading, done, failed, cancelled }

class DownloadEvent {
  const DownloadEvent(this.bookId, this.chapterId, this.status, {this.error});
  final String bookId;
  final String chapterId;
  final DownloadStatus status;
  final String? error;
}
