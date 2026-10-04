import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/corrections/correction_store.dart';
import 'package:atlas_app/intelligence/domain/entities/read_through.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/application/corrections/correction_rule_engine.dart';
import 'package:atlas_app/intelligence/application/extraction/confidence_scorer.dart';
import 'package:atlas_app/intelligence/application/extraction/entity_extractor.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_correction_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/drift_story_memory_repository.dart';
import 'package:atlas_app/intelligence/presentation/review_queue/review_queue_controller.dart';

final storyMemoryRepositoryProvider = Provider<StoryMemoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftStoryMemoryRepository(db: db);
});

final correctionRepositoryProvider = Provider<CorrectionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftCorrectionRepository(db: db);
});

final correctionStoreProvider = Provider<CorrectionStore>((ref) {
  final repo = ref.watch(correctionRepositoryProvider);
  return CorrectionStore(repository: repo);
});

final entityExtractorProvider = Provider<EntityExtractor>((ref) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  final correctionRepo = ref.watch(correctionRepositoryProvider);
  return EntityExtractor(
    repository: repo,
    correctionEngine: CorrectionRuleEngine(repository: correctionRepo),
    scorer: const ConfidenceScorer(),
  );
});

final reviewQueueControllerProvider =
    StateNotifierProvider.family<ReviewQueueController, ReviewQueueState, String>(
  (ref, bookId) {
    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final rtId = activeRt?.id ?? 'default';
    return ReviewQueueController(
      bookId: bookId,
      readThroughId: rtId,
      repository: ref.watch(storyMemoryRepositoryProvider),
      correctionStore: ref.watch(correctionStoreProvider),
    );
  },
);

final readThroughsProvider =
    FutureProvider.family<List<ReadThrough>, String>((ref, bookId) async {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  final res = await repo.getReadThroughs(bookId);
  if (res is Success<List<ReadThrough>>) {
    return res.value;
  }
  return const [];
});

final activeReadThroughProvider =
    FutureProvider.family<ReadThrough, String>((ref, bookId) async {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  final res = await repo.getActiveReadThrough(bookId);
  if (res is Success<ReadThrough>) {
    return res.value;
  }
  return ReadThrough(
    id: 'default',
    bookId: bookId,
    name: 'Primary Read',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

class ReadThroughController
    extends StateNotifier<AsyncValue<List<ReadThrough>>> {
  ReadThroughController({
    required this.bookId,
    required this.repository,
    required this.ref,
  }) : super(const AsyncValue.loading()) {
    refresh();
  }

  final String bookId;
  final StoryMemoryRepository repository;
  final Ref ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final res = await repository.getReadThroughs(bookId);
    if (res is Success<List<ReadThrough>>) {
      state = AsyncValue.data(res.value);
    } else if (res is Failure<List<ReadThrough>>) {
      state = AsyncValue.error(res.error, StackTrace.current);
    }
  }

  Future<bool> switchActive(String readThroughId) async {
    final res = await repository.setActiveReadThrough(bookId, readThroughId);
    if (res is Success) {
      await refresh();
      ref.invalidate(activeReadThroughProvider(bookId));
      ref.invalidate(readThroughsProvider(bookId));
      ref.invalidate(storyEntitiesStreamProvider(bookId));
      ref.invalidate(reviewQueueControllerProvider(bookId));
      return true;
    }
    return false;
  }

  Future<ReadThrough?> createNew({
    required String name,
    bool copyFromDefault = false,
  }) async {
    final res = await repository.createReadThrough(
      bookId,
      name: name,
      copyFromDefault: copyFromDefault,
    );
    if (res is Success<ReadThrough>) {
      await refresh();
      ref.invalidate(activeReadThroughProvider(bookId));
      ref.invalidate(readThroughsProvider(bookId));
      ref.invalidate(storyEntitiesStreamProvider(bookId));
      ref.invalidate(reviewQueueControllerProvider(bookId));
      return res.value;
    }
    return null;
  }

  Future<bool> delete(String readThroughId) async {
    final res = await repository.deleteReadThrough(bookId, readThroughId);
    if (res is Success) {
      await refresh();
      ref.invalidate(activeReadThroughProvider(bookId));
      ref.invalidate(readThroughsProvider(bookId));
      ref.invalidate(storyEntitiesStreamProvider(bookId));
      ref.invalidate(reviewQueueControllerProvider(bookId));
      return true;
    }
    return false;
  }
}

final readThroughControllerProvider = StateNotifierProvider.family<
    ReadThroughController, AsyncValue<List<ReadThrough>>, String>(
  (ref, bookId) {
    return ReadThroughController(
      bookId: bookId,
      repository: ref.watch(storyMemoryRepositoryProvider),
      ref: ref,
    );
  },
);

final storyEntitiesStreamProvider =
    StreamProvider.family<List<StoryEntity>, String>((ref, bookId) {
  final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
  final rtId = activeRt?.id ?? 'default';
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return repo.watchEntities(bookId, readThroughId: rtId);
});

final scopedStoryEntitiesStreamProvider = StreamProvider.family<
    List<StoryEntity>, ({String bookId, String readThroughId})>((ref, params) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return repo.watchEntities(params.bookId, readThroughId: params.readThroughId);
});

final storyRelationshipsProvider =
    FutureProvider.family<List<StoryRelationship>, ({String bookId, String? entityId})>(
  (ref, params) async {
    final repo = ref.watch(storyMemoryRepositoryProvider);
    final res = await repo.getRelationships(params.bookId, entityId: params.entityId);
    if (res is Success<List<StoryRelationship>>) {
      return res.value;
    }
    return const [];
  },
);

final storyEventsProvider =
    FutureProvider.family<List<StoryEvent>, ({String bookId, String? entityId, int? maxChapter})>(
  (ref, params) async {
    final repo = ref.watch(storyMemoryRepositoryProvider);
    final res = await repo.getEvents(
      params.bookId,
      maxChapter: params.maxChapter,
      involvedEntityIds: params.entityId != null ? [params.entityId!] : null,
    );
    if (res is Success<List<StoryEvent>>) {
      return res.value;
    }
    return const [];
  },
);

