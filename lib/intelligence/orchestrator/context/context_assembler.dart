import 'dart:math' as math;

import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/context_package.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
import 'package:atlas_app/intelligence/domain/entities/story_relationship.dart';
import 'package:atlas_app/intelligence/domain/repositories/story_memory_repository.dart';
import 'package:atlas_app/intelligence/orchestrator/context/token_budgeter.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';

class ChatMessagePayload {
  const ChatMessagePayload({
    required this.role,
    required this.content,
  });

  final String role; // 'user' or 'assistant'
  final String content;
}

/// Assembles the 5-layer spoiler-safe context package and produces formatted AI prompts.
///
/// The package is query-aware: when a [userQuery] is attached, story entities
/// are relevance-reranked, the top BM25 scene excerpts for the query are
/// retrieved through FTS5 (always ≤ the reader's current chapter), and the
/// relationship graph is capped at the reader's chapter.
///
/// See also: [TokenBudgeter] for CJK-aware layer budgeting.
class ContextAssembler {
  ContextAssembler({
    required StoryMemoryRepository repository,
    TokenBudgeter? budgeter,
  })  : _repository = repository,
        _budgeter = budgeter ?? const TokenBudgeter();

  final StoryMemoryRepository _repository;
  final TokenBudgeter _budgeter;

  /// Assembles the 5-layer ContextPackage bounded strictly by [position.currentChapter].
  Future<ContextPackage> assemblePackage({
    required ReaderPosition position,
    String? taskFilter,
    String? userQuery,
    List<ChapterExcerpt> immediateWindow = const [],
  }) async {
    // 1. Fetch entities up to reader's chapter
    final allEntitiesRes = await _repository.getEntities(
      position.bookId,
      readThroughId: position.readThroughId,
    );
    var entities = <StoryEntity>[];
    if (allEntitiesRes is Success<List<StoryEntity>>) {
      // Exclude any entities first seen after reader's current chapter
      entities = allEntitiesRes.value
          .where((e) => e.firstSeenChapter <= position.currentChapter)
          .toList();
    }

    // 2. Fetch timeline events up to reader's chapter
    final eventsRes = await _repository.getEvents(
      position.bookId,
      readThroughId: position.readThroughId,
      maxChapter: position.currentChapter,
    );
    var events = <StoryEvent>[];
    if (eventsRes is Success<List<StoryEvent>>) {
      events = eventsRes.value;
    }

    // 3. Spoiler-capped relationship graph (established ≤ current chapter).
    final relationshipsRes = await _repository.getRelationships(
      position.bookId,
      readThroughId: position.readThroughId,
      maxChapter: position.currentChapter,
    );
    var relationships = <StoryRelationship>[];
    if (relationshipsRes is Success<List<StoryRelationship>>) {
      relationships = [...relationshipsRes.value]
        ..sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
      if (relationships.length > 12) {
        relationships = relationships.sublist(0, 12);
      }
    }

    // 4. Query-aware relevance reranking of the entity list. The query tokens
    //    matched against canonical names and aliases; ties fall back to the
    //    engagement-ordered stable sort so the plain (no-query) assembly
    //    stays deterministic.
    final relevance = <String, double>{};
    final queryTokens = _queryTokens(userQuery);
    if (queryTokens.isNotEmpty) {
      for (final e in entities) {
        final score = _relevanceScore(e, queryTokens);
        if (score > 0) relevance[e.id] = score;
      }
      if (relevance.isNotEmpty) {
        entities.sort((a, b) {
          final byScore = (relevance[b.id] ?? 0).compareTo(relevance[a.id] ?? 0);
          if (byScore != 0) return byScore;
          final byMentions = b.mentionCount.compareTo(a.mentionCount);
          if (byMentions != 0) return byMentions;
          return a.canonicalName.compareTo(b.canonicalName);
        });
      } else {
        // Nothing matched the query: surface the most established entities
        // first instead of an arbitrary insertion order.
        entities.sort(
          (a, b) => b.mentionCount.compareTo(a.mentionCount),
        );
      }
    }

    // 5. Top BM25 scene excerpts for the query — always spoiler-capped.
    var scenes = <String>[];
    final trimmedQuery = userQuery?.trim() ?? '';
    if (trimmedQuery.length >= 2) {
      final scenesRes = await _repository.searchScenes(
        position.bookId,
        trimmedQuery,
        readThroughId: position.readThroughId,
        maxChapter: position.currentChapter,
        limit: 3,
      );
      if (scenesRes is Success<List<String>>) {
        scenes = scenesRes.value;
      }
    }

    // Approximate token count across every layer that reaches the prompt.
    final tokenCount = _budgeter.estimateTokens(
      '${entities.map((e) => e.canonicalName).join(' ')} '
      '${events.map((e) => e.summary).join(' ')} '
      '${relationships.map((r) => r.relationType).join(' ')} '
      '${scenes.join(' ')}',
    );

    return ContextPackage(
      position: position,
      immediateWindow: immediateWindow,
      entityContext: entities,
      timelineContext: events,
      relationshipContext: relationships,
      sceneExcerpts: scenes,
      relevanceScores: relevance,
      taskFilter: taskFilter,
      estimatedTokens: tokenCount,
    );
  }

