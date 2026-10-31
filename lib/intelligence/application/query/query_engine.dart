import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/application/query/entity_slot_resolver.dart';
import 'package:atlas_app/intelligence/application/query/extractive_summarizer.dart';
import 'package:atlas_app/intelligence/application/query/intent_matcher.dart';
import 'package:atlas_app/intelligence/application/query/query_intent.dart';
import 'package:atlas_app/intelligence/application/query/response_templates.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';

typedef ChapterTextProvider = Future<String?> Function(String bookId, int chapterIndex);

/// How the offline engine classifies its own answer, consumed by the chat
/// layer to decide whether to escalate to the AI orchestrator.
///
/// This replaces the old fragile contract of sniffing response strings for
/// phrases like "couldn't find".
enum QueryAnswerKind {
  /// A deterministic, factual offline answer — no escalation needed.
  resolved,

  /// The engine could not answer from story memory (entity unknown, empty
  /// results, or unrecognized intent). Callers may escalate to the AI layer
  /// and use [QueryAnswer.text] as the final fallback.
  needsEscalation,
}

/// A Layer 2 answer together with its routing classification.
class QueryAnswer {
  const QueryAnswer(this.text, {required this.kind});

  final String text;
  final QueryAnswerKind kind;

  bool get isResolved => kind == QueryAnswerKind.resolved;
}

/// Layer 2 No-AI Query Engine.
///
/// Handles factual queries, character lookups, relationship inquiries,
/// and plot recaps 100% offline using deterministic heuristics and TF-IDF extraction.
class QueryEngine {
  QueryEngine({
    required StoryMemoryRepository repository,
    IntentMatcher? matcher,
    EntitySlotResolver? resolver,
    ExtractiveSummarizer? summarizer,
    ResponseTemplates? templates,
    ChapterTextProvider? chapterTextProvider,
  })  : _repository = repository,
        _matcher = matcher ?? const IntentMatcher(),
        _resolver = resolver ?? EntitySlotResolver(repository: repository),
        _summarizer = summarizer ?? const ExtractiveSummarizer(),
        _templates = templates ?? const ResponseTemplates(),
        _chapterTextProvider = chapterTextProvider;

  final StoryMemoryRepository _repository;
  final IntentMatcher _matcher;
  final EntitySlotResolver _resolver;
  final ExtractiveSummarizer _summarizer;
  final ResponseTemplates _templates;
  final ChapterTextProvider? _chapterTextProvider;

  /// Executes an offline user query and returns formatted markdown.
  ///
  /// Convenience wrapper over [executeQueryDetailed] for callers that only
  /// need the text (tests, generic fallback). New routing code should prefer
  /// the typed API so escalation decisions do not depend on string sniffing.
  Future<String> executeQuery({
    required String bookId,
    String readThroughId = 'default',
    required String query,
    int? readerChapter,
  }) async {
    final answer = await executeQueryDetailed(
      bookId: bookId,
      readThroughId: readThroughId,
      query: query,
      readerChapter: readerChapter,
    );
    return answer.text;
  }

