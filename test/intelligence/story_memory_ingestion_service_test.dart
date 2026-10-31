import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_memory_ingestion_service.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

const _chapterText = '''
Lin Dong raised his hand, and the stone seal above the pool began to glow.
"Is this the Ancient Talisman?" he whispered to Ling Qingzhu.

The Yuan Power in his meridians surged as he stepped into the Great Yan Empire's
hidden treasure vault. The domain master's spirit appeared beside him, warning
him of the Devouring Power hidden beneath the water.

"I will not leave without the talisman," Lin Dong declared, grabbing the stone
seal and feeling the Martial Ancestor's relic burn against his palm.
''';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  late StoryMemoryIngestionService service;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
    service = StoryMemoryIngestionService(
      repository: repository,
      extractor: EntityExtractor(repository: repository),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('StoryMemoryIngestionService', () {
    test('ingests a chapter: extracts entities and indexes scenes', () async {
      // Default production path: the extractor may run its scan in an isolate,
      // degrading to inline scanning when spawn is unavailable.
      final res = await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 3,
        chapterText: _chapterText,
      );

      expect(res, isA<Success<IngestionDecision>>());
      final decision = (res as Success<IngestionDecision>).value;
      expect(decision, isA<IngestionCompleted>());
      final completed = decision as IngestionCompleted;
      expect(completed.summary.chapterIndex, 3);
      expect(completed.sceneCount, greaterThan(0));

      // Extraction produced durable story memory.
      final entitiesRes = await repository.getEntities('book_1');
      expect(entitiesRes, isA<Success<List<StoryEntity>>>());
      final names = (entitiesRes as Success<List<StoryEntity>>)
          .value
          .map((e) => e.canonicalName)
          .toList();
      expect(names, contains('Lin Dong'));

      // Scene search now finds a quoted scene via FTS5.
      final scenesRes = await repository.searchScenes('book_1', 'talisman');
      expect(scenesRes, isA<Success<List<String>>>());
      expect((scenesRes as Success<List<String>>).value, isNotEmpty);
    });

    test('is idempotent: re-ingesting identical text skips', () async {
      await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 1,
        chapterText: _chapterText,
      );
      final entityCountBefore =
          (await (repository.getEntities('book_1')) as Success<List<StoryEntity>>).value.length;

      final second = await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 1,
        chapterText: _chapterText,
      );
      expect(second, isA<Success<IngestionDecision>>());
      expect(
        (second as Success<IngestionDecision>).value,
        isA<IngestionSkippedAlreadyDone>(),
      );

      // No double extraction: mention counts were not incremented again.
      final entitiesAfter =
          (await (repository.getEntities('book_1')) as Success<List<StoryEntity>>).value;
      expect(entitiesAfter.length, entityCountBefore);
    });

    test('re-extracts when chapter text changed (translation rewrite)', () async {
      await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 2,
        chapterText: _chapterText,
      );

      const translated = '$_chapterText\nXiao Yan arrived next scene.';
      final third = await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 2,
        chapterText: translated,
      );

      expect(third, isA<Success<IngestionDecision>>());
      expect((third as Success<IngestionDecision>).value, isA<IngestionCompleted>());
    });

    test('skips empty text', () async {
      final res = await service.ingestChapter(
        bookId: 'book_1',
        chapterIndex: 1,
        chapterText: '   ',
      );
      expect((res as Success<IngestionDecision>).value, isA<IngestionSkippedEmpty>());
    });

    test('read-through isolation: separate sessions extract independently', () async {
      await service.ingestChapter(
        bookId: 'book_1',
        readThroughId: 'default',
        chapterIndex: 1,
        chapterText: _chapterText,
      );

      // A different read-through has not yet ingested this chapter.
      final other = await service.ingestChapter(
        bookId: 'book_1',
        readThroughId: 'rt_second',
        chapterIndex: 1,
        chapterText: _chapterText,
      );
      expect((other as Success<IngestionDecision>).value, isA<IngestionCompleted>());
    });

    test('textHash is stable for identical content', () {
      expect(service.textHash(_chapterText), service.textHash(_chapterText));
      expect(
        service.textHash(_chapterText),
        isNot(service.textHash('$_chapterText ')),
      );
    });

    test('splitScenes chunks paragraph text within bounds', () {
      final paragraphs = List.generate(
        40,
        (i) => 'Scene paragraph $i with plenty of dialogue and narrative detail to '
            'make it long enough to hit the minimum scene size of the chunker. '
            'It contains a battle between Lin Dong and the Devouring Power.',
      );
      final scenes = StoryMemoryIngestionService.splitScenes(paragraphs.join('\n'));
      expect(scenes, isNotEmpty);
      for (final scene in scenes.take(scenes.length - 1)) {
        expect(scene.length, greaterThanOrEqualTo(400));
        expect(scene.length, lessThan(1200 + 130));
      }
    });
  });
}
