import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/corrections/correction_store.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

class ReviewQueueState {
  const ReviewQueueState({
    required this.bookId,
    this.readThroughId = 'default',
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final String bookId;
  final String readThroughId;
  final List<ReviewItem> items;
  final bool isLoading;
  final String? errorMessage;

  ReviewQueueState copyWith({
    String? bookId,
    String? readThroughId,
    List<ReviewItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReviewQueueState(
      bookId: bookId ?? this.bookId,
      readThroughId: readThroughId ?? this.readThroughId,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ReviewQueueController extends StateNotifier<ReviewQueueState> {
  ReviewQueueController({
    required String bookId,
    String readThroughId = 'default',
    required StoryMemoryRepository repository,
    required CorrectionStore correctionStore,
  })  : _repository = repository,
        _correctionStore = correctionStore,
        super(ReviewQueueState(bookId: bookId, readThroughId: readThroughId)) {
    loadPending();
  }

  final StoryMemoryRepository _repository;
  final CorrectionStore _correctionStore;

  Future<void> loadPending() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final res = await _repository.getReviewQueue(
      state.bookId,
      status: ReviewStatus.pending,
      readThroughId: state.readThroughId,
    );
    if (res is Success<List<ReviewItem>>) {
      state = state.copyWith(items: res.value, isLoading: false);
    } else if (res is Failure<List<ReviewItem>>) {
      state = state.copyWith(isLoading: false, errorMessage: res.error.userMessage);
    }
  }

  /// Confirms a low-confidence entity, upgrading it to Confirmed/High tier
  /// and recording a positive active-learning correction rule.
  Future<Result<void>> confirmEntity(ReviewItem item) async {
    // 1. If provisional, create or update the entity with userConfirmed = true
    final existingRes = await _repository.getEntityById(item.entityId);
    if (existingRes is Success<StoryEntity?> && existingRes.value != null) {
      final existing = existingRes.value!;
      final confirmed = existing.copyWith(
        confidenceScore: 0.95,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        updatedAt: DateTime.now(),
      );
      await _repository.saveEntity(confirmed);
    } else {
      final newEntity = StoryEntity(
        id: item.entityId.startsWith('prov_')
            ? '${item.bookId}:ent:${DateTime.now().microsecondsSinceEpoch}'
            : item.entityId,
        bookId: item.bookId,
        readThroughId: item.readThroughId,
        type: StoryEntityType.character,
        canonicalName: item.candidateName,
        confidenceScore: 0.95,
        tier: ConfidenceTier.high,
        userConfirmed: true,
        firstSeenChapter: item.chapterIndex,
        lastSeenChapter: item.chapterIndex,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repository.saveEntity(newEntity);
    }

    // 2. Mark review item as resolved
    await _repository.resolveReviewItem(item.id, ReviewStatus.resolved);

    // 3. Store active learning rule
    await _correctionStore.recordDecision(
      id: '${item.bookId}:corr:${DateTime.now().millisecondsSinceEpoch}',
      pattern: item.candidateName,
      decision: CorrectionDecision.confirm,
      entityType: StoryEntityType.character,
      bookId: item.bookId,
    );

    await loadPending();
    return const Success(null);
  }

  /// Merges candidate into target entity and records merge pattern rule.
  ///
  /// When the candidate references a real duplicate entity row
  /// (`entityId` exists in the store), the merge is a true consolidation:
  /// [StoryMemoryRepository.mergeEntities] absorbs the row — aliases and
  /// mention counts combine, relationships re-point, and the duplicate
  /// disappears from every rendered entity list. When the candidate is
  /// name-only (provisional alias candidate with no persisted row), the
  /// legacy behavior applies: the name is added to the target's aliases.
  Future<Result<void>> mergeAlias(ReviewItem item) async {
    if (item.targetEntityId == null) {
      return const Failure(ValidationException('Target entity is required for alias merge'));
    }

    final targetRes = await _repository.getEntityById(item.targetEntityId!);
    if (targetRes is! Success<StoryEntity?> || targetRes.value == null) {
      return const Failure(DatabaseException('Target entity for alias merge was not found'));
    }
    final target = targetRes.value!;

    final absorbedRes = await _repository.getEntityById(item.entityId);
    if (absorbedRes is Success<StoryEntity?> && absorbedRes.value != null) {
      final absorbed = absorbedRes.value!;
      if (absorbed.id == target.id) {
        return const Failure(ValidationException('Cannot merge an entity into itself'));
      }
      // True consolidation: the duplicate row is absorbed into the target.
      final mergedRes = await _repository.mergeEntities(
        item.bookId,
        readThroughId: item.readThroughId,
        keepEntityId: target.id,
        absorbedEntityId: absorbed.id,
      );
      if (mergedRes is! Success<StoryEntity>) {
        return const Failure(DatabaseException('Failed to merge duplicate entity'));
      }
    } else {
      // Name-only alias candidate (no duplicate row persisted): add the
      // candidate name to the target's aliases so the next extraction
      // pass recognizes it as the same entity.
      final updatedAliases = {...target.aliases, item.candidateName}.toList();
      final updated = target.copyWith(
        aliases: updatedAliases,
        confidenceScore: (target.confidenceScore + 0.10).clamp(0.0, 1.0),
        updatedAt: DateTime.now(),
      );
      await _repository.saveEntity(updated);
    }

    await _repository.resolveReviewItem(item.id, ReviewStatus.resolved);

    await _correctionStore.recordDecision(
      id: '${item.bookId}:merge:${DateTime.now().millisecondsSinceEpoch}',
      pattern: item.candidateName,
      decision: CorrectionDecision.merge,
      entityType: StoryEntityType.character,
      bookId: item.bookId,
    );

    await loadPending();
    return const Success(null);
  }

  /// Rejects a candidate entity, dismissing the review item and saving a negative rule.
  Future<Result<void>> rejectCandidate(ReviewItem item) async {
    await _repository.resolveReviewItem(item.id, ReviewStatus.dismissed);

    // If entity was already created, delete it
    if (!item.entityId.startsWith('prov_')) {
      await _repository.deleteEntity(item.entityId);
    }

    await _correctionStore.recordDecision(
      id: '${item.bookId}:rej:${DateTime.now().millisecondsSinceEpoch}',
      pattern: item.candidateName,
      decision: CorrectionDecision.reject,
      entityType: StoryEntityType.character,
      bookId: item.bookId,
    );

    await loadPending();
    return const Success(null);
  }
}

