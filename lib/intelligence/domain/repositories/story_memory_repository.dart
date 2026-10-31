import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/read_through.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';

/// Abstract contract for reading, writing, and merging Story Memory
/// with multi-read-through memory isolation.
abstract interface class StoryMemoryRepository {
  /// Fetches entities for a book and read-through, optionally filtered by type or minimum tier.
  Future<Result<List<StoryEntity>>> getEntities(
    String bookId, {
    String readThroughId = 'default',
    StoryEntityType? type,
    ConfidenceTier? minTier,
  });

  /// Real-time stream of all entities for a book and read-through.
  Stream<List<StoryEntity>> watchEntities(
    String bookId, {
    String readThroughId = 'default',
  });

  /// Fetches an entity by ID.
  Future<Result<StoryEntity?>> getEntityById(String entityId);

  /// Looks up an entity by exact canonical name or listed alias within a read-through.
  Future<Result<StoryEntity?>> findEntityByNameOrAlias(
    String bookId,
    String name, {
    String readThroughId = 'default',
  });

  /// Saves or updates a single entity.
  Future<Result<void>> saveEntity(StoryEntity entity);

  /// Batch saves or updates multiple entities.
  Future<Result<void>> saveEntities(List<StoryEntity> entities);

  /// Deletes an entity by ID.
  Future<Result<void>> deleteEntity(String entityId);

  /// Merges [absorbedEntityId] into [keepEntityId], transferring aliases,
  /// updating relationships and events, and recalculating confidence.
  Future<Result<StoryEntity>> mergeEntities(
    String bookId, {
    String readThroughId = 'default',
    required String keepEntityId,
    required String absorbedEntityId,
  });

  /// Fetches relationships for a book, optionally filtered by an involved entity.
  ///
  /// When [maxChapter] is set, only relationships established up to and
  /// including that chapter are returned — the anti-spoiler guarantee that
  /// backs "who is X?" style queries at the reader's current chapter.
  Future<Result<List<StoryRelationship>>> getRelationships(
    String bookId, {
    String readThroughId = 'default',
    String? entityId,
    int? maxChapter,
  });

  /// Saves a recognized relationship.
  Future<Result<void>> saveRelationship(StoryRelationship relationship);

  /// Batch saves recognized relationships.
  Future<Result<void>> saveRelationships(List<StoryRelationship> relationships);

  /// Fetches events up to [maxChapter], optionally filtered to the exact
  /// [chapterExact] chapter and optionally filtered by involved entities.
  ///
  /// [chapterExact] lets single-chapter queries ("what happened in
  /// chapter 7?") filter in SQL instead of fetching the full event history.
  Future<Result<List<StoryEvent>>> getEvents(
    String bookId, {
    String readThroughId = 'default',
    int? maxChapter,
    int? chapterExact,
    List<String>? involvedEntityIds,
  });

  /// Saves a batch of plot events.
  Future<Result<void>> saveEvents(List<StoryEvent> events);

  /// Fetches co-occurrence graph edges for a book and read-through.
  Future<Result<List<StoryCooccurrence>>> getCooccurrences(
    String bookId, {
    String readThroughId = 'default',
  });

  /// Updates or inserts co-occurrence edge weights.
  Future<Result<void>> updateCooccurrences(
    String bookId,
    List<StoryCooccurrence> edges, {
    String readThroughId = 'default',
  });

  /// Fetches only the co-occurrence edges touching any of [entityIds] —
  /// the targeted read an extraction pass uses to seed its
  /// [CooccurrenceGraph] with persisted history instead of starting empty.
  Future<Result<List<StoryCooccurrence>>> getCooccurrencesForEntities(
    String bookId,
    Set<String> entityIds, {
    String readThroughId = 'default',
  });

  /// Fetches items awaiting human review in the review queue.
  Future<Result<List<ReviewItem>>> getReviewQueue(
    String bookId, {
    String readThroughId = 'default',
    ReviewStatus status = ReviewStatus.pending,
  });

  /// Adds an item to the review queue.
  Future<Result<void>> saveReviewItem(ReviewItem item);

  /// Adds [items] to the review queue in a single transaction — the batched
  /// form used by the extraction pass so a chapter's candidates cost one
  /// transaction instead of one per item.
  Future<Result<void>> saveReviewItems(List<ReviewItem> items);

