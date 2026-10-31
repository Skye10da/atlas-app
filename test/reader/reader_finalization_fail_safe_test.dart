import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/translation_repository.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/providers/translation_providers.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';

/// A repository whose every load never completes — models a wedged
/// SharedPreferences/platform look-up.
class _NeverResolvingTranslationRepository implements TranslationRepository {
  const _NeverResolvingTranslationRepository();

  @override
  Future<SupportedLanguage?> loadTargetLanguage(
    String bookId, {
    List<SupportedLanguage>? languages,
  }) => Completer<SupportedLanguage?>().future;

  @override
  Future<bool> loadEnabled(String bookId) => Completer<bool>().future;

  @override
  Future<void> saveEnabled(String bookId, bool enabled) async {}

  @override
  Future<void> saveTargetLanguage(
    String bookId,
    SupportedLanguage language,
  ) async {}
}

/// Glossary repository whose [load] is fully controlled per test.
class _StubGlossaryRepository implements AtlasGlossaryRepository {
  _StubGlossaryRepository(this._loader);

  final Future<List<AtlasGlossaryEntry>> Function() _loader;

  @override
  Future<List<AtlasGlossaryEntry>> load(String bookId) => _loader();

  @override
  Future<void> save(String bookId, List<AtlasGlossaryEntry> entries) async {}
}

/// Regression tests for the "stuck on Preparing reader" reader bug.
///
/// Root cause: the chapter finalization chain (`_applyTranslation` →
/// `getBookById` → `targetLanguageProvider`, then `_applyAtlasGlossary`) used
/// to await SharedPreferences/drift-backed lookups without any bound; when
/// one wedged, `readerChapterContentProvider` never resolved and the reader
/// stayed on "Preparing reader" until it was closed and reopened. Every await
/// is now capped by [ReaderLoadFailSafes] and the whole chain runs under a
/// finalization deadline, so the provider always resolves (fail-soft to raw
/// text).
void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('atlas_reader_failsafe');
    db = AppDatabase.memory();
    // Shrink the fail-safe durations so wedged dependencies surface in
    // milliseconds instead of production-level seconds.
    ReaderLoadFailSafes.translationEnabled = const Duration(milliseconds: 120);
    ReaderLoadFailSafes.glossary = const Duration(milliseconds: 120);
    ReaderLoadFailSafes.bookLookup = const Duration(milliseconds: 120);
    ReaderLoadFailSafes.targetLanguage = const Duration(milliseconds: 120);
    ReaderLoadFailSafes.finalization = const Duration(milliseconds: 600);
  });

  tearDown(() async {
    ReaderLoadFailSafes.reset();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ChapterEntity makeChapter({
    required String id,
    required String bookId,
    required int index,
    required String title,
    required String contentPath,
  }) {
    return ChapterEntity(
      id: id,
      bookId: bookId,
      index: index,
      title: title,
      contentPath: contentPath,
      wordCount: 100,
      pageCount: 1,
      contentState: ContentState.availableOffline.index,
      version: 1,
    );
  }

  test(
    'wedged translation-enabled lookup resolves the chapter instead of '
    'sticking on Preparing reader',
    () async {
      final filePath = p.join(tempDir.path, 'ch1.txt');
      File(filePath).writeAsStringSync('Cached chapter text');

      final chapter = makeChapter(
        id: 'ch-1',
        bookId: 'book-1',
        index: 0,
        title: 'Chapter 1',
        contentPath: filePath,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Models the historic wedge: enable prefs never resolve.
          translationRepositoryProvider.overrideWithValue(
            const _NeverResolvingTranslationRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The provider must resolve (fail-soft: untranslated raw text).
      final content = await container
          .read(readerChapterContentProvider(chapter).future)
          .timeout(const Duration(seconds: 5));
      expect(content, 'Cached chapter text');

      // Phase advanced to "preparing" once the display text was final.
      await pumpEventQueue();
      expect(
        container.read(chapterLoadPhaseProvider(chapter)),
        ChapterLoadPhase.preparing,
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'wedged glossary load resolves the chapter instead of sticking on '
    'Preparing reader',
    () async {
      final filePath = p.join(tempDir.path, 'ch2.txt');
      File(filePath).writeAsStringSync('Cached chapter text');

      final chapter = makeChapter(
        id: 'ch-2',
        bookId: 'book-1',
        index: 1,
        title: 'Chapter 2',
        contentPath: filePath,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Models the historic wedge: glossary prefs never resolve.
          atlasGlossaryRepositoryProvider.overrideWithValue(
            _StubGlossaryRepository(
              () => Completer<List<AtlasGlossaryEntry>>().future,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final content = await container
          .read(readerChapterContentProvider(chapter).future)
          .timeout(const Duration(seconds: 5));
      expect(content, 'Cached chapter text');

      await pumpEventQueue();
      expect(
        container.read(chapterLoadPhaseProvider(chapter)),
        ChapterLoadPhase.preparing,
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'combined wedged finalization (translation + glossary) still resolves '
    'within the finalization fail-safe',
    () async {
      final filePath = p.join(tempDir.path, 'ch3.txt');
      File(filePath).writeAsStringSync('Cached chapter text');

      final chapter = makeChapter(
        id: 'ch-3',
        bookId: 'book-1',
        index: 2,
        title: 'Chapter 3',
        contentPath: filePath,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          translationRepositoryProvider.overrideWithValue(
            const _NeverResolvingTranslationRepository(),
          ),
          atlasGlossaryRepositoryProvider.overrideWithValue(
            _StubGlossaryRepository(
              () => Completer<List<AtlasGlossaryEntry>>().future,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final content = await container
          .read(readerChapterContentProvider(chapter).future)
          .timeout(const Duration(seconds: 5));
      expect(content, 'Cached chapter text');
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'phase pill shows processing during transforms and preparing only once '
    'the display text is final',
    () async {
      final filePath = p.join(tempDir.path, 'ch4.txt');
      File(filePath).writeAsStringSync('Cached chapter text');

      final chapter = makeChapter(
        id: 'ch-4',
        bookId: 'book-1',
        index: 3,
        title: 'Chapter 4',
        contentPath: filePath,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Hold the glossary lookup briefly so transform time is observable.
          atlasGlossaryRepositoryProvider.overrideWithValue(
            _StubGlossaryRepository(() async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return const <AtlasGlossaryEntry>[];
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      final phases = <ChapterLoadPhase>[];
      container.listen(chapterLoadPhaseProvider(chapter), (_, next) {
        phases.add(next);
      });

      await container.read(readerChapterContentProvider(chapter).future);
      await pumpEventQueue();

      expect(phases, [
        ChapterLoadPhase.processing,
        ChapterLoadPhase.preparing,
      ]);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
