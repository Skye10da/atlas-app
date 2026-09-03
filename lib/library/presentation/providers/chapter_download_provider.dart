import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

/// Set of currently downloading chapter IDs.
final downloadingChapterIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Returns true if a specific chapter is currently downloading.
final isChapterDownloadingProvider =
    Provider.family<bool, String>((ref, chapterId) {
  final downloadingIds = ref.watch(downloadingChapterIdsProvider);
  return downloadingIds.contains(chapterId);
});

/// Set of book IDs currently undergoing a batch download.
final batchDownloadingBookIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Returns true if a book is undergoing batch download.
final isBatchDownloadingProvider =
    Provider.family<bool, String>((ref, bookId) {
  final batchIds = ref.watch(batchDownloadingBookIdsProvider);
  return batchIds.contains(bookId);
});

final chapterDownloadControllerProvider =
    StateNotifierProvider<ChapterDownloadController, AsyncValue<void>>((ref) {
  return ChapterDownloadController(ref);
});

class ChapterDownloadController extends StateNotifier<AsyncValue<void>> {
  ChapterDownloadController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> downloadSingle(String bookId, ChapterEntity chapter) async {
    _ref.read(downloadingChapterIdsProvider.notifier).update((set) => {...set, chapter.id});
    try {
      final downloadService = _ref.read(chapterDownloadServiceProvider);
      await downloadService.downloadChapter(bookId, chapter.index);
    } finally {
      _ref.read(downloadingChapterIdsProvider.notifier).update((set) {
        final next = Set<String>.from(set);
        next.remove(chapter.id);
        return next;
      });
    }
  }

  Future<void> downloadAll(String bookId) async {
    _ref.read(batchDownloadingBookIdsProvider.notifier).update((set) => {...set, bookId});
    state = const AsyncLoading();
    try {
      final repo = _ref.read(readerRepositoryProvider);
      final res = await repo.getChapters(bookId);
      final chapters = res.valueOrNull ?? [];
      final downloadService = _ref.read(chapterDownloadServiceProvider);

      final toDownload = chapters.where(
        (c) => c.contentState != ContentState.availableOffline.index,
      ).toList();

      for (final ch in toDownload) {
        _ref.read(downloadingChapterIdsProvider.notifier).update((set) => {...set, ch.id});
        try {
          await downloadService.downloadChapter(bookId, ch.index);
        } finally {
          _ref.read(downloadingChapterIdsProvider.notifier).update((set) {
            final next = Set<String>.from(set);
            next.remove(ch.id);
            return next;
          });
        }
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      _ref.read(batchDownloadingBookIdsProvider.notifier).update((set) {
        final next = Set<String>.from(set);
        next.remove(bookId);
        return next;
      });
    }
  }
}