  /// Returns the pending (unresolved) review-queue dedup keys for a book /
  /// read-through as `type|entityId|candidateName` strings — the prefetch
  /// that lets an extraction pass deduplicate candidates in memory instead
  /// of issuing one SQL check per candidate.
  Future<Result<Set<String>>> pendingReviewItemKeys({
    required String bookId,
    String readThroughId = 'default',
  });

  /// Returns true when a pending (unresolved) review item already exists for
  /// the same entity + candidate + type — the idempotency guard that keeps
  /// re-extracted chapters from flooding the review queue with duplicates.
  Future<Result<bool>> hasPendingReviewItem({
    required String bookId,
    String readThroughId = 'default',
    required ReviewType type,
    required String entityId,
    required String candidateName,
  });

  /// Resolves or dismisses a review item.
  Future<Result<void>> resolveReviewItem(String reviewId, ReviewStatus status);

  /// Cascade-deletes Story Memory for a novel. If [readThroughId] is specified,
  /// deletes only memory belonging to that read-through. If null, deletes all read-throughs
  /// and memories for that novel.
  Future<Result<void>> deleteBookStoryMemory(String bookId, {String? readThroughId});

  /// Searches scene excerpts using SQLite FTS5 for query terms up to [maxChapter].
  Future<Result<List<String>>> searchScenes(
    String bookId,
    String query, {
    String readThroughId = 'default',
    int? maxChapter,
    int limit = 10,
  });

  /// Returns the set of chapter indexes already logged as ingested for a
  /// book / read-through — the coverage snapshot a backfill pass needs to
  /// decide what still lacks story memory.
  Future<Result<Set<int>>> ingestedChapterIndexes({
    required String bookId,
    String readThroughId = 'default',
  });

  /// Returns the persisted recap text for one (book, read-through, chapter)
  /// key, or null when no snapshot has been generated yet. The detail page
  /// renders from this cache instantly; recompute overwrites the same key.
  Future<Result<String?>> getRecapSnapshot({
    required String bookId,
    String readThroughId = 'default',
    required int chapterIndex,
  });

  /// Persists the recap text for one (book, read-through, chapter) key,
  /// replacing any previous snapshot for that key.
  Future<Result<void>> saveRecapSnapshot({
    required String bookId,
    String readThroughId = 'default',
    required int chapterIndex,
    required String recapText,
  });

  /// Replaces the FTS5 scene rows for one chapter with fresh [scenes]
  /// (delete-then-insert, safe for re-extraction). Read-through agnostic:
  /// scenes bound to the book's raw chapter text shared by all read-throughs.
  Future<Result<void>> saveScenes(
    String bookId,
    int chapterIndex,
    List<String> scenes,
  );

  /// Returns true when a chapter has already been extracted under the exact
  /// same [textHash] for [bookId]/[readThroughId] — the idempotency guard that
  /// keeps re-opening a chapter from re-running the full extraction pipeline.
  Future<Result<bool>> isChapterIngested(
    String bookId,
    String readThroughId,
    int chapterIndex,
    String textHash,
  );

  /// Marks a chapter as ingested with the given [textHash] so a later pass
  /// with identical text short-circuits in [isChapterIngested].
  Future<Result<void>> recordChapterIngestion(
    String bookId,
    String readThroughId,
    int chapterIndex,
    String textHash,
  );

  /// Fetches all read-through sessions for [bookId].
  Future<Result<List<ReadThrough>>> getReadThroughs(String bookId);

  /// Fetches the currently active read-through session for [bookId].
  Future<Result<ReadThrough>> getActiveReadThrough(String bookId);

  /// Creates a new read-through session. If [copyFromDefault] is true,
  /// deep-copies confirmed entities and relationships from the 'default' read-through.
  Future<Result<ReadThrough>> createReadThrough(
    String bookId, {
    required String name,
    bool copyFromDefault = false,
  });

  /// Sets [readThroughId] as the active session for [bookId], deactivating others.
  Future<Result<void>> setActiveReadThrough(String bookId, String readThroughId);

  /// Updates chapter reading progress for a read-through.
  Future<Result<void>> updateReadThroughProgress(
    String bookId,
    String readThroughId,
    int chapter,
  );

  /// Deletes a specific read-through and cascades deletion of its isolated memory.
  Future<Result<void>> deleteReadThrough(String bookId, String readThroughId);
}

