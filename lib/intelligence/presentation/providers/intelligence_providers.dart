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
import 'package:atlas_app/intelligence/application/ingestion/story_backfill_service.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_memory_ingestion_service.dart';
import 'package:atlas_app/intelligence/application/graph/entity_consolidation_service.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/domain/repositories/correction_repository.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/ai_credentials_store.dart';
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

/// Secure (DPAPI/Keychain/Keystore) storage for BYOK API keys, replacing the
/// legacy plaintext SharedPreferences keys which it migrates on first load.
final aiCredentialsStoreProvider = Provider<AiCredentialsStore>((ref) {
  return SecureAiCredentialsStore();
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

/// Whole-book story-memory entity deduplication sweep (see
/// [EntityConsolidationService]). Fire-and-forget from the details-page
/// open path; self-guards against overlapping runs per book.
final entityConsolidationServiceProvider = Provider<EntityConsolidationService>((ref) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return EntityConsolidationService(repository: repo);
});

/// Pipe that turns displayed chapter text into story memory. Idempotent per
/// (book, read-through, chapter, content hash) — safe to call on every open.
final storyMemoryIngestionServiceProvider = Provider<StoryMemoryIngestionService>((ref) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  final extractor = ref.watch(entityExtractorProvider);
  return StoryMemoryIngestionService(repository: repo, extractor: extractor);
});

/// Live story-memory build progress for one book, driven by
/// [StoryBackfillService.onProgress]. Null while no run has reported yet.
final storyBackfillProgressProvider =
    StateProvider.autoDispose.family<StoryBackfillProgress?, String>(
  (ref, bookId) => null,
);

/// State of the persisted story-recap: text + whether a background
/// recompute is still polishing it (the UI keeps showing stale text).
class RecapSnapshotState {
  const RecapSnapshotState({this.text, this.recomputing = false});

  final String? text;
  final bool recomputing;
}

final queryEngineProvider = Provider<QueryEngine>((ref) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return QueryEngine(repository: repo);
});

/// Spoiler-free recap backed by the persisted `story_recap_snapshots` cache.
///
/// First render: instantly shows any cached snapshot, then recomputes quietly
/// and swaps only when the new recap differs — the detail page no longer
/// flashes "Gathering the story so far…" or re-runs the timeline query on
/// every open.
final recapSnapshotProvider = StateNotifierProvider.autoDispose.family<RecapSnapshotController,
    RecapSnapshotState, ({String bookId, String readThroughId, int chapter})>((
  ref,
  key,
) {
  final controller = RecapSnapshotController(
    repository: ref.watch(storyMemoryRepositoryProvider),
    queryEngine: ref.watch(queryEngineProvider),
  );
  controller.load(key);
  return controller;
});

class RecapSnapshotController extends StateNotifier<RecapSnapshotState> {
  RecapSnapshotController({
    required StoryMemoryRepository repository,
    required QueryEngine queryEngine,
  })  : _repository = repository,
        _queryEngine = queryEngine,
        super(const RecapSnapshotState());

  final StoryMemoryRepository _repository;
  final QueryEngine _queryEngine;

  int _generation = 0;

  Future<void> load(({String bookId, String readThroughId, int chapter}) key) async {
    final generation = ++_generation;

    // 1. Instant paint from the persisted snapshot.
    final snapshotRes = await _repository.getRecapSnapshot(
      bookId: key.bookId,
      readThroughId: key.readThroughId,
      chapterIndex: key.chapter,
    );
    if (generation != _generation) return;
    if (snapshotRes is Success<String?> && snapshotRes.value != null) {
      state = RecapSnapshotState(text: snapshotRes.value, recomputing: true);
    } else {
      state = const RecapSnapshotState(recomputing: true);
    }

    // 2. Fresh recompute from story memory; only swaps in on change.
    try {
      final text = await _queryEngine.executeQuery(
        bookId: key.bookId,
        readThroughId: key.readThroughId,
        query: 'recap',
        readerChapter: key.chapter,
      );
      if (generation != _generation) return;
      final isEscalationFallback = text.isEmpty;
      if (isEscalationFallback) {
        if (state.text == null) {
          state = const RecapSnapshotState(text: '', recomputing: false);
        }
        return;
      }
      if (text != state.text) {
        state = RecapSnapshotState(text: text, recomputing: false);
        await _repository.saveRecapSnapshot(
          bookId: key.bookId,
          readThroughId: key.readThroughId,
          chapterIndex: key.chapter,
          recapText: text,
        );
      } else {
        state = RecapSnapshotState(text: state.text, recomputing: false);
      }
    } catch (_) {
      if (generation != _generation) return;
      state = RecapSnapshotState(text: state.text, recomputing: false);
    }
  }
}

final reviewQueueControllerProvider =
    StateNotifierProvider.autoDispose.family<ReviewQueueController, ReviewQueueState, String>(
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
    FutureProvider.autoDispose.family<List<ReadThrough>, String>((ref, bookId) async {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  final res = await repo.getReadThroughs(bookId);
  if (res is Success<List<ReadThrough>>) {
    return res.value;
  }
  return const [];
});

final activeReadThroughProvider =
    FutureProvider.autoDispose.family<ReadThrough, String>((ref, bookId) async {
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

final readThroughControllerProvider = StateNotifierProvider.autoDispose.family<
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
    StreamProvider.autoDispose.family<List<StoryEntity>, String>((ref, bookId) {
  final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
  final rtId = activeRt?.id ?? 'default';
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return repo.watchEntities(bookId, readThroughId: rtId);
});

final scopedStoryEntitiesStreamProvider = StreamProvider.autoDispose.family<
    List<StoryEntity>, ({String bookId, String readThroughId})>((ref, params) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return repo.watchEntities(params.bookId, readThroughId: params.readThroughId);
});

final storyRelationshipsProvider =
    FutureProvider.autoDispose.family<List<StoryRelationship>, ({String bookId, String? entityId})>(
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
    FutureProvider.autoDispose.family<List<StoryEvent>, ({String bookId, String? entityId, int? maxChapter})>(
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

