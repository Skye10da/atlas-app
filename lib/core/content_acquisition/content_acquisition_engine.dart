import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/content_acquisition/adapters/source_adapter.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/models/chapter_model.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/content_acquisition/services/cache_manager.dart';
import 'package:atlas_app/core/content_acquisition/services/download_manager.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/content_acquisition/services/prefetch_engine.dart';
import 'package:atlas_app/core/content_engine/image/image_pipeline.dart';
import 'package:atlas_app/core/database/database.dart';

class ImportOutcome {
  const ImportOutcome({required this.bookId, required this.category});
  final String bookId;
  final ContentCategory category;
}

class ContentAcquisitionEngine {
  ContentAcquisitionEngine({
    required this.registry,
    required this.db,
    CacheManager? cacheManager,
    DownloadManager? downloadManager,
    this.imagePipeline,
  })  : cacheManager = cacheManager ?? CacheManager(),
        downloadManager = downloadManager ?? DownloadManager(),
        importService = ImportService(registry) {
    prefetchEngine = PrefetchEngine(downloadManager: this.downloadManager);
  }

  final SourceRegistry registry;
  final AppDatabase db;
  final ImportService importService;
  final CacheManager cacheManager;
  final DownloadManager downloadManager;
  final ImagePipeline? imagePipeline;
  late final PrefetchEngine prefetchEngine;
  final Map<String, _BookSourceState> _activeBooks = {};

  Future<ImportOutcome> importAndSave(
    String url, {
    ImportProgressCallback? onProgress,
  }) async {
    final result = await importService.import(url, onProgress: onProgress);
    final novel = result.novel;
    final chapters = result.chapters;
    final category = novel.category;

    final existing = await (db.select(db.books)
      ..where((b) => b.sourceId.equals(novel.sourceId) & b.sourceName.equals(novel.source)))
        .getSingleOrNull();
    if (existing != null) {
      throw const ImportException('This book is already in your library.');
    }

    var bookId = _normalizeId(novel.title);
    final idConflict = await (db.select(db.books)..where((b) => b.id.equals(bookId))).getSingleOrNull();
    if (idConflict != null) {
      bookId = '${bookId}_${DateTime.now().millisecondsSinceEpoch}';
    }

    final docsDir = await getApplicationSupportDirectory();
    final bookDir = Directory(p.join(docsDir.path, 'books', bookId));
    if (!bookDir.existsSync()) await bookDir.create(recursive: true);

    String? coverPath;
    final Uint8List? coverBytes = novel.coverBytes;
    if (coverBytes == null && novel.coverUrl != null) {
      coverPath = await _downloadCover(novel.coverUrl!, bookDir.path);
    }
    if (coverPath == null && coverBytes != null) {
      coverPath = p.join(bookDir.path, 'cover.jpg');
      await File(coverPath).writeAsBytes(coverBytes);
    }

    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final chapterId = '${bookId}_ch${ch.index}';
      final contentPath = p.join(bookDir.path, '${ch.index}.txt');

      if (ch.content != null) {
        await File(contentPath).writeAsString(ch.content!);
      }

      final wordCount = ch.wordCount ?? (ch.content?.split(RegExp(r'\s+')).length ?? 0);

      await db.into(db.chapters).insert(ChaptersCompanion(
        id: Value(chapterId),
        bookId: Value(bookId),
        index: Value(ch.index),
        title: Value(ch.title),
        contentPath: Value(contentPath),
        wordCount: Value(wordCount),
        pageCount: Value((wordCount / 300).ceil().clamp(1, 9999)),
        contentState: Value(ch.content != null ? ContentState.availableOffline.index : ContentState.discovered.index),
        createdAt: Value(DateTime.now()),
      ));

      onProgress?.call(0.8 + 0.2 * ((i + 1) / chapters.length));
    }

    final chapterIndex = chapters.map((ch) => {
      'id': ch.id,
      'title': ch.title,
      'index': ch.index,
      'contentUrl': ch.contentUrl,
    }).toList();
    await File(p.join(bookDir.path, '.chapter_index.json')).writeAsString(jsonEncode(chapterIndex));