  /// Typed variant of [executeQuery]: the answer carries its routing kind so
  /// the chat layer knows whether the response is genuinely resolved from
  /// story memory or merely an "I couldn't find this" answer.
  Future<QueryAnswer> executeQueryDetailed({
    required String bookId,
    String readThroughId = 'default',
    required String query,
    int? readerChapter,
  }) async {
    final match = _matcher.match(query);

    switch (match.intent) {
      case QueryIntentType.whoIs:
        return _handleWhoIs(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.relationship:
        return _handleRelationship(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.whereIs:
        return _handleWhereIs(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.whatHappened:
        return _handleWhatHappened(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.recap:
        return _handleRecap(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.sceneSearch:
        return _handleSceneSearch(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.unknown:
        return QueryAnswer(_templates.formatUnknown(query), kind: QueryAnswerKind.needsEscalation);
    }
  }

  Future<QueryAnswer> _handleWhoIs(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final slot = match.primarySlot;
    if (slot == null) {
      return QueryAnswer(_templates.formatUnknown(match.rawQuery), kind: QueryAnswerKind.needsEscalation);
    }

    final resolution = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: slot,
    );
    if (resolution.status == ResolutionStatus.notFound) {
      return QueryAnswer(_templates.formatNotFound(slot), kind: QueryAnswerKind.needsEscalation);
    } else if (resolution.status == ResolutionStatus.ambiguous) {
      // A disambiguation list is a complete, useful offline answer.
      return QueryAnswer(
        _templates.formatDisambiguation(query: slot, candidates: resolution.candidates),
        kind: QueryAnswerKind.resolved,
      );
    }

    final entity = resolution.entity!;

    // Fetch relationships established up to the reader's chapter (anti-spoiler).
    var relationships = <StoryRelationship>[];
    final relRes = await _repository.getRelationships(
      bookId,
      readThroughId: readThroughId,
      entityId: entity.id,
      maxChapter: readerChapter,
    );
    if (relRes is Success<List<StoryRelationship>>) {
      relationships = relRes.value;
    }

    // Fetch events up to reader chapter (anti-spoiler)
    var events = <StoryEvent>[];
    final evRes = await _repository.getEvents(
      bookId,
      readThroughId: readThroughId,
      maxChapter: readerChapter,
      involvedEntityIds: [entity.id],
    );
    if (evRes is Success<List<StoryEvent>>) {
      events = evRes.value;
    }

    return QueryAnswer(
      _templates.formatWhoIs(entity: entity, relationships: relationships, events: events),
      kind: QueryAnswerKind.resolved,
    );
  }

  Future<QueryAnswer> _handleRelationship(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    if (match.primarySlot == null || match.secondarySlot == null) {
      return QueryAnswer(_templates.formatUnknown(match.rawQuery), kind: QueryAnswerKind.needsEscalation);
    }

    final resA = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: match.primarySlot!,
    );
    if (resA.status != ResolutionStatus.resolved) {
      return resA.status == ResolutionStatus.ambiguous
          ? QueryAnswer(
              _templates.formatDisambiguation(query: match.primarySlot!, candidates: resA.candidates),
              kind: QueryAnswerKind.resolved,
            )
          : QueryAnswer(_templates.formatNotFound(match.primarySlot!), kind: QueryAnswerKind.needsEscalation);
    }

    final resB = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: match.secondarySlot!,
    );
    if (resB.status != ResolutionStatus.resolved) {
      return resB.status == ResolutionStatus.ambiguous
          ? QueryAnswer(
              _templates.formatDisambiguation(query: match.secondarySlot!, candidates: resB.candidates),
              kind: QueryAnswerKind.resolved,
            )
          : QueryAnswer(_templates.formatNotFound(match.secondarySlot!), kind: QueryAnswerKind.needsEscalation);
    }

    final entityA = resA.entity!;
    final entityB = resB.entity!;

    // Anti-spoiler: only relationships established up to the reader's chapter.
    final relsRes = await _repository.getRelationships(
      bookId,
      readThroughId: readThroughId,
      entityId: entityA.id,
      maxChapter: readerChapter,
    );
    StoryRelationship? matchedRel;
    if (relsRes is Success<List<StoryRelationship>>) {
      for (final r in relsRes.value) {
        if ((r.sourceEntityId == entityA.id && r.targetEntityId == entityB.id) ||
            (r.sourceEntityId == entityB.id && r.targetEntityId == entityA.id)) {
          matchedRel = r;
          break;
        }
      }
    }

    // "No direct relationship found" is still a factual offline answer.
    return QueryAnswer(
      _templates.formatRelationship(entityA: entityA, entityB: entityB, relationship: matchedRel),
      kind: QueryAnswerKind.resolved,
    );
  }

  Future<QueryAnswer> _handleWhereIs(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final slot = match.primarySlot;
    if (slot == null) {
      return QueryAnswer(_templates.formatUnknown(match.rawQuery), kind: QueryAnswerKind.needsEscalation);
    }

    final res = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: slot,
    );
    if (res.status != ResolutionStatus.resolved) {
      return res.status == ResolutionStatus.ambiguous
          ? QueryAnswer(
              _templates.formatDisambiguation(query: slot, candidates: res.candidates),
              kind: QueryAnswerKind.resolved,
            )
          : QueryAnswer(_templates.formatNotFound(slot), kind: QueryAnswerKind.needsEscalation);
    }

    final entity = res.entity!;
    var events = <StoryEvent>[];
    final evRes = await _repository.getEvents(
      bookId,
      readThroughId: readThroughId,
      maxChapter: readerChapter,
      involvedEntityIds: [entity.id],
    );
    if (evRes is Success<List<StoryEvent>>) {
      events = evRes.value;
    }

    return QueryAnswer(
      _templates.formatWhereIs(location: entity, events: events),
      kind: QueryAnswerKind.resolved,
    );
  }

  Future<QueryAnswer> _handleWhatHappened(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    // Specific chapter query
    if (match.chapterSlot != null) {
      final ch = match.chapterSlot!;
      var events = <StoryEvent>[];
      final evRes = await _repository.getEvents(
        bookId,
        readThroughId: readThroughId,
        chapterExact: ch,
      );
      if (evRes is Success<List<StoryEvent>>) {
        events = evRes.value;
      }

      String? extractive;
      if (_chapterTextProvider != null) {
        final text = await _chapterTextProvider(bookId, ch);
        if (text != null && text.isNotEmpty) {
          extractive = _summarizer.summarize(text);
        }
      }

      // Empty events AND no extractive text means the engine has nothing
      // grounded to say about that chapter — escalate instead.
      final hasContent = events.isNotEmpty || (extractive != null && extractive.isNotEmpty);
      return QueryAnswer(
        _templates.formatChapterSummary(chapter: ch, events: events, extractiveSummary: extractive),
        kind: hasContent ? QueryAnswerKind.resolved : QueryAnswerKind.needsEscalation,
      );
    }

    // Entity-centric what happened
    if (match.primarySlot != null) {
      return _handleWhoIs(bookId, match, readerChapter, readThroughId);
    }

    return _handleRecap(bookId, match, readerChapter, readThroughId);
  }

  Future<QueryAnswer> _handleRecap(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final targetChapter = match.chapterSlot ?? readerChapter ?? 999999;
    var events = <StoryEvent>[];
    final evRes = await _repository.getEvents(
      bookId,
      readThroughId: readThroughId,
      maxChapter: targetChapter,
    );
    if (evRes is Success<List<StoryEvent>>) {
      events = evRes.value;
    }

    return QueryAnswer(
      _templates.formatRecap(
        maxChapter: targetChapter == 999999 ? (events.isNotEmpty ? events.last.chapter : 1) : targetChapter,
        events: events,
      ),
      kind: events.isNotEmpty ? QueryAnswerKind.resolved : QueryAnswerKind.needsEscalation,
    );
  }

  Future<QueryAnswer> _handleSceneSearch(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final query = match.primarySlot ?? match.rawQuery;
    final ftsRes = await _repository.searchScenes(
      bookId,
      query,
      readThroughId: readThroughId,
      maxChapter: readerChapter,
    );

    if (ftsRes is Success<List<String>> && ftsRes.value.isNotEmpty) {
      final buffer = StringBuffer('### Matching Scenes:\n');
      for (final scene in ftsRes.value.take(3)) {
        buffer.writeln('• "$scene"\n');
      }
      return QueryAnswer(buffer.toString().trim(), kind: QueryAnswerKind.resolved);
    }

    return QueryAnswer(
      'No matching scenes found for "$query".',
      kind: QueryAnswerKind.needsEscalation,
    );
  }
}
