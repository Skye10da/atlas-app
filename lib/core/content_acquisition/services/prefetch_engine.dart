import 'dart:async';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/services/download_engine.dart';

class PrefetchEngine {
  PrefetchEngine({required this.downloadEngine});

  final DownloadEngine downloadEngine;
  final Map<String, _PrefetchState> _states = {};
  Timer? _debounce;

  void registerChapters(String bookId, List<ChapterModel> chapters, SourceAdapter source) {
    _states[bookId] = _PrefetchState(chapters: chapters, source: source);
  }

  void onChapterRead(String bookId, int currentIndex, {int prefetchAhead = 4}) {
    final state = _states[bookId];
    if (state == null) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      for (int i = 1; i <= prefetchAhead; i++) {
        final idx = currentIndex + i;
        if (idx >= state.chapters.length) break;
        downloadEngine.enqueue(bookId, state.chapters[idx], state.source);
      }
    });
  }

  void clearBook(String bookId) => _states.remove(bookId);
  void clear() { _states.clear(); _debounce?.cancel(); }
}

class _PrefetchState {
  _PrefetchState({required this.chapters, required this.source});
  final List<ChapterModel> chapters;
  final SourceAdapter source;
}
