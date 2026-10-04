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
  Future<Result<List<StoryRelationship>>> getRelationships(
    String bookId, {
    String readThroughId = 'default',
    String? entityId,
  });

  /// Saves a recognized relationship.
  Future<Result<void>> saveRelationship(StoryRelationship relationship);

  /// Batch saves recognized relationships.
  Future<Result<void>> saveRelationships(List<StoryRelationship> relationships);

  /// Fetches events up to [maxChapter], optionally filtered by involved entities.
  Future<Result<List<StoryEvent>>> getEvents(
    String bookId, {
    String readThroughId = 'default',
    int? maxChapter,
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

  /// Fetches items awaiting human review in the review queue.
  Future<Result<List<ReviewItem>>> getReviewQueue(
    String bookId, {
    String readThroughId = 'default',
    ReviewStatus status = ReviewStatus.pending,
  });

  /// Adds an item to the review queue.
  Future<Result<void>> saveReviewItem(ReviewItem item);

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

