import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

void main() {
  late AppDatabase db;
  late DriftReaderRepository repo;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftReaderRepository(db);
    tempDir = Directory.systemTemp.createTempSync('atlas_reader_repo');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> insertChapter({
    required String id,
    required String bookId,
    required int index,
    required String contentPath,
    required ContentState state,
    String? checksum,
    int version = 1,
    String? previousVersionRef,
  }) async {
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion(
            id: Value(id),
            bookId: Value(bookId),
            index: Value(index),
            title: Value('Chapter ${index + 1}'),
            contentPath: Value(contentPath),
            wordCount: const Value(100),
            pageCount: const Value(1),
            contentState: Value(state.index),
            version: Value(version),
            checksum: Value(checksum),
            previousVersionRef: Value(previousVersionRef),
            createdAt: Value(DateTime(2025, 1, 1)),
          ),
        );
  }

  group('resetChapterContent', () {
    test('deletes downloaded content and reverts to discovered', () async {
      final file = File(p.join(tempDir.path, '0.txt'));
      file.writeAsStringSync('old translation text');

      await insertChapter(
        id: 'b1_ch0',
        bookId: 'b1',
        index: 0,
        contentPath: file.path,
        state: ContentState.availableOffline,
        checksum: 'abc',
        version: 2,
        previousVersionRef: 'b1_ch0',
      );

      final result = await repo.resetChapterContent('b1');

      expect(result, isA<Success<void>>());
      expect(file.existsSync(), isFalse);
      final chapters = (await repo.getChapters('b1')).valueOrThrow;
      expect(chapters.single.contentState, ContentState.discovered.index);
      expect(chapters.single.version, 1);
      expect(chapters.single.checksum, isNull);
      expect(chapters.single.previousVersionRef, isNull);
    });

    test('also removes superseded version archives', () async {
      final file = File(p.join(tempDir.path, '0.txt'));
      file.writeAsStringSync('current');
      final archive = File('${file.path}.v2');
      archive.writeAsStringSync('previous version');

      await insertChapter(
        id: 'b1_ch0',
        bookId: 'b1',
        index: 0,
        contentPath: file.path,
        state: ContentState.availableOffline,
      );

      await repo.resetChapterContent('b1');

      expect(file.existsSync(), isFalse);
      expect(archive.existsSync(), isFalse);
    });

    test('leaves chapters that were never downloaded untouched', () async {
      final file = File(p.join(tempDir.path, '0.txt'));
      file.writeAsStringSync('pre-seeded content');

      await insertChapter(
        id: 'b1_ch0',
        bookId: 'b1',
        index: 0,
        contentPath: file.path,
        state: ContentState.discovered,
      );

      final result = await repo.resetChapterContent('b1');

      expect(result, isA<Success<void>>());
      expect(file.existsSync(), isTrue);
      final chapters = (await repo.getChapters('b1')).valueOrThrow;
      expect(chapters.single.contentState, ContentState.discovered.index);
    });

    test('is scoped to the requested book', () async {
      final fileA = File(p.join(tempDir.path, 'a.txt'));
      fileA.writeAsStringSync('a');
      final fileB = File(p.join(tempDir.path, 'b.txt'));
      fileB.writeAsStringSync('b');

      await insertChapter(
        id: 'a_ch0',
        bookId: 'a',
        index: 0,
        contentPath: fileA.path,
        state: ContentState.availableOffline,
      );
      await insertChapter(
        id: 'b_ch0',
        bookId: 'b',
        index: 0,
        contentPath: fileB.path,
        state: ContentState.availableOffline,
      );

      await repo.resetChapterContent('a');

      expect(fileA.existsSync(), isFalse);
      expect(fileB.existsSync(), isTrue);
    });
  });
}

extension<T> on Result<T> {
  T get valueOrThrow => switch (this) {
    Success(value: final value) => value,
    Failure() => throw StateError('Unexpected failure'),
  };
}
