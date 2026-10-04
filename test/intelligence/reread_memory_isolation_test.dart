import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/read_through.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

void main() {
  late AppDatabase db;
  late DriftStoryMemoryRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftStoryMemoryRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Re-Read Memory Isolation', () {
    const bookId = 'novel_re_read_101';

    test('getReadThroughs auto-creates default Primary Read session', () async {
      final res = await repository.getReadThroughs(bookId);
      expect(res, isA<Success<List<ReadThrough>>>());
      final list = (res as Success<List<ReadThrough>>).value;
      expect(list.length, 1);
      expect(list.first.id, 'default');
      expect(list.first.name, 'Primary Read');
      expect(list.first.isActive, isTrue);
      expect(list.first.currentChapter, 1);

      final activeRes = await repository.getActiveReadThrough(bookId);
      expect(activeRes, isA<Success<ReadThrough>>());
      expect((activeRes as Success<ReadThrough>).value.id, 'default');
    });

    test('isolates entities across distinct read-through sessions', () async {
      final now = DateTime.now();

      // Entity in 'default' read-through
      final entityDefault = StoryEntity(
        id: 'ent_default_1',
        bookId: bookId,
        readThroughId: 'default',
        type: StoryEntityType.character,
        canonicalName: 'Lin Dong',
        confidenceScore: 0.95,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        firstSeenChapter: 1,
        lastSeenChapter: 10,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(entityDefault);

      // Create second read-through session
      final newRtRes = await repository.createReadThrough(
        bookId,
        name: 'Second Run',
        copyFromDefault: false,
      );
      expect(newRtRes, isA<Success<ReadThrough>>());
      final newRt = (newRtRes as Success<ReadThrough>).value;

      // Entity in second read-through session
      final entitySecond = StoryEntity(
        id: 'ent_second_1',
        bookId: bookId,
        readThroughId: newRt.id,
        type: StoryEntityType.character,
        canonicalName: 'Xiao Yan',
        confidenceScore: 0.90,
        tier: ConfidenceTier.high,
        userConfirmed: false,
        firstSeenChapter: 5,
        lastSeenChapter: 8,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(entitySecond);

      // Verify default sees Lin Dong but NOT Xiao Yan
      final defaultEntitiesRes = await repository.getEntities(bookId, readThroughId: 'default');
      expect(defaultEntitiesRes, isA<Success<List<StoryEntity>>>());
      final defaultEntities = (defaultEntitiesRes as Success<List<StoryEntity>>).value;
      expect(defaultEntities.map((e) => e.canonicalName), contains('Lin Dong'));
      expect(defaultEntities.map((e) => e.canonicalName), isNot(contains('Xiao Yan')));

      // Verify second session sees Xiao Yan but NOT Lin Dong
      final secondEntitiesRes = await repository.getEntities(bookId, readThroughId: newRt.id);
      expect(secondEntitiesRes, isA<Success<List<StoryEntity>>>());
      final secondEntities = (secondEntitiesRes as Success<List<StoryEntity>>).value;
      expect(secondEntities.map((e) => e.canonicalName), contains('Xiao Yan'));
      expect(secondEntities.map((e) => e.canonicalName), isNot(contains('Lin Dong')));
    });

    test('clones user-confirmed entities and relationships when copyFromDefault is true', () async {
      final now = DateTime.now();

      // Confirmed character in default
      final confirmedChar = StoryEntity(
        id: 'c1',
        bookId: bookId,
        readThroughId: 'default',
        type: StoryEntityType.character,
        canonicalName: 'Lin Dong',
        confidenceScore: 0.95,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        firstSeenChapter: 1,
        lastSeenChapter: 10,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(confirmedChar);

      // Confirmed faction in default
      final confirmedFaction = StoryEntity(
        id: 'f1',
        bookId: bookId,
        readThroughId: 'default',
        type: StoryEntityType.faction,
        canonicalName: 'Lin Clan',
        confidenceScore: 0.90,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        firstSeenChapter: 1,
        lastSeenChapter: 5,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(confirmedFaction);

      // Unconfirmed character in default (should NOT be copied)
      final unconfirmedChar = StoryEntity(
        id: 'c2',
        bookId: bookId,
        readThroughId: 'default',
        type: StoryEntityType.character,
        canonicalName: 'Lei Li',
        confidenceScore: 0.40,
        tier: ConfidenceTier.low,
        userConfirmed: false,
        firstSeenChapter: 2,
        lastSeenChapter: 2,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(unconfirmedChar);

      // Relationship between confirmed entities
      final rel = StoryRelationship(
        id: 'rel_1',
        bookId: bookId,
        readThroughId: 'default',
        sourceEntityId: 'c1',
        targetEntityId: 'f1',
        relationType: 'member',
        confidenceScore: 0.90,
        chapterEstablished: 1,
        createdAt: now,
      );
      await repository.saveRelationship(rel);

      // Create new read-through with copyFromDefault: true
      final newRtRes = await repository.createReadThrough(
        bookId,
        name: 'Re-Read 2026',
        copyFromDefault: true,
      );
      expect(newRtRes, isA<Success<ReadThrough>>());
      final newRt = (newRtRes as Success<ReadThrough>).value;

      // Verify copied entities
      final copiedEntitiesRes = await repository.getEntities(bookId, readThroughId: newRt.id);
      expect(copiedEntitiesRes, isA<Success<List<StoryEntity>>>());
      final copiedEntities = (copiedEntitiesRes as Success<List<StoryEntity>>).value;

      expect(copiedEntities.length, 2);
      expect(copiedEntities.map((e) => e.canonicalName), containsAll(['Lin Dong', 'Lin Clan']));
      expect(copiedEntities.map((e) => e.canonicalName), isNot(contains('Lei Li')));

      // Verify cloned entity readThroughId is newRt.id
      for (final e in copiedEntities) {
        expect(e.readThroughId, newRt.id);
      }

      // Verify copied relationship
      final copiedRelsRes = await repository.getRelationships(bookId, readThroughId: newRt.id);
      expect(copiedRelsRes, isA<Success<List<StoryRelationship>>>());
      final copiedRels = (copiedRelsRes as Success<List<StoryRelationship>>).value;
      expect(copiedRels.length, 1);
      expect(copiedRels.first.relationType, 'member');
      expect(copiedRels.first.readThroughId, newRt.id);
    });

    test('deleting a read-through only deletes memory for that session', () async {
      final now = DateTime.now();

      final eDefault = StoryEntity(
        id: 'ed_1',
        bookId: bookId,
        readThroughId: 'default',
        type: StoryEntityType.character,
        canonicalName: 'Lin Dong',
        confidenceScore: 0.95,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        firstSeenChapter: 1,
        lastSeenChapter: 10,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(eDefault);

      final newRt = (await repository.createReadThrough(bookId, name: 'Temp Read')).asOrNull()!;
      final eTemp = StoryEntity(
        id: 'et_1',
        bookId: bookId,
        readThroughId: newRt.id,
        type: StoryEntityType.character,
        canonicalName: 'Temporary Hero',
        confidenceScore: 0.80,
        tier: ConfidenceTier.medium,
        userConfirmed: false,
        firstSeenChapter: 1,
        lastSeenChapter: 2,
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveEntity(eTemp);

      // Delete the temp session
      final delRes = await repository.deleteReadThrough(bookId, newRt.id);
      expect(delRes, isA<Success<void>>());

      // Verify temp entities are deleted
      final tempEntities = (await repository.getEntities(bookId, readThroughId: newRt.id)).asOrNull()!;
      expect(tempEntities, isEmpty);

      // Verify default entities remain intact
      final defaultEntities = (await repository.getEntities(bookId, readThroughId: 'default')).asOrNull()!;
      expect(defaultEntities.length, 1);
      expect(defaultEntities.first.canonicalName, 'Lin Dong');
    });

    test('setActiveReadThrough toggles active session correctly', () async {
      final rt2 = (await repository.createReadThrough(bookId, name: 'Pass 2')).asOrNull()!;

      var active = (await repository.getActiveReadThrough(bookId)).asOrNull()!;
      expect(active.id, 'default');

      await repository.setActiveReadThrough(bookId, rt2.id);

      active = (await repository.getActiveReadThrough(bookId)).asOrNull()!;
      expect(active.id, rt2.id);
      expect(active.name, 'Pass 2');
    });

    test('updateReadThroughProgress updates chapter index for specific session', () async {
      final rt2 = (await repository.createReadThrough(bookId, name: 'Pass 2')).asOrNull()!;

      await repository.updateReadThroughProgress(bookId, rt2.id, 42);

      final all = (await repository.getReadThroughs(bookId)).asOrNull()!;
      final updated = all.firstWhere((r) => r.id == rt2.id);
      expect(updated.currentChapter, 42);

      final def = all.firstWhere((r) => r.id == 'default');
      expect(def.currentChapter, 1);
    });
  });
}

extension _ResultExt<T> on Result<T> {
  T? asOrNull() => this is Success<T> ? (this as Success<T>).value : null;
}
