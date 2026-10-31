import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/corrections/correction_rule_engine.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_correction_repository.dart';
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

  ReviewItem item({
    required String id,
    String bookId = 'book_1',
    String readThroughId = 'default',
    ReviewType type = ReviewType.newEntity,
    String entityId = 'ent_1',
    String candidateName = 'Lin Dong',
    int chapterIndex = 3,
    ReviewStatus status = ReviewStatus.pending,
  }) =>
      ReviewItem(
        id: id,
        bookId: bookId,
        readThroughId: readThroughId,
        type: type,
        entityId: entityId,
        candidateName: candidateName,
        confidenceScore: 0.6,
        chapterIndex: chapterIndex,
        status: status,
        createdAt: DateTime(2026, 1, 1),
      );

  group('Batch review-queue writes', () {
    test('saveReviewItems persists every item in one call', () async {
      final res = await repository.saveReviewItems([
        item(id: 'rv1'),
        item(id: 'rv2', candidateName: 'Elder Mo', entityId: 'ent_2'),
        item(id: 'rv3', type: ReviewType.mergeCandidates, entityId: 'ent_3'),
      ]);

      expect(res, isA<Success<void>>());
      final queue = await repository.getReviewQueue('book_1');
      expect((queue as Success<List<ReviewItem>>).value, hasLength(3));
    });

    test('saveReviewItems with an empty list is a no-op success', () async {
      final res = await repository.saveReviewItems(const []);
      expect(res, isA<Success<void>>());
    });

    test('saveReviewItems dedup keys stay scoped per read-through', () async {
      await repository.saveReviewItems([
        item(id: 'rv1'),
        item(id: 'rv2', readThroughId: 'rt2'),
        item(id: 'rv3', readThroughId: 'rt3'),
      ]);

      final keysRes = await repository.pendingReviewItemKeys(
        bookId: 'book_1',
      );
      final keys = (keysRes as Success<Set<String>>).value;
      expect(keys, contains('new_entity|ent_1|Lin Dong'));
      expect(keys, hasLength(1));

      final rt2Res = await repository.pendingReviewItemKeys(
        bookId: 'book_1',
        readThroughId: 'rt2',
      );
      expect(
        (rt2Res as Success<Set<String>>).value,
        contains('new_entity|ent_1|Lin Dong'),
      );

      final rt3Res = await repository.pendingReviewItemKeys(
        bookId: 'book_other',
      );
      expect((rt3Res as Success<Set<String>>).value, isEmpty);
    });
  });

  group('CorrectionRuleEngine batch scoring', () {
    test('adjustmentFor mirrors SQL matching semantics', () {
      final engine = CorrectionRuleEngine(repository: _EngineHarness());
      final rules = [
        _rule('Lin', CorrectionDecision.confirm, StoryEntityType.character),
        _rule('elder mo', CorrectionDecision.reject, StoryEntityType.character),
        // Wrong type — must not affect the score.
        _rule('Lin', CorrectionDecision.reject, StoryEntityType.location),
      ];

      expect(engine.adjustmentFor(rules, 'Lin Dong', StoryEntityType.character), 0.20);
      expect(
        engine.adjustmentFor(rules, 'ELDER MO compares', StoryEntityType.character),
        -0.40,
      );
      expect(
        engine.adjustmentFor(rules, 'Wester Moren', StoryEntityType.character),
        0.0,
      );
      // SQL LIKE is a substring match: any candidate containing the pattern
      // (e.g. "Linx") picks up the rule, which the ported logic preserves.
      expect(
        engine.adjustmentFor(rules, 'Linx Zhao', StoryEntityType.character),
        0.20,
      );
      expect(engine.adjustmentFor(const [], 'Lin Dong', StoryEntityType.character), 0.0);
    });

    test('loadCorrectionsForBook prefetched rules cover global scope', () async {
      final repo = DriftCorrectionRepository(db: db);
      final engine = CorrectionRuleEngine(repository: repo);
      final now = DateTime(2026, 1, 1);

      await repo.saveCorrection(CorrectionRecord(
        id: 'c1',
        bookId: 'book_1',
        pattern: 'Lin',
        decision: CorrectionDecision.confirm,
        entityType: StoryEntityType.character,
        createdAt: now,
      ));
      await repo.saveCorrection(CorrectionRecord(
        id: 'c2',
        bookId: 'global',
        pattern: 'Stone Talisman',
        decision: CorrectionDecision.merge,
        entityType: StoryEntityType.item,
        createdAt: now,
      ));
      await repo.saveCorrection(CorrectionRecord(
        id: 'c3',
        bookId: 'book_other',
        pattern: 'Lin',
        decision: CorrectionDecision.reject,
        entityType: StoryEntityType.character,
        createdAt: now,
      ));

      final rules = await engine.loadCorrectionsForBook('book_1');
      expect(rules.map((r) => r.id), unorderedEquals(['c1', 'c2']));

      final delta = engine.adjustmentFor(
        rules,
        'Lin Guang',
        StoryEntityType.character,
      );
      expect(delta, greaterThan(0.0));
    });
  });
}

CorrectionRecord _rule(
  String pattern,
  CorrectionDecision decision,
  StoryEntityType type,
) =>
    CorrectionRecord(
      id: 'rule_$pattern',
      bookId: 'book_1',
      pattern: pattern,
      decision: decision,
      entityType: type,
      createdAt: DateTime(2026, 1, 1),
    );

/// Exposes the batch scoring API without a DB in the pure-semantics test.
class _EngineHarness implements CorrectionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('not used in adjustmentFor tests');

  // The engine only needs adjustmentFor here, which never touches the repo.
  @override
  Future<Result<List<CorrectionRecord>>> findMatchingCorrections(
    String bookId,
    String pattern,
    StoryEntityType type,
  ) async =>
      const Success([]);

  @override
  Future<Result<List<CorrectionRecord>>> getAllCorrections() async =>
      const Success([]);

  @override
  Future<Result<List<CorrectionRecord>>> getCorrections(String bookId) async =>
      const Success([]);

  @override
  Future<Result<void>> saveCorrection(CorrectionRecord record) async =>
      const Success(null);
}
