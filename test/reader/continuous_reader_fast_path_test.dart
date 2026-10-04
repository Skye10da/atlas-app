import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_content_loader.dart';
import 'package:atlas_app/reader/presentation/widgets/continuous_reader_layout.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('atlas_continuous_test');
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ChapterEntity makeChapter({
    required String id,
    required String bookId,
    required int index,
    required String contentPath,
  }) {
    return ChapterEntity(
      id: id,
      bookId: bookId,
      index: index,
      title: 'Chapter ${index + 1}',
      contentPath: contentPath,
      wordCount: 100,
      pageCount: 1,
      contentState: ContentState.availableOffline.index,
      version: 1,
    );
  }

  test('Sync providers default to false for instant fast path', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(translationEnabledSyncProvider('book-1')), isFalse);
    expect(container.read(atlasGlossaryNotEmptySyncProvider('book-1')), isFalse);
  });

  test('readerChapterContentProvider returns cached content via fast-path', () async {
    final filePath = p.join(tempDir.path, 'ch1.txt');
    File(filePath).writeAsStringSync('Cached instant chapter text');

    final chapter = makeChapter(
      id: 'ch-1',
      bookId: 'book-1',
      index: 0,
      contentPath: filePath,
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    final content = await container.read(readerChapterContentProvider(chapter).future);
    expect(content, equals('Cached instant chapter text'));
  });

  test('readerChapterContentProvider returns cached content directly for both -1 and +1 neighbors', () async {
    final ch0Path = p.join(tempDir.path, 'ch0.txt');
    final ch1Path = p.join(tempDir.path, 'ch1.txt');
    final ch2Path = p.join(tempDir.path, 'ch2.txt');
    File(ch0Path).writeAsStringSync('Chapter 0 cached content');
    File(ch1Path).writeAsStringSync('Chapter 1 cached content');
    File(ch2Path).writeAsStringSync('Chapter 2 cached content');

    final ch0 = makeChapter(id: 'ch-0', bookId: 'book-1', index: 0, contentPath: ch0Path);
    final ch1 = makeChapter(id: 'ch-1', bookId: 'book-1', index: 1, contentPath: ch1Path);
    final ch2 = makeChapter(id: 'ch-2', bookId: 'book-1', index: 2, contentPath: ch2Path);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    // Active chapter is 1; neighbors are 0 (-1) and 2 (+1).
    // The first call directly fetches from cache without network errors.
    final contentPrev = await container.read(readerChapterContentProvider(ch0).future);
    final contentCurr = await container.read(readerChapterContentProvider(ch1).future);
    final contentNext = await container.read(readerChapterContentProvider(ch2).future);

    expect(contentPrev, equals('Chapter 0 cached content'));
    expect(contentCurr, equals('Chapter 1 cached content'));
    expect(contentNext, equals('Chapter 2 cached content'));
  });

  test('readerChapterContentProvider resolves content from candidate filename in parent directory', () async {
    final bookDir = Directory(p.join(tempDir.path, 'books', 'book-1'))..createSync(recursive: true);
    // Write under index name '0.txt' instead of composite id
    final indexFilePath = p.join(bookDir.path, '0.txt');
    File(indexFilePath).writeAsStringSync('Candidate index file content');

    // Expected path is bookId_ch0.txt which does not exist yet
    final targetPath = p.join(bookDir.path, 'book-1_ch0.txt');
    final chapter = makeChapter(
      id: 'book-1_ch0',
      bookId: 'book-1',
      index: 0,
      contentPath: targetPath,
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    final content = await container.read(readerChapterContentProvider(chapter).future);
    expect(content, equals('Candidate index file content'));
    // Target file should have been synced
    expect(File(targetPath).existsSync(), isTrue);
  });

  testWidgets('ContinuousReaderLayout renders ChapterContentLoader by default without delay or placeholder', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ch0Path = p.join(tempDir.path, 'ch0.txt');
    final ch1Path = p.join(tempDir.path, 'ch1.txt');
    final ch2Path = p.join(tempDir.path, 'ch2.txt');
    File(ch0Path).writeAsStringSync('Chapter 0 content');
    File(ch1Path).writeAsStringSync('Chapter 1 content');
    File(ch2Path).writeAsStringSync('Chapter 2 content');

    final ch0 = makeChapter(id: 'ch-0', bookId: 'b1', index: 0, contentPath: ch0Path);
    final ch1 = makeChapter(id: 'ch-1', bookId: 'b1', index: 1, contentPath: ch1Path);
    final ch2 = makeChapter(id: 'ch-2', bookId: 'b1', index: 2, contentPath: ch2Path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: ContinuousReaderLayout(
            chapters: [ch0, ch1, ch2],
            settings: const ReadingSettingsEntity(),
            currentChapterIndex: 1,
            bookmarkedChapterIds: const {},
            onPositionChanged: (pos, total) {},
            onScrollProgress: (_) {},
            onCurrentChapterChanged: (_) {},
            onScrollDirectionChanged: (_) {},
            onSettingsTap: () {},
            onChapterSelected: (_) {},
            isBookmarked: false,
            onBookmarkToggle: () {},
            onOpenAnnotations: () {},
          ),
        ),
      ),
    );

    // ContinuousReaderLayout directly mounts ChapterContentLoader for visible chapters
    expect(find.byType(ChapterContentLoader), findsWidgets);
    // No placeholder widget text
    expect(find.text('is not downloaded'), findsNothing);
  });
}