    await db.into(db.books).insert(BooksCompanion(
      id: Value(bookId),
      title: Value(novel.title),
      author: novel.author != null ? Value(novel.author) : const Value.absent(),
      description: novel.description != null ? Value(novel.description) : const Value.absent(),
      format: Value(category == ContentCategory.book ? (novel.fileFormat ?? 'epub') : 'web'),
      itemType: Value(category.name),
      filePath: Value(bookDir.path),
      coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
      totalChapters: Value(chapters.length),
      language: novel.language != null ? Value(novel.language) : const Value.absent(),
      tags: novel.genres.isNotEmpty ? Value(jsonEncode(novel.genres)) : const Value.absent(),
      rating: novel.rating != null ? Value(novel.rating) : const Value.absent(),
      status: novel.status != null ? Value(novel.status) : const Value.absent(),
      sourceName: Value(novel.source),
      sourceId: Value(novel.sourceId),
      sourceUrl: Value(novel.sourceUrl),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));

    _activeBooks[bookId] = _BookSourceState(chapters: chapters, source: result.source);
    prefetchEngine.registerChapters(bookId, chapters, result.source);

    return ImportOutcome(bookId: bookId, category: category);
  }

  Future<void> downloadChapter(String bookId, int chapterIndex) async {
    final state = _activeBooks[bookId];
    if (state == null || chapterIndex >= state.chapters.length) return;
    downloadManager.enqueue(bookId, state.chapters[chapterIndex], state.source);
  }

  Future<void> downloadAllChapters(String bookId) async {
    final state = _activeBooks[bookId];
    if (state == null) return;
    downloadManager.enqueueMany(bookId, state.chapters, state.source);
  }

  void onChapterRead(String bookId, int chapterIndex) {
    prefetchEngine.onChapterRead(bookId, chapterIndex);
  }

  /// Re-enqueues chapters whose last-known state was downloading/queued, for
  /// books that were imported this session. Returns how many were re-enqueued.
  Future<int> resumeDownloads() async {
    var resumed = 0;
    for (final entry in _activeBooks.entries) {
      final bookId = entry.key;
      final state = entry.value;
      final interrupted = <ChapterModel>[];
      for (final chapter in state.chapters) {
        if (await downloadManager.isDownloaded(bookId, chapter.id)) continue;
        final row = await (db.select(db.chapters)
              ..where((c) => c.bookId.equals(bookId))
              ..where((c) => c.index.equals(chapter.index)))
            .getSingleOrNull();
        final storedState = row?.contentState;
        final needsResume = storedState == ContentState.queued.index ||
            storedState == ContentState.downloading.index ||
            storedState == ContentState.discovered.index;
        if (needsResume) interrupted.add(chapter);
      }
      if (interrupted.isNotEmpty) {
        downloadManager.enqueueMany(bookId, interrupted, state.source);
        resumed += interrupted.length;
      }
    }
    return resumed;
  }

  String _normalizeId(String title) {
    final id = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    return id.length > 48 ? '${id.substring(0, 48)}_${id.hashCode.abs()}' : id;
  }

  /// Downloads a cover through the [ImagePipeline] when one is wired in
  /// (content-addressed, deduped), copying the result into the book dir.
  /// Falls back to null on any failure so a missing cover never blocks import.
  Future<String?> _downloadCover(String url, String bookDirPath) async {
    final pipeline = imagePipeline;
    if (pipeline == null) return null;
    try {
      final stored = await pipeline.download(Uri.parse(url));
      if (stored == null) return null;
      final coverPath = p.join(bookDirPath, 'cover.jpg');
      await File(stored).copy(coverPath);
      return coverPath;
    } catch (_) {
      return null;
    }
  }
}

class _BookSourceState {
  _BookSourceState({required this.chapters, required this.source});
  final List<ChapterModel> chapters;
  final SourceAdapter source;
}
