import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/intelligence/domain/entities/context_package.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/domain/entities/story_entity.dart';
import 'package:atlas_app/intelligence/domain/entities/story_event.dart';
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

    // Approximate token count
    final tokenCount = _budgeter.estimateTokens(
      '${entities.map((e) => e.canonicalName).join(' ')} ${events.map((e) => e.summary).join(' ')}',
    );

    return ContextPackage(
      position: position,
      immediateWindow: immediateWindow,
      entityContext: entities,
      timelineContext: events,
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
    final package = await assemblePackage(position: position);

    // Layer 1 & 2: System prompt with strict spoiler boundary
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
      userPromptBuffer.writeln('### Previous Conversation:');
      for (final msg in history.take(6)) {
        userPromptBuffer.writeln('${msg.role == "user" ? "User" : "Assistant"}: ${msg.content}');
      }
      userPromptBuffer.writeln();
    }

    // Layer 5: Current User Query
    userPromptBuffer.writeln('User Query: $userQuery');

    return AiPrompt(
      systemPrompt: systemBuffer.toString().trim(),
      userPrompt: userPromptBuffer.toString().trim(),
    );
  }
}