  /// Formats the 5-layer context into an [AiPrompt] respecting token budgets.
  Future<AiPrompt> assemblePrompt({
    required ReaderPosition position,
    required String userQuery,
    List<ChatMessagePayload> history = const [],
  }) async {
    final package = await assemblePackage(
      position: position,
      userQuery: userQuery,
    );

    // Layer 1 & 2: System prompt with strict spoiler boundary. This content
    // is stable per (book, read-through, chapter) so providers with prompt
    // caching can reuse it across queries at the same reading position.
    final systemBuffer = StringBuffer();
    systemBuffer.writeln(
      'You are Atlas, an intelligent novel-reading companion. You help the user understand the story, characters, factions, and world.',
    );
    systemBuffer.writeln(
      'STRICT SPOILER RULE: The reader is currently at Chapter ${position.currentChapter}. Never mention, imply, or hint at any events, deaths, character turns, or revelations that happen after Chapter ${position.currentChapter}.',
    );
    systemBuffer.writeln('Answer concisely, factually, and helpfully based on the story memory provided below.');

    // Layer 3: Story Memory Context (budgeted)
    final memoryBuffer = StringBuffer();
    if (package.entityContext.isNotEmpty) {
      memoryBuffer.writeln('\n### Story Entities:');
      for (final e in package.entityContext.take(15)) {
        final aliases = e.aliases.isNotEmpty ? ' (aka: ${e.aliases.join(", ")})' : '';
        memoryBuffer.writeln('- ${e.canonicalName}$aliases [${e.type.name}]: first seen Ch. ${e.firstSeenChapter}, last seen Ch. ${e.lastSeenChapter}');
      }
    }

    if (package.relationshipContext.isNotEmpty) {
      memoryBuffer.writeln('\n### Known Relationships:');
      final relationshipBlock = StringBuffer();
      for (final r in package.relationshipContext.take(8)) {
        final from = _entityName(package, r.sourceEntityId);
        final to = _entityName(package, r.targetEntityId);
        relationshipBlock.writeln(
          '- $from —[${r.relationType}]→ $to (est. Ch. ${r.chapterEstablished})',
        );
      }
      memoryBuffer.write(
        _budgeter.truncateToBudget(
          relationshipBlock.toString(),
          _budgeter.relationshipBudget,
        ),
      );
    }

    if (package.timelineContext.isNotEmpty) {
      memoryBuffer.writeln('\n### Key Plot Events:');
      for (final ev in package.timelineContext.take(10)) {
        memoryBuffer.writeln('- [Ch. ${ev.chapter}] ${ev.summary}');
      }
    }

    final truncatedMemory = _budgeter.truncateToBudget(
      memoryBuffer.toString(),
      _budgeter.storyMemoryBudget,
    );
    systemBuffer.writeln(truncatedMemory);

    // Layer 4: Conversation History (budgeted)
    final userPromptBuffer = StringBuffer();
    if (history.isNotEmpty) {
      final historyBuffer = StringBuffer();
      historyBuffer.writeln('### Previous Conversation:');
      for (final msg in history.take(6)) {
        historyBuffer.writeln('${msg.role == "user" ? "User" : "Assistant"}: ${msg.content}');
      }
      userPromptBuffer.writeln(
        _budgeter.truncateToBudget(
          historyBuffer.toString(),
          _budgeter.historyBudget,
        ),
      );
      userPromptBuffer.writeln();
    }

    // Query-aware scene excerpts live in the USER message (not the cacheable
    // system prompt) because they vary query-to-query at the same chapter.
    if (package.sceneExcerpts.isNotEmpty) {
      userPromptBuffer.writeln('### Relevant Scene Excerpts:');
      final scenesBlock = StringBuffer();
      for (final scene in package.sceneExcerpts.take(3)) {
        scenesBlock.writeln('• "${scene.replaceAll('\n', ' ')}"');
      }
      userPromptBuffer.writeln(
        _budgeter.truncateToBudget(
          scenesBlock.toString(),
          _budgeter.sceneExcerptBudget,
        ),
      );
      userPromptBuffer.writeln();
    }

    // Layer 5: Current User Query
    userPromptBuffer.writeln('User Query: $userQuery');

    return AiPrompt(
      systemPrompt: systemBuffer.toString().trim(),
      userPrompt: userPromptBuffer.toString().trim(),
      cacheSystemPrompt: true,
    );
  }

  String _entityName(ContextPackage package, String entityId) {
    for (final e in package.entityContext) {
      if (e.id == entityId) return e.canonicalName;
    }
    return entityId;
  }

  /// Splits a raw user query into normalized matching tokens, dropping
  /// stopword-length fragments. Works for spaced scripts and CJK alike
  /// (a CJK query stays one long token, which containment matching handles).
  List<String> _queryTokens(String? raw) {
    if (raw == null) return const [];
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[,.;:!?，。；：！？\x27"()\[\]{}—–-]', multiLine: false), ' ');
    final tokens = <String>{
      for (final t in normalized.split(RegExp(r'\s+')))
        if (t.length > 1) t,
    };
    return tokens.toList(growable: false);
  }

  /// Relevance of one entity to the parsed query tokens:
  /// 3 = exact name/alias token, 2 = containment either way, 1 = fuzzy
  /// transliteration match, weighted toward multi-token hits.
  double _relevanceScore(StoryEntity entity, List<String> tokens) {
    double best = 0;
    final names = [entity.canonicalName, ...entity.aliases];
    for (final name in names) {
      final n = name.toLowerCase().trim();
      if (n.isEmpty) continue;
      for (final token in tokens) {
        double score = 0;
        if (n == token) {
          score = 3.0;
        } else if (n.contains(token)) {
          score = 2.0 + math.min(1.0, token.length / n.length) * 0.5;
        } else if (token.length > 3 &&
            n.length > 1 &&
            token.contains(n)) {
          score = 2.0;
        }
        best = math.max(best, score);
      }
    }
    return best;
  }
}
