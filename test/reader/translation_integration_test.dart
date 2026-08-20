import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/translation_repository.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';
import 'package:atlas_app/wtr/domain/services/wtr_web_translate_service.dart';

extension<T> on Result<T> {
  T get valueOrThrow => switch (this) {
        Success(value: final value) => value,
        Failure() => throw StateError('Unexpected failure'),
      };
}

class _FakeTranslateService extends WtrWebTranslateService {
  const _FakeTranslateService();

  @override
  Future<List<String>> translateParagraphs(
    Transport transport, {
    required List<String> paragraphs,
    String from = 'zh-CN',
    String to = 'en',
    Map<String, String>? headers,
  }) async {
    return paragraphs.map((para) => 'TRANS[$to:$para]').toList();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppDatabase> seedBook({
    required String bookId,
    required String content,
    String? sourceUrl,
    String? sourceName,
    String? language,
  }) async {
    final db = AppDatabase.memory();
    final tempDir = Directory.systemTemp.createTempSync('translation_test');
    final file = File(p.join(tempDir.path, '0.txt'));
    file.writeAsStringSync(content);

    await db.into(db.books).insert(BooksCompanion(
          id: const Value('b1'),
          title: const Value('Test Book'),
          format: const Value('epub'),
          filePath: const Value('/fake/path'),
          totalChapters: const Value(1),
          sourceUrl: Value(sourceUrl),
          sourceName: Value(sourceName),
          language: Value(language),
          createdAt: Value(DateTime(2025, 1, 1)),
          updatedAt: Value(DateTime(2025, 1, 1)),
        ));
    await db.into(db.chapters).insert(ChaptersCompanion(
          id: const Value('b1_ch0'),
          bookId: Value(bookId),
          index: const Value(0),
          title: const Value('Chapter 1'),
          contentPath: Value(file.path),
          wordCount: const Value(100),
          pageCount: const Value(1),
          contentState: Value(ContentState.availableOffline.index),
          version: const Value(1),
          createdAt: Value(DateTime(2025, 1, 1)),
        ));
    return db;
  }

  group('readerChapterContentProvider non-WTR translation', () {
    test('translates downloaded content when enabled with a language',
        () async {
      final db = await seedBook(
        bookId: 'b1',
        content: '你好世界\n\n你吃饭了吗',
        sourceUrl: 'https://example.com/novel/1',
      );
      addTearDown(() async {
        await db.close();
      });

      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      final prefs = InMemoryTranslationRepository();
      await prefs.saveEnabled('b1', true);
      await prefs.saveTargetLanguage('b1', spanish);

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        translationRepositoryProvider.overrideWithValue(prefs),
        googleTranslateServiceProvider
            .overrideWithValue(const _FakeTranslateService()),
      ]);
      addTearDown(container.dispose);

      final reader = DriftReaderRepository(db);
      final chapter = (await reader.getChapters('b1')).valueOrThrow.single;
      final content =
          await container.read(readerChapterContentProvider(chapter).future);
      expect(content, 'TRANS[es:你好世界]\n\nTRANS[es:你吃饭了吗]');
    });

    test('returns the original text when the toggle is off', () async {
      final db = await seedBook(
        bookId: 'b1',
        content: '你好世界\n\n你吃饭了吗',
        sourceUrl: 'https://example.com/novel/1',
      );
      addTearDown(() async {
        await db.close();
      });

      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      final prefs = InMemoryTranslationRepository();
      await prefs.saveTargetLanguage('b1', spanish);

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        translationRepositoryProvider.overrideWithValue(prefs),
        googleTranslateServiceProvider
            .overrideWithValue(const _FakeTranslateService()),
      ]);
      addTearDown(container.dispose);

      final reader = DriftReaderRepository(db);
      final chapter = (await reader.getChapters('b1')).valueOrThrow.single;
      final content =
          await container.read(readerChapterContentProvider(chapter).future);
      expect(content, '你好世界\n\n你吃饭了吗');
    });

    test('never re-translates a WTR-Lab novel even when enabled', () async {
      final db = await seedBook(
        bookId: 'b1',
        content: '你好世界',
        sourceUrl: 'https://wtr-lab.com/en/novel/29058',
        sourceName: 'wtr-lab',
      );
      addTearDown(() async {
        await db.close();
      });

      final spanish = SupportedLanguage.defaults.firstWhere(
        (l) => l.code == 'es',
      );
      final prefs = InMemoryTranslationRepository();
      await prefs.saveEnabled('b1', true);
      await prefs.saveTargetLanguage('b1', spanish);

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        translationRepositoryProvider.overrideWithValue(prefs),
        googleTranslateServiceProvider
            .overrideWithValue(const _FakeTranslateService()),
      ]);
      addTearDown(container.dispose);

      final reader = DriftReaderRepository(db);
      final chapter = (await reader.getChapters('b1')).valueOrThrow.single;
      final content =
          await container.read(readerChapterContentProvider(chapter).future);
      expect(content, '你好世界');
    });
  });
}
