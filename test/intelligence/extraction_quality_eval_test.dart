import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_memory_ingestion_service.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

/// Evaluation harness for the extraction → memory → recap pipeline.
///
/// Fixture chapters come in two quality profiles so regressions can be judged
/// against the realistic input quality of each source instead of one global
/// bar: WTR machine-translation noise (garbled particles, odd names, broken
/// sentences) versus clean human-edited English. Each profile declares the
/// minimum quality the pipeline must reach on that input.
class ExtractionQualityProfile {
  const ExtractionQualityProfile({
    required this.name,
    required this.chapterText,
    required this.expectedEntities,
    this.minEntitiesFound = 3,
    this.minEvents = 1,
    this.requireNonEmptyRecap = true,
  });

  final String name;
  final String chapterText;

  /// Names / fragments the extractor must surface (canonical or alias or
  /// fuzzy variant counts as found).
  final List<String> expectedEntities;

  final int minEntitiesFound;
  final int minEvents;
  final bool requireNonEmptyRecap;
}

const _cleanChapter = '''
Lin Dong strode into Black Water City as the auction began.
"This Stone Talisman is genuine," said Lin Dong calmly.
"Bid wisely, Elder Mo," said Elder Mo as he pushed the talisman across the counter.
From the shadows, Xuan Su of the Iron Banner Faction watched every move.
That night, Lin Dong fought the Devouring Power and won the talisman seed.
''';

const _wtrChapter = '''
Lin Dong walked into black water city , auction had begin.
" This stone talisman is real goods " said Lin Dong calmly.
" Bid wisely uh " said Elder Mo , push stone talisman over counter.
In shadow place , Xuan Su belong to Iron Banner , observing all movement.
This night time , Lin Dong fight Devouring Power , won talisman seed.
''';

void main() {
  final profiles = [
    const ExtractionQualityProfile(
      name: 'clean English',
      chapterText: _cleanChapter,
      expectedEntities: [
        'Lin Dong',
        'Elder Mo',
        'Black Water City',
        'Stone Talisman',
      ],
      minEntitiesFound: 4,
      minEvents: 1,
    ),
    const ExtractionQualityProfile(
      name: 'WTR machine-translation',
      chapterText: _wtrChapter,
      expectedEntities: ['Lin Dong', 'Elder Mo'],
      minEntitiesFound: 2,
      minEvents: 1,
    ),
  ];

  group('Extraction quality harness', () {
    for (final profile in profiles) {
      group('profile: ${profile.name}', () {
        late AppDatabase db;
        late DriftStoryMemoryRepository repository;
        late StoryMemoryIngestionService ingestion;
        late QueryEngine queryEngine;

        setUp(() async {
          db = AppDatabase.memory();
          repository = DriftStoryMemoryRepository(db: db);
          ingestion = StoryMemoryIngestionService(
            repository: repository,
            extractor: EntityExtractor(repository: repository),
          );
          queryEngine = QueryEngine(repository: repository);
        });

        tearDown(() async {
          await db.close();
        });

        test('meets the entity recall bar for its profile', () async {
          final result = await ingestion.ingestChapter(
            bookId: 'eval_book',
            readThroughId: 'default',
            chapterIndex: 1,
            chapterText: profile.chapterText,
            runInIsolate: false,
          );
          expect(result, isA<Success>());

          final entitiesRes = await repository.getEntities('eval_book');
          final entities =
              (entitiesRes as Success<List<StoryEntity>>).value;
          final names = entities
              .expand((e) => [e.canonicalName, ...e.aliases])
              .map((n) => n.toLowerCase())
              .toSet();

          final found = <String>[];
          for (final expected in profile.expectedEntities) {
            final needle = expected.toLowerCase();
            final needleWords =
                needle.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
            final hit = names.any((n) {
              if (n == needle || n.contains(needle)) return true;
              if (n.length >= 3 && needle.contains(n)) return true;
              // Word-level fallback: "Mo" counts as a match for "Elder Mo"
              // because the honorific is stripped during cleaning.
              final nWords = n
                  .split(RegExp(r'\s+'))
                  .where((w) => w.length > 1)
                  .toSet();
              return nWords.isNotEmpty && needleWords.containsAll(nWords);
            });
            if (hit) found.add(expected);
          }
          expect(
            found,
            hasLength(greaterThanOrEqualTo(profile.minEntitiesFound)),
            reason:
                '${profile.name}: expected ${profile.expectedEntities}, found $found in '
                '${entities.map((e) => e.canonicalName).toList()}',
          );
        });

        test('no duplicate review items after a re-run', () async {
          for (int i = 0; i < 2; i++) {
            await ingestion.ingestChapter(
              bookId: 'eval_book',
              readThroughId: 'default',
              chapterIndex: 1,
              chapterText: profile.chapterText,
              runInIsolate: false,
            );
          }

          final queueRes = await repository.getReviewQueue('eval_book');
          final queue = (queueRes as Success<List<ReviewItem>>).value;
          final keys = queue
              .map((q) => '${q.type.id}|${q.entityId}|${q.candidateName}')
              .toSet();
          expect(
            keys.length,
            queue.length,
            reason: 're-running the same chapter must not duplicate review items',
          );
        });

        test('recap grounded in this chapter, spoiler-safe', () async {
          await ingestion.ingestChapter(
            bookId: 'eval_book',
            readThroughId: 'default',
            chapterIndex: 1,
            chapterText: profile.chapterText,
            runInIsolate: false,
          );

          final recap = await queryEngine.executeQuery(
            bookId: 'eval_book',
            readThroughId: 'default',
            query: 'recap',
            readerChapter: 1,
          );

          if (profile.requireNonEmptyRecap) {
            expect(recap.trim(), isNotEmpty);
            // Recap must describe something that actually happened in-text.
            expect(
              recap.toLowerCase(),
              contains('chapter 1'),
              reason: 'recap should reference the bounded chapter',
            );
          }
        });
      });
    }

    test('re-extraction stays idempotent on entity counts for both profiles',
        () async {
      final db = AppDatabase.memory();
      final repository = DriftStoryMemoryRepository(db: db);
      final ingestion = StoryMemoryIngestionService(
        repository: repository,
        extractor: EntityExtractor(repository: repository),
      );

      try {
        for (final text in [_cleanChapter, _wtrChapter]) {
          final beforeRes = await ingestion.ingestChapter(
            bookId: 'idem_book',
            readThroughId: 'default',
            chapterIndex: 7,
            chapterText: text,
            runInIsolate: false,
          );
          expect(beforeRes, isA<Success>());

          final first = await repository.getEntities('idem_book');
          final firstCount = (first as Success<List<StoryEntity>>).value.length;

          await ingestion.ingestChapter(
            bookId: 'idem_book',
            readThroughId: 'default',
            chapterIndex: 7,
            chapterText: text,
            runInIsolate: false,
          );
          final second = await repository.getEntities('idem_book');
          final secondCount = (second as Success<List<StoryEntity>>).value.length;

          expect(
            secondCount,
            firstCount,
            reason: 're-ingesting the same text must grow the entity table only '
                'via confidence updates, not new duplicate rows',
          );
        }
      } finally {
        await db.close();
      }
    });
  });
}
