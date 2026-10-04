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
  Future<String> executeQuery({
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
        return _handleRelationship(bookId, match, readThroughId);

      case QueryIntentType.whereIs:
        return _handleWhereIs(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.whatHappened:
        return _handleWhatHappened(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.recap:
        return _handleRecap(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.sceneSearch:
        return _handleSceneSearch(bookId, match, readerChapter, readThroughId);

      case QueryIntentType.unknown:
        return _templates.formatUnknown(query);
    }
  }

  Future<String> _handleWhoIs(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final slot = match.primarySlot;
    if (slot == null) {
      return _templates.formatUnknown(match.rawQuery);
    }

    final resolution = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: slot,
    );
    if (resolution.status == ResolutionStatus.notFound) {
      return _templates.formatNotFound(slot);
    } else if (resolution.status == ResolutionStatus.ambiguous) {
      return _templates.formatDisambiguation(
        query: slot,
        candidates: resolution.candidates,
      );
    }

    final entity = resolution.entity!;

    // Fetch relationships
    var relationships = <StoryRelationship>[];
    final relRes = await _repository.getRelationships(
      bookId,
      readThroughId: readThroughId,
      entityId: entity.id,
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

    return _templates.formatWhoIs(
      entity: entity,
      relationships: relationships,
      events: events,
    );
  }

  Future<String> _handleRelationship(
    String bookId,
    QueryIntentMatch match,
    String readThroughId,
  ) async {
    if (match.primarySlot == null || match.secondarySlot == null) {
      return _templates.formatUnknown(match.rawQuery);
    }

    final resA = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: match.primarySlot!,
    );
    if (resA.status != ResolutionStatus.resolved) {
      return resA.status == ResolutionStatus.ambiguous
          ? _templates.formatDisambiguation(query: match.primarySlot!, candidates: resA.candidates)
          : _templates.formatNotFound(match.primarySlot!);
    }

    final resB = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: match.secondarySlot!,
    );
    if (resB.status != ResolutionStatus.resolved) {
      return resB.status == ResolutionStatus.ambiguous
          ? _templates.formatDisambiguation(query: match.secondarySlot!, candidates: resB.candidates)
          : _templates.formatNotFound(match.secondarySlot!);
    }

    final entityA = resA.entity!;
    final entityB = resB.entity!;

    final relsRes = await _repository.getRelationships(
      bookId,
      readThroughId: readThroughId,
      entityId: entityA.id,
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

    return _templates.formatRelationship(
      entityA: entityA,
      entityB: entityB,
      relationship: matchedRel,
    );
  }

  Future<String> _handleWhereIs(
    String bookId,
    QueryIntentMatch match,
    int? readerChapter,
    String readThroughId,
  ) async {
    final slot = match.primarySlot;
    if (slot == null) return _templates.formatUnknown(match.rawQuery);

    final res = await _resolver.resolve(
      bookId: bookId,
      readThroughId: readThroughId,
      slotText: slot,
    );
    if (res.status != ResolutionStatus.resolved) {
      return res.status == ResolutionStatus.ambiguous
          ? _templates.formatDisambiguation(query: slot, candidates: res.candidates)
          : _templates.formatNotFound(slot);
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

    return _templates.formatWhereIs(location: entity, events: events);
  }

  Future<String> _handleWhatHappened(
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
        maxChapter: ch,
      );
      if (evRes is Success<List<StoryEvent>>) {
        events = evRes.value.where((e) => e.chapter == ch).toList();
      }

      String? extractive;
      if (_chapterTextProvider != null) {
        final text = await _chapterTextProvider(bookId, ch);
        if (text != null && text.isNotEmpty) {
          extractive = _summarizer.summarize(text);
        }
      }

      return _templates.formatChapterSummary(
        chapter: ch,
        events: events,
        extractiveSummary: extractive,
      );
    }

    // Entity-centric what happened
    if (match.primarySlot != null) {
      return _handleWhoIs(bookId, match, readerChapter, readThroughId);
    }

    return _handleRecap(bookId, match, readerChapter, readThroughId);
  }

  Future<String> _handleRecap(
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

    return _templates.formatRecap(
      maxChapter: targetChapter == 999999 ? (events.isNotEmpty ? events.last.chapter : 1) : targetChapter,
      events: events,
    );
  }

  Future<String> _handleSceneSearch(
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
      return buffer.toString().trim();
    }

    return 'No matching scenes found for "$query".';
  }
}
