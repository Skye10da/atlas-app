import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;
  late EntityExtractor extractor;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
    extractor = EntityExtractor(repository: repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('EntityExtractor Pipeline', () {
    const chapter1 = '''
      The Great Wasteland stretched endlessly into the horizon.
      "We must proceed with caution," said Lin Dong, his gaze steady.
      Beside him, Elder Mo nodded gently. "The Lin Clan has awaited this opportunity for a hundred years."
      They arrived at Black Water City as dusk settled over the misty plains.
      In his grasp, the Stone Talisman hummed with ancient primal energy.
    ''';

    test('extracts entities across types and saves to Story Memory', () async {
      final summaryRes = await extractor.processChapter(
        bookId: 'book_wdqk',
        chapterIndex: 1,
        chapterText: chapter1,
        runInIsolate: false, // Run inline for unit test predictability
      );

      expect(summaryRes, isA<Success<ChapterExtractionSummary>>());
      final summary = (summaryRes as Success<ChapterExtractionSummary>).value;
      expect(summary.chapterIndex, 1);
      expect(summary.newEntitiesCount, greaterThan(0));

      final entitiesRes = await repository.getEntities('book_wdqk');
      expect(entitiesRes, isA<Success<List<StoryEntity>>>());
      final entities = (entitiesRes as Success<List<StoryEntity>>).value;

      final names = entities.map((e) => e.canonicalName).toSet();
      expect(names, containsAll(['Lin Dong', 'Mo', 'Lin Clan', 'Black Water City', 'Stone Talisman']));

      // Verify entity types
      final linDong = entities.firstWhere((e) => e.canonicalName == 'Lin Dong');
      expect(linDong.type, StoryEntityType.character);
      expect(linDong.firstSeenChapter, 1);
      expect(linDong.mentionCount, 1);

      final linClan = entities.firstWhere((e) => e.canonicalName == 'Lin Clan');
      expect(linClan.type, StoryEntityType.faction);

      final city = entities.firstWhere((e) => e.canonicalName == 'Black Water City');
      expect(city.type, StoryEntityType.location);

      final talisman = entities.firstWhere((e) => e.canonicalName == 'Stone Talisman');
      expect(talisman.type, StoryEntityType.item);

      // Verify co-occurrences were recorded
      final edgesRes = await repository.getCooccurrences('book_wdqk');
      expect((edgesRes as Success<List<StoryCooccurrence>>).value.isNotEmpty, isTrue);
    });

    test('re-processing does not duplicate entities, updates confidence instead', () async {
      await extractor.processChapter(
        bookId: 'book_wdqk',
        chapterIndex: 1,
        chapterText: chapter1,
        runInIsolate: false,
      );

      final initialRes = await repository.getEntities('book_wdqk');
      final initialEntities = (initialRes as Success<List<StoryEntity>>).value;
      final initialLinDong = initialEntities.firstWhere((e) => e.canonicalName == 'Lin Dong');
      final initialScore = initialLinDong.confidenceScore;
      final initialMentions = initialLinDong.mentionCount;

      // Process again with same chapter
      await extractor.processChapter(
        bookId: 'book_wdqk',
        chapterIndex: 1,
        chapterText: chapter1,
        runInIsolate: false,
      );

      final secondRes = await repository.getEntities('book_wdqk');
      final secondEntities = (secondRes as Success<List<StoryEntity>>).value;

      // Count of Lin Dong must still be exactly 1 entity
      final linDongMatches = secondEntities.where((e) => e.canonicalName == 'Lin Dong');
      expect(linDongMatches.length, 1);

      final updatedLinDong = linDongMatches.first;
      expect(updatedLinDong.mentionCount, initialMentions + 1);
      expect(updatedLinDong.confidenceScore, greaterThan(initialScore));
    });

    test('queues transliteration alias variants to review queue', () async {
      await extractor.processChapter(
        bookId: 'book_wdqk',
        chapterIndex: 1,
        chapterText: chapter1,
        runInIsolate: false,
      );

      // Chapter 2 uses hyphenated spelling "Lin-dong"
      const chapter2 = '''
        "Watch out!" yelled Lin-dong as a demonic beast lunged.
      ''';

      await extractor.processChapter(
        bookId: 'book_wdqk',
        chapterIndex: 2,
        chapterText: chapter2,
        runInIsolate: false,
      );

      final queueRes = await repository.getReviewQueue('book_wdqk');
      expect(queueRes, isA<Success<List<ReviewItem>>>());
      final queue = (queueRes as Success<List<ReviewItem>>).value;

      expect(queue.isNotEmpty, isTrue);
      final aliasItem = queue.firstWhere((q) => q.type == ReviewType.mergeCandidates);
      expect(aliasItem.candidateName, 'Lin-dong');
      expect(aliasItem.targetName, 'Lin Dong');
      expect(aliasItem.similarityScore, greaterThanOrEqualTo(0.75));
    });
  });
}
