import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';

/// Regression tests for the seeded co-occurrence graph:
///
/// The extraction pass used to start with an EMPTY graph every chapter,
/// so a pair co-present N chapters still carried weight 1 into the DB
/// upsert (double-counting: `weight = stored + excluded.weight`) and the
/// distinctness gate (co-occur ≥ 2 → distinct) never blocked, spawning
/// merge proposals for recurring distinct characters on every pass.
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

  const chapter = '''
    The Great Wasteland stretched endlessly into the horizon.
    "We must proceed with caution," said Lin Dong, his gaze steady.
    Beside him, Elder Mo nodded gently. "The Lin Clan has awaited this opportunity for a hundred years."
    They arrived at Black Water City as dusk settled over the misty plains.
    In his grasp, the Stone Talisman hummed with ancient primal energy.
  ''';

  test('co-occurrence weights accumulate across passes without double-counting',
      () async {
    await extractor.processChapter(
      bookId: 'book_seed',
      chapterIndex: 1,
      chapterText: chapter,
      runInIsolate: false,
    );

    final firstEdges = await repository.getCooccurrences('book_seed');
    final first = (firstEdges as Success<List<StoryCooccurrence>>).value;
    expect(first, isNotEmpty);
    // First pass: every co-present pair starts at weight 1.
    for (final edge in first) {
      expect(edge.weight, 1, reason: 'edge ${edge.id}');
    }

    // Second identical pass must bump each pair to exactly 2.
    await extractor.processChapter(
      bookId: 'book_seed',
      chapterIndex: 1,
      chapterText: chapter,
      runInIsolate: false,
    );

    final secondEdges = await repository.getCooccurrences('book_seed');
    final second = (secondEdges as Success<List<StoryCooccurrence>>).value;
    expect(second.length, first.length);
    for (final edge in second) {
      expect(edge.weight, 2, reason: 'edge ${edge.id}');
    }

    // Third pass keeps the increment linear (weight 3).
    await extractor.processChapter(
      bookId: 'book_seed',
      chapterIndex: 1,
      chapterText: chapter,
      runInIsolate: false,
    );
    final thirdEdges = await repository.getCooccurrences('book_seed');
    for (final edge in (thirdEdges as Success<List<StoryCooccurrence>>).value) {
      expect(edge.weight, 3, reason: 'edge ${edge.id}');
    }
  });

  test('same-type pairs that co-occur do not spawn merge proposals every pass',
      () async {
    await extractor.processChapter(
      bookId: 'book_distinct',
      chapterIndex: 1,
      chapterText: chapter,
      runInIsolate: false,
    );
    final firstQueue = await repository.getReviewQueue('book_distinct');
    final firstMergeCount = (firstQueue as Success<List<ReviewItem>>)
        .value
        .where((i) => i.type == ReviewType.mergeCandidates)
        .length;

    // Second pass: the seeded graph now weights every co-present pair ≥ 2,
    // so the clusterer's distinctness gate blocks them.
    await extractor.processChapter(
      bookId: 'book_distinct',
      chapterIndex: 1,
      chapterText: chapter,
      runInIsolate: false,
    );
    final secondQueue = await repository.getReviewQueue('book_distinct');
    final secondMergeCount = (secondQueue as Success<List<ReviewItem>>)
        .value
        .where((i) => i.type == ReviewType.mergeCandidates)
        .length;

    expect(secondMergeCount, firstMergeCount,
        reason: 'recurring co-present pairs must not re-propose merges');
  });
}
