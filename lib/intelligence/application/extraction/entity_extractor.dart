import 'dart:isolate';
import 'dart:math' as math;
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/corrections/correction_rule_engine.dart';
import 'package:atlas_app/intelligence/application/extraction/character_extractor.dart';
import 'package:atlas_app/intelligence/application/extraction/confidence_scorer.dart';
import 'package:atlas_app/intelligence/application/extraction/faction_extractor.dart';
import 'package:atlas_app/intelligence/application/extraction/item_extractor.dart';
import 'package:atlas_app/intelligence/application/extraction/location_extractor.dart';
import 'package:atlas_app/intelligence/application/extraction/relationship_deriver.dart';
import 'package:atlas_app/intelligence/application/graph/cooccurrence_graph.dart';
import 'package:atlas_app/intelligence/application/graph/graph_clusterer.dart';
import 'package:atlas_app/intelligence/domain/entities/confidence.dart';
import 'package:atlas_app/intelligence/domain/entities/correction_record.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/domain/entities/story_cooccurrence.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/infrastructure/parsing/transliteration_matcher.dart';

/// Summary of what was recognized and updated during a chapter extraction pass.
class ChapterExtractionSummary {
  const ChapterExtractionSummary({
    required this.chapterIndex,
    required this.newEntitiesCount,
    required this.updatedEntitiesCount,
    required this.reviewItemsCount,
    required this.relationshipsCount,
    required this.eventsCount,
  });

  final int chapterIndex;
  final int newEntitiesCount;
  final int updatedEntitiesCount;
  final int reviewItemsCount;
  final int relationshipsCount;
  final int eventsCount;
}

/// Raw extraction DTO produced inside background isolates.
class _RawExtractionPayload {
  const _RawExtractionPayload({
    required this.characterNames,
    required this.characterSignals,
    required this.characterEvidence,
    required this.locationNames,
    required this.locationEvidence,
    required this.factionNames,
    required this.factionEvidence,
    required this.itemNames,
    required this.itemEvidence,
  });

  final List<String> characterNames;
  final Map<String, List<String>> characterSignals;
  final Map<String, List<String>> characterEvidence;

  final List<String> locationNames;
  final Map<String, List<String>> locationEvidence;

  final List<String> factionNames;
  final Map<String, List<String>> factionEvidence;

  final List<String> itemNames;
  final Map<String, List<String>> itemEvidence;
}

/// Orchestrates zero-AI chapter extraction, confidence scoring, co-occurrence,
/// and review queue population.
class EntityExtractor {
  EntityExtractor({
    required StoryMemoryRepository repository,
    CorrectionRuleEngine? correctionEngine,
    ConfidenceScorer? scorer,
    CharacterExtractor? characterExtractor,
    LocationExtractor? locationExtractor,
    FactionExtractor? factionExtractor,
    ItemExtractor? itemExtractor,
    GraphClusterer? clusterer,
    TransliterationMatcher? matcher,
  })  : _repository = repository,
        _correctionEngine = correctionEngine,
        _scorer = scorer ?? const ConfidenceScorer(),
        _characterExtractor = characterExtractor ?? CharacterExtractor(),
        _locationExtractor = locationExtractor ?? LocationExtractor(),
        _factionExtractor = factionExtractor ?? FactionExtractor(),
        _itemExtractor = itemExtractor ?? ItemExtractor(),
        _clusterer = clusterer ?? const GraphClusterer(),
        _matcher = matcher ?? const TransliterationMatcher();

  static int _idSeq = 0;
  static String generateEntityId(String bookId, String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '$bookId:ent:${slug}_${DateTime.now().microsecondsSinceEpoch}_${++_idSeq}';
  }

  static String generateReviewId(String bookId, String prefix) {
    return '$bookId:$prefix:${DateTime.now().microsecondsSinceEpoch}_${++_idSeq}';
  }

  final StoryMemoryRepository _repository;
  final CorrectionRuleEngine? _correctionEngine;
  final ConfidenceScorer _scorer;
  final CharacterExtractor _characterExtractor;
  final LocationExtractor _locationExtractor;
  final FactionExtractor _factionExtractor;
  final ItemExtractor _itemExtractor;
  final GraphClusterer _clusterer;
  final TransliterationMatcher _matcher;

