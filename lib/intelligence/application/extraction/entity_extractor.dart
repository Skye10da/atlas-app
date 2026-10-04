import 'dart:isolate';
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
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity_type.dart';
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
    RelationshipDeriver? relationshipDeriver,
    GraphClusterer? clusterer,
    TransliterationMatcher? matcher,
  })  : _repository = repository,
        _correctionEngine = correctionEngine,
        _scorer = scorer ?? const ConfidenceScorer(),
        _characterExtractor = characterExtractor ?? CharacterExtractor(),
        _locationExtractor = locationExtractor ?? LocationExtractor(),
        _factionExtractor = factionExtractor ?? FactionExtractor(),
        _itemExtractor = itemExtractor ?? ItemExtractor(),
        _relationshipDeriver = relationshipDeriver ?? const RelationshipDeriver(),
        _clusterer = clusterer ?? GraphClusterer(),
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
  final RelationshipDeriver _relationshipDeriver;
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

      // 1. Run regex tokenization and pattern matching in background isolate
      final _RawExtractionPayload payload;
      if (runInIsolate) {
        payload = await Isolate.run(() => _scanChapterText(chapterText));
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

      final knownEntityMap = <String, StoryEntity>{};
      for (final e in existingEntities) {
        knownEntityMap[e.canonicalName.toLowerCase()] = e;
        for (final a in e.aliases) {
          knownEntityMap[a.toLowerCase()] = e;
        }
      }

      final thresholdConfigs = ConfidenceThresholdConfig.defaults;
      final presentEntitiesThisChapter = <StoryEntity>[];
      int newCount = 0;
      int updatedCount = 0;
      int reviewCount = 0;

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

            await _repository.saveEntity(updated);
            presentEntitiesThisChapter.add(updated);
            knownEntityMap[name.toLowerCase()] = updated;
            updatedCount++;
          } else {
            // Check for transliteration fuzzy match against known entities
            StoryEntity? fuzzyMatch;
            for (final e in existingEntities) {
              if (e.type == type && _matcher.isPotentialAlias(e.canonicalName, name)) {
                fuzzyMatch = e;
                break;
              }
            }

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
              await _repository.saveReviewItem(reviewItem);
              reviewCount++;
            } else {
              // Newly discovered candidate
              var initialConfidence = _scorer.initialScore(
                primarySignal: primarySignal,
                hasSecondarySignal: (evidenceMap[name]?.length ?? 0) > 1,
              );

              // Apply active learning correction rule adjustment if available
              if (_correctionEngine != null) {
                final delta = await _correctionEngine.evaluateConfidenceAdjustment(
                  bookId: bookId,
                  candidateName: name,
                  type: type,
                );
                initialConfidence = (initialConfidence + delta).clamp(0.0, 1.0);
              }

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
                await _repository.saveReviewItem(reviewItem);
                reviewCount++;
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

                await _repository.saveEntity(newEntity);
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

      // 2. Update co-occurrence graph
      final presentIds = presentEntitiesThisChapter.map((e) => e.id).toSet().toList();
      final graph = CooccurrenceGraph();
      final edges = graph.recordCooccurrences(
        bookId: bookId,
        readThroughId: readThroughId,
        entityIds: presentIds,
        chapterIndex: chapterIndex,
      );
      if (edges.isNotEmpty) {
        await _repository.updateCooccurrences(bookId, edges, readThroughId: readThroughId);

        final proposals = _clusterer.findMergeCandidates(
          entities: presentEntitiesThisChapter,
          graph: graph,
          bookId: bookId,
        );
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
            await _repository.saveReviewItem(reviewItem);
            reviewCount++;
          }
        }
      }

      // 3. Derive relationships and events
      final derivedRelationships = _relationshipDeriver.deriveRelationships(
        chapterText: chapterText,
        chapterIndex: chapterIndex,
        presentEntities: presentEntitiesThisChapter,
        readThroughId: readThroughId,
      );
      if (derivedRelationships.isNotEmpty) {
        await _repository.saveRelationships(derivedRelationships);
      }

      final derivedEvents = _relationshipDeriver.deriveEvents(
        chapterText: chapterText,
        chapterIndex: chapterIndex,
        bookId: bookId,
        readThroughId: readThroughId,
        presentEntities: presentEntitiesThisChapter,
      );
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
}
