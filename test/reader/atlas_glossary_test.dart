import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/domain/entities/atlas_glossary_entry.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/atlas_glossary_repository_interface.dart';
import 'package:atlas_app/reader/domain/services/atlas_glossary_applier.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/infrastructure/repositories/shared_prefs_atlas_glossary_repository.dart';
import 'package:atlas_app/reader/presentation/providers/atlas_glossary_providers.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

extension<T> on Result<T> {
  T get valueOrThrow => switch (this) {
    Success(value: final value) => value,
    Failure() => throw StateError('Unexpected failure'),
  };
}

AtlasGlossaryEntry _entry(
  String term,
  List<String> replacements, {
  int activeIndex = 0,
}) {
  return AtlasGlossaryEntry(
    id: 'b1:$term',
    bookId: 'b1',
    term: term,
    replacements: replacements,
    activeIndex: activeIndex,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('AtlasGlossaryEntry', () {
    test('round-trips through JSON preserving the active option', () {
      final entry = _entry('中', const ['middle', 'center'], activeIndex: 1);
      final restored = AtlasGlossaryEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.term, '中');
      expect(restored.replacements, ['middle', 'center']);
      expect(restored.activeIndex, 1);
      expect(restored.activeReplacement, 'center');
    });

    test('activeReplacement is null for an out-of-range index', () {
      expect(
        _entry('中', const ['middle'], activeIndex: 5).activeReplacement,
        isNull,
      );
      expect(_entry('中', const []).activeReplacement, isNull);
      expect(
        _entry('中', const ['  ']).activeReplacement,
        isNull,
        reason: 'blank options are not usable',
      );
    });
  });

  group('AtlasGlossaryApplier', () {
    test('replaces each term with its active option', () {
      final out = AtlasGlossaryApplier.apply('A 中 a 正 b', [
        _entry('中', const ['middle']),
        _entry('正', const ['just']),
      ]);
      expect(out, 'A middle a just b');
    });

    test('prefers the longest term when phrases share characters', () {
      final out = AtlasGlossaryApplier.apply('王中烈 中', [
        _entry('中', const ['middle']),
        _entry('王中烈', const ['Wang Zhonglie']),
      ]);
      expect(out, 'Wang Zhonglie middle');
    });

    test('matches on the original text so replacements never chain', () {
      final out = AtlasGlossaryApplier.apply('甲', [
        _entry('甲', const ['乙']),
        _entry('乙', const ['丙']),
      ]);
      expect(out, '乙');
    });

    test('respects the active index when multiple options exist', () {
      final out = AtlasGlossaryApplier.apply('中', [
        _entry('中', const ['middle', 'center'], activeIndex: 1),
      ]);
      expect(out, 'center');
    });

    test('skips entries with no usable replacement', () {
      expect(AtlasGlossaryApplier.apply('中', [_entry('中', const [])]), '中');
      expect(
        AtlasGlossaryApplier.apply('正', [
          _entry('中', const ['middle']),
          _entry('正', const [' ']),
        ]),
        '正',
      );
    });

    test('is a no-op for empty content or an empty glossary', () {
      expect(
        AtlasGlossaryApplier.apply('', [
          _entry('中', const ['middle']),
        ]),
        '',
      );
      expect(AtlasGlossaryApplier.apply('中 a', const []), '中 a');
    });
  });

  group('SharedPrefsAtlasGlossaryRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and reloads a book glossary', () async {
      const repo = SharedPrefsAtlasGlossaryRepository();
      await repo.save('b1', [
        _entry('中', const ['middle']),
      ]);

      final loaded = await repo.load('b1');
      expect(loaded, hasLength(1));
      expect(loaded.single.term, '中');
      expect(loaded.single.activeReplacement, 'middle');
    });

    test('keeps each book glossary isolated', () async {
      const repo = SharedPrefsAtlasGlossaryRepository();
      await repo.save('b1', [
        _entry('中', const ['middle']),
      ]);
      await repo.save('b2', [
        _entry('正', const ['just']),
      ]);

      expect(await repo.load('b1'), hasLength(1));
      expect(await repo.load('b2'), hasLength(1));
      expect(await repo.load('b3'), isEmpty);
    });

    test('returns empty for corrupt stored JSON', () async {
      const repo = SharedPrefsAtlasGlossaryRepository();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('atlas_glossary_b1', 'not json');

      expect(await repo.load('b1'), isEmpty);
    });
  });

  group('AtlasGlossaryController', () {
    test('creates an entry on first upsert', () async {
      final repo = InMemoryAtlasGlossaryRepository();
      final controller = AtlasGlossaryController(repo);
      await controller.upsertTerm('b1', ' 中 ', ' middle ');

      final entries = await repo.load('b1');
      expect(entries.single.term, '中');
      expect(entries.single.replacements, ['middle']);
    });

    test(
      'adds a new option and makes it active when the term already exists',
      () async {
        final repo = InMemoryAtlasGlossaryRepository();
        await repo.save('b1', [
          _entry('中', const ['middle']),
        ]);
        final controller = AtlasGlossaryController(repo);

        await controller.upsertTerm('b1', '中', 'center');

        final entries = await repo.load('b1');
        expect(entries.single.replacements, ['middle', 'center']);
        expect(entries.single.activeReplacement, 'center');
      },
    );

    test(
      'selecting an existing option just switches the active index',
      () async {
        final repo = InMemoryAtlasGlossaryRepository();
        await repo.save('b1', [
          _entry('中', const ['middle', 'center']),
        ]);
        final controller = AtlasGlossaryController(repo);

        await controller.upsertTerm('b1', '中', 'middle');

        final entries = await repo.load('b1');
        expect(entries.single.replacements, ['middle', 'center']);
        expect(entries.single.activeReplacement, 'middle');
      },
    );

    test('adds options and switches the active one independently', () async {
      final repo = InMemoryAtlasGlossaryRepository();
      await repo.save('b1', [
        _entry('中', const ['middle']),
      ]);
      final controller = AtlasGlossaryController(repo);

      await controller.addReplacement('b1', 'b1:中', 'center');
      await controller.setActiveReplacement('b1', 'b1:中', 1);

      final entries = await repo.load('b1');
      expect(entries.single.replacements, ['middle', 'center']);
      expect(entries.single.activeReplacement, 'center');
    });

    test('removes an entry so the original term returns', () async {
      final repo = InMemoryAtlasGlossaryRepository();
      await repo.save('b1', [
        _entry('中', const ['middle']),
      ]);
      final controller = AtlasGlossaryController(repo);

      await controller.removeEntry('b1', 'b1:中');

      expect(await repo.load('b1'), isEmpty);
    });
  });

  group('readerChapterContentProvider glossary integration', () {
    test(
      'renders the glossary onto downloaded content without rewriting it',
      () async {
        final db = AppDatabase.memory();
        final reader = DriftReaderRepository(db);
        final tempDir = Directory.systemTemp.createTempSync('atlas_glossary');
        final file = File(p.join(tempDir.path, '0.txt'));
        file.writeAsStringSync('A 中 a 正 b');

        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion(
                id: const Value('b1_ch0'),
                bookId: const Value('b1'),
                index: const Value(0),
                title: const Value('Chapter 1'),
                contentPath: Value(file.path),
                wordCount: const Value(100),
                pageCount: const Value(1),
                contentState: Value(ContentState.availableOffline.index),
                version: const Value(1),
                createdAt: Value(DateTime(2025, 1, 1)),
              ),
            );

        final glossary = InMemoryAtlasGlossaryRepository();
        await glossary.save('b1', [
          _entry('中', const ['middle']),
        ]);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            atlasGlossaryRepositoryProvider.overrideWithValue(glossary),
          ],
        );
        addTearDown(container.dispose);

        final chapter = (await reader.getChapters('b1')).valueOrThrow.single;
        final content = await container.read(
          readerChapterContentProvider(chapter).future,
        );
        expect(content, 'A middle a 正 b');
        expect(
          file.readAsStringSync(),
          'A 中 a 正 b',
          reason: 'on-disk chapter text must stay untouched',
        );

        // Adding a term and invalidating the glossary re-renders the chapter.
        final controller = AtlasGlossaryController(glossary);
        await controller.upsertTerm('b1', '正', 'just');
        container.invalidate(atlasGlossaryProvider('b1'));
        final updated = await container.read(
          readerChapterContentProvider(chapter).future,
        );
        expect(updated, 'A middle a just b');

        await db.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });
}