  /// Runs extraction on [chapterText], executing the heavy text scanning inside
  /// a background isolate to protect the main Flutter UI thread from frame drops.
  Future<Result<ChapterExtractionSummary>> processChapter({
    required String bookId,
    String readThroughId = 'default',
    required int chapterIndex,
    required String chapterText,
    bool runInIsolate = true,
  }) async {
    try {
      if (chapterText.trim().isEmpty) {
        return Success(
          ChapterExtractionSummary(
            chapterIndex: chapterIndex,
            newEntitiesCount: 0,
            updatedEntitiesCount: 0,
            reviewItemsCount: 0,
            relationshipsCount: 0,
            eventsCount: 0,
          ),
        );
      }

      // 1. Run regex tokenization and pattern matching in background isolate.
      // Some restricted runtimes (e.g. the flutter_test VM or sandboxed
      // embedders) cannot spawn isolates — degrade to inline scanning in
      // that case instead of failing the whole chapter extraction.
      _RawExtractionPayload payload;
      if (runInIsolate) {
        try {
          payload = await Isolate.run(() => _scanChapterText(chapterText));
        } catch (_) {
          payload = _buildPayload(
            _characterExtractor.extract(chapterText),
            _locationExtractor.extract(chapterText),
            _factionExtractor.extract(chapterText),
            _itemExtractor.extract(chapterText),
          );
        }
      } else {
        payload = _buildPayload(
          _characterExtractor.extract(chapterText),
          _locationExtractor.extract(chapterText),
          _factionExtractor.extract(chapterText),
          _itemExtractor.extract(chapterText),
        );
      }

      final existingEntitiesRes = await _repository.getEntities(
        bookId,
        readThroughId: readThroughId,
      );
      final existingEntities = existingEntitiesRes is Success<List<StoryEntity>>
          ? existingEntitiesRes.value
          : <StoryEntity>[];

      // One round trip each instead of one per candidate: pending review
      // dedup keys (in-memory duplicate guard) and the correction-rule set
      // the confidence engine scores candidates against.
      final correctionsFuture = _correctionEngine != null
          ? _correctionEngine.loadCorrectionsForBook(bookId)
          : Future.value(const <CorrectionRecord>[]);
      final pendingKeysRes = await _repository.pendingReviewItemKeys(
        bookId: bookId,
        readThroughId: readThroughId,
      );
      final pendingReviewKeys = pendingKeysRes is Success<Set<String>>
          ? pendingKeysRes.value
          : <String>{};
      final corrections = await correctionsFuture;

      // Cheap-metric index over the existing entities: normalized name
      // length + Soundex code, bucketed per type. A candidate only runs the
      // (expensive) full transliteration similarity against entities that
      // pass this superset prefilter — phonetic match, plausible edit-distance
      // length band, or subset/prefix similarity — so the fuzzy scan stays
      // proportional to the plausible bucket instead of the whole library.
      final fuzzyIndex = <String, List<_FuzzyIndexEntry>>{};
      for (final e in existingEntities) {
        final norm = _matcher.normalizeName(e.canonicalName);
        (fuzzyIndex[e.type.id] ??= []).add(_FuzzyIndexEntry(
          entity: e,
          norm: norm,
          length: norm.length,
          soundex: _matcher.soundexCode(e.canonicalName),
        ));
      }

      StoryEntity? findFuzzyAliasMatch(StoryEntityType type, String name) {
        final candidates = fuzzyIndex[type.id];
        if (candidates == null) return null;
        final norm = _matcher.normalizeName(name);
        final soundex = _matcher.soundexCode(name);
        final len = norm.length;
        for (final entry in candidates) {
          final sameSoundex = soundex.isNotEmpty && soundex == entry.soundex;
          final lenDelta = (len - entry.length).abs().toDouble();
          // Levenshtein similarity >= 0.75 implies edit distance <= 0.25 *
          // maxLen, which bounds |lenA - lenB|. +1 slack for rounding.
          final plausibleBand = lenDelta <= 0.25 * math.max(len, entry.length) + 1;
          final subsetPlausible = len > 2 &&
              entry.length > 2 &&
              (norm.contains(entry.norm) || entry.norm.contains(norm));
          if (!sameSoundex && !plausibleBand && !subsetPlausible) continue;
          if (_matcher.isPotentialAlias(entry.entity.canonicalName, name)) {
            return entry.entity;
          }
        }
        return null;
      }

      final knownEntityMap = <String, StoryEntity>{};
      for (final e in existingEntities) {
        knownEntityMap[e.canonicalName.toLowerCase()] = e;
        for (final a in e.aliases) {
          knownEntityMap[a.toLowerCase()] = e;
        }
      }

      final thresholdConfigs = ConfidenceThresholdConfig.defaults;
      final presentEntitiesThisChapter = <StoryEntity>[];
      // Entities are collected here and flushed in ONE batch write after all
      // candidate types are processed — saves per-entity transactions.
      final entitiesToPersist = <StoryEntity>[];
      final reviewItemsToPersist = <ReviewItem>[];
      int newCount = 0;
      int updatedCount = 0;
      int reviewCount = 0;

      /// Queues a review item, skipping duplicates already pending in the
      /// queue or produced earlier in this same pass.
      void queueReviewItem(ReviewItem item) {
        final key = '${item.type.id}|${item.entityId}|${item.candidateName}';
        if (pendingReviewKeys.contains(key)) return;
        pendingReviewKeys.add(key);
        reviewItemsToPersist.add(item);
        reviewCount++;
      }

      // Helper to process candidates of a given type
      Future<void> processCandidates({
        required List<String> names,
        required StoryEntityType type,
        required Map<String, List<String>> evidenceMap,
        required ExtractionSignalType primarySignal,
      }) async {
        final config = thresholdConfigs[type]!;

        for (final name in names) {
          final existing = knownEntityMap[name.toLowerCase()];

          if (existing != null) {
            // Corroborating mention -> Bayesian confidence update
            final updatedScore = _scorer.updateConfidence(
              currentScore: existing.confidenceScore,
              signalType: primarySignal,
              signalConfirms: true,
              mentionCount: existing.mentionCount + 1,
            );

            final updated = existing.copyWith(
              confidenceScore: updatedScore,
              tier: config.resolveTier(updatedScore),
              lastSeenChapter: chapterIndex,
              mentionCount: existing.mentionCount + 1,
              updatedAt: DateTime.now(),
            );

            entitiesToPersist.add(updated);
            presentEntitiesThisChapter.add(updated);
            knownEntityMap[name.toLowerCase()] = updated;
            updatedCount++;
          } else {
            // Check for transliteration fuzzy match against known entities
            final fuzzyMatch = findFuzzyAliasMatch(type, name);

            if (fuzzyMatch != null) {
              // Found fuzzy alias match -> queue for review as alias merge candidate
              final reviewItem = ReviewItem(
                id: generateReviewId(bookId, 'alias'),
                bookId: bookId,
                readThroughId: readThroughId,
                type: ReviewType.mergeCandidates,
                entityId: fuzzyMatch.id,
                candidateName: name,
                targetName: fuzzyMatch.canonicalName,
                confidenceScore: 0.65,
                similarityScore: _matcher.similarity(fuzzyMatch.canonicalName, name),
                evidence: ['Phonetic alias match for existing entity: "${fuzzyMatch.canonicalName}"'],
                chapterIndex: chapterIndex,
                createdAt: DateTime.now(),
              );
              queueReviewItem(reviewItem);
            } else {
              // Newly discovered candidate
              var initialConfidence = _scorer.initialScore(
                primarySignal: primarySignal,
                hasSecondarySignal: (evidenceMap[name]?.length ?? 0) > 1,
              );

              // Apply active learning correction rule adjustment if available.
              // Rules were prefetched once for the whole chapter pass.
              final delta = _correctionEngine?.adjustmentFor(corrections, name, type) ?? 0.0;
              initialConfidence = (initialConfidence + delta).clamp(0.0, 1.0);

              final tier = config.resolveTier(initialConfidence);

              if (config.requiresReview(initialConfidence)) {
                // Low confidence -> queue for user review before creating entity
                final reviewItem = ReviewItem(
                  id: generateReviewId(bookId, 'new'),
                  bookId: bookId,
                  readThroughId: readThroughId,
                  type: ReviewType.newEntity,
                  entityId: 'prov_$name',
                  candidateName: name,
                  confidenceScore: initialConfidence,
                  evidence: evidenceMap[name] ?? [],
                  chapterIndex: chapterIndex,
                  createdAt: DateTime.now(),
                );
                queueReviewItem(reviewItem);
              } else {
                // High/Medium auto-accepted -> create entity
                final newEntity = StoryEntity(
                  id: generateEntityId(bookId, name),
                  bookId: bookId,
                  readThroughId: readThroughId,
                  type: type,
                  canonicalName: name,
                  aliases: const [],
                  confidenceScore: initialConfidence,
                  tier: tier,
                  userConfirmed: false,
                  firstSeenChapter: chapterIndex,
                  lastSeenChapter: chapterIndex,
                  mentionCount: 1,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                entitiesToPersist.add(newEntity);
                presentEntitiesThisChapter.add(newEntity);
                knownEntityMap[name.toLowerCase()] = newEntity;
                newCount++;
              }
            }
          }
        }
      }

      // Process characters, locations, factions, and items
      await processCandidates(
        names: payload.characterNames,
        type: StoryEntityType.character,
        evidenceMap: payload.characterEvidence,
        primarySignal: ExtractionSignalType.dialogueTag,
      );

      await processCandidates(
        names: payload.locationNames,
        type: StoryEntityType.location,
        evidenceMap: payload.locationEvidence,
        primarySignal: ExtractionSignalType.structuredPattern,
      );

      await processCandidates(
        names: payload.factionNames,
        type: StoryEntityType.faction,
        evidenceMap: payload.factionEvidence,
        primarySignal: ExtractionSignalType.structuredPattern,
      );

      await processCandidates(
        names: payload.itemNames,
        type: StoryEntityType.item,
        evidenceMap: payload.itemEvidence,
        primarySignal: ExtractionSignalType.structuredPattern,
      );

      // Flush collected writes in a single batched pass before the
      // co-occurrence/relationship derivation steps.
      if (entitiesToPersist.isNotEmpty) {
        await _repository.saveEntities(entitiesToPersist);
      }
      await _repository.saveReviewItems(reviewItemsToPersist);

      // 2. Update co-occurrence graph. The graph is SEEDED from the persisted
      // story_cooccurrences for the entities present in this chapter — it
      // used to start empty every pass, which (a) made each recovered pair
      // weigh 1 so the "co-occur ≥ 2 → distinct" gate never blocked and the
      // main-isolate clusterer ran full similarity on every same-type pair,
      // and (b) re-proposed merges for long-co-occurring distinct characters.
      final presentIds = presentEntitiesThisChapter.map((e) => e.id).toSet();
      if (presentIds.length >= 2) {
        final persistedRes = await _repository.getCooccurrencesForEntities(
          bookId,
          presentIds,
          readThroughId: readThroughId,
        );
        final persistedEdges = persistedRes is Success<List<StoryCooccurrence>>
            ? persistedRes.value
            : const <StoryCooccurrence>[];

        final graph = CooccurrenceGraph(persistedEdges);
        final edges = graph.recordCooccurrences(
          bookId: bookId,
          readThroughId: readThroughId,
          entityIds: presentIds.toList(),
          chapterIndex: chapterIndex,
        );
        if (edges.isNotEmpty) {
          await _repository.updateCooccurrences(bookId, edges, readThroughId: readThroughId);

          // Clustering runs the O(pairs) transliteration similarity scan, so
          // it goes through the same isolate route as the text scan — kept
          // off the UI thread like [_deriveInsights].
          List<MergeProposal> proposals;
          if (runInIsolate) {
            try {
              proposals = await Isolate.run(
                () => GraphClusterer.findMergeCandidatesFromEdges(
                  entities: presentEntitiesThisChapter,
                  bookId: bookId,
                  persistedEdges: persistedEdges,
                ),
              );
            } catch (_) {
              // Restricted runtimes: fall through to the inline pass.
              proposals = _clusterer.findMergeCandidates(
                entities: presentEntitiesThisChapter,
                graph: graph,
                bookId: bookId,
              );
            }
          } else {
            proposals = _clusterer.findMergeCandidates(
              entities: presentEntitiesThisChapter,
              graph: graph,
              bookId: bookId,
            );
          }
          for (final p in proposals) {
            if (!p.shouldAutoMerge) {
              final reviewItem = ReviewItem(
                id: generateReviewId(bookId, 'cluster'),
                bookId: bookId,
                readThroughId: readThroughId,
                type: ReviewType.mergeCandidates,
                entityId: p.absorbedEntity.id,
                targetEntityId: p.keepEntity.id,
                candidateName: p.absorbedEntity.canonicalName,
                targetName: p.keepEntity.canonicalName,
                confidenceScore: 0.70,
                similarityScore: p.similarityScore,
                evidence: p.evidence,
                chapterIndex: chapterIndex,
                createdAt: DateTime.now(),
              );
              queueReviewItem(reviewItem);
            }
          }
        }
      }

      // 3. Derive relationships and events — the same O(sentences × pair)
      // sentence scans as the extraction pass, so they run in a background
      // isolate when the runtime allows, keeping the UI isolate light.
      final insights = await _deriveInsights(
        chapterText: chapterText,
        chapterIndex: chapterIndex,
        bookId: bookId,
        readThroughId: readThroughId,
        presentEntities: presentEntitiesThisChapter,
        runInIsolate: runInIsolate,
      );
      final derivedRelationships = insights.$1;
      final derivedEvents = insights.$2;
      if (derivedRelationships.isNotEmpty) {
        await _repository.saveRelationships(derivedRelationships);
      }

      if (derivedEvents.isNotEmpty) {
        await _repository.saveEvents(derivedEvents);
      }

      return Success(
        ChapterExtractionSummary(
          chapterIndex: chapterIndex,
          newEntitiesCount: newCount,
          updatedEntitiesCount: updatedCount,
          reviewItemsCount: reviewCount,
          relationshipsCount: derivedRelationships.length,
          eventsCount: derivedEvents.length,
        ),
      );
    } catch (e, st) {
      return Failure(DatabaseException('Chapter extraction failed', e), st);
    }
  }

  static _RawExtractionPayload _buildPayload(
    List<CharacterCandidate> chars,
    List<LocationCandidate> locs,
    List<FactionCandidate> facts,
    List<ItemCandidate> items,
  ) {
    return _RawExtractionPayload(
      characterNames: chars.map((c) => c.name).toList(),
      characterSignals: {
        for (final c in chars) c.name: c.signals.map((s) => s.name).toList(),
      },
      characterEvidence: {for (final c in chars) c.name: c.evidence},
      locationNames: locs.map((l) => l.name).toList(),
      locationEvidence: {for (final l in locs) l.name: l.evidence},
      factionNames: facts.map((f) => f.name).toList(),
      factionEvidence: {for (final f in facts) f.name: f.evidence},
      itemNames: items.map((i) => i.name).toList(),
      itemEvidence: {for (final i in items) i.name: i.evidence},
    );
  }

  /// Pure relationship/event derivation shared by the isolate and inline
  /// path. Executed inside [Isolate.run] when the runtime allows, so the
  /// O(sentences × entity-pair) scans stay off the UI thread.
  static (List<StoryRelationship>, List<StoryEvent>) deriveInsightsSync({
    required String chapterText,
    required int chapterIndex,
    required String bookId,
    required String readThroughId,
    required List<StoryEntity> presentEntities,
  }) {
    const deriver = RelationshipDeriver();
    final relationships = deriver.deriveRelationships(
      chapterText: chapterText,
      chapterIndex: chapterIndex,
      presentEntities: presentEntities,
      readThroughId: readThroughId,
    );
    final events = deriver.deriveEvents(
      chapterText: chapterText,
      chapterIndex: chapterIndex,
      bookId: bookId,
      readThroughId: readThroughId,
      presentEntities: presentEntities,
    );
    return (relationships, events);
  }

  /// Top-level pure function executed inside Isolate.run.
  static _RawExtractionPayload _scanChapterText(String text) {
    final charExtractor = CharacterExtractor();
    final locExtractor = LocationExtractor();
    final factExtractor = FactionExtractor();
    final itemExtractor = ItemExtractor();

    return _buildPayload(
      charExtractor.extract(text),
      locExtractor.extract(text),
      factExtractor.extract(text),
      itemExtractor.extract(text),
    );
  }

  /// Derives relationships and events for the chapter — inline shortcut.
  ///
  /// The sentence scans these two functions perform (sentence split once,
  /// entity-pair containment checks) are meaningful work on long chapters,
  /// so [processChapter] routes this through [Isolate.run] like the raw text
  /// scan, keeping the UI isolate free.
  Future<(List<StoryRelationship>, List<StoryEvent>)> _deriveInsights({
    required String chapterText,
    required int chapterIndex,
    required String bookId,
    required String readThroughId,
    required List<StoryEntity> presentEntities,
    required bool runInIsolate,
  }) async {
    if (presentEntities.isEmpty) {
      return (const <StoryRelationship>[], const <StoryEvent>[]);
    }
    if (runInIsolate) {
      try {
        return await Isolate.run(
          () => EntityExtractor.deriveInsightsSync(
            chapterText: chapterText,
            chapterIndex: chapterIndex,
            bookId: bookId,
            readThroughId: readThroughId,
            presentEntities: presentEntities,
          ),
        );
      } catch (_) {
        // Restricted runtimes: fall through to the inline pass.
      }
    }
    return EntityExtractor.deriveInsightsSync(
      chapterText: chapterText,
      chapterIndex: chapterIndex,
      bookId: bookId,
      readThroughId: readThroughId,
      presentEntities: presentEntities,
    );
  }
}

/// Entry of the per-chapter fuzzy prefilter: cheap metrics over one existing
/// entity so full transliteration similarity only runs on plausible matches.
class _FuzzyIndexEntry {
  const _FuzzyIndexEntry({
    required this.entity,
    required this.norm,
    required this.length,
    required this.soundex,
  });

  final StoryEntity entity;
  final String norm;
  final int length;
  final String soundex;
}
