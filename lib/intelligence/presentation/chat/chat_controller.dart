import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/intelligence/application/query/intent_matcher.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/application/query/query_intent.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/orchestrator/ai_orchestrator.dart';
import 'package:atlas_app/intelligence/orchestrator/context/context_assembler.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.source = 'offline_memory', // 'offline_memory' or 'ai_orchestrator'
  });

  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final String source;
}

class ChatState {
  const ChatState({
    required this.bookId,
    this.messages = const [],
    this.isThinking = false,
    this.error,
  });

  final String bookId;
  final List<ChatMessage> messages;
  final bool isThinking;
  final String? error;

  ChatState copyWith({
    String? bookId,
    List<ChatMessage>? messages,
    bool? isThinking,
    String? error,
  }) {
    return ChatState(
      bookId: bookId ?? this.bookId,
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      error: error,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required String bookId,
    required QueryEngine queryEngine,
    AiOrchestrator? orchestrator,
  })  : _queryEngine = queryEngine,
        _orchestrator = orchestrator,
        super(ChatState(bookId: bookId));

  final QueryEngine _queryEngine;
  final AiOrchestrator? _orchestrator;
  final IntentMatcher _matcher = const IntentMatcher();

  Future<void> sendMessage({
    required String text,
    required ReaderPosition position,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
      error: null,
    );

    try {
      // 1. Check if query matches a known factual Layer 2 intent
      final match = _matcher.match(trimmed);
      final isFactualIntent = match.intent != QueryIntentType.unknown;

      if (isFactualIntent) {
        // Try Layer 2 offline query engine first
        final offlineResponse = await _queryEngine.executeQuery(
          bookId: state.bookId,
          query: trimmed,
          readerChapter: position.currentChapter,
          readThroughId: position.readThroughId,
        );

        // If Layer 2 resolved with useful content, respond immediately
        if (!offlineResponse.contains("couldn't find") &&
            !offlineResponse.contains('not sure how to answer')) {
          final replyMsg = ChatMessage(
            id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            content: offlineResponse,
            timestamp: DateTime.now(),
            source: 'offline_memory',
          );
          state = state.copyWith(
            messages: [...state.messages, replyMsg],
            isThinking: false,
          );
          return;
        }
      }

      // 2. Fall back to Layer 3 AI Orchestrator if available
      if (_orchestrator != null) {
        try {
          final historyPayload = state.messages
              .map((m) => ChatMessagePayload(role: m.role, content: m.content))
              .toList();

          final aiResponse = await _orchestrator.executeTask(
            AiTask(
              bookId: state.bookId,
              position: position,
              query: trimmed,
              history: historyPayload,
            ),
          );

          final replyMsg = ChatMessage(
            id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            content: aiResponse,
            timestamp: DateTime.now(),
            source: 'ai_orchestrator',
          );
          state = state.copyWith(
            messages: [...state.messages, replyMsg],
            isThinking: false,
          );
          return;
        } catch (_) {
          // If AI fails, proceed to Layer 2 offline fallback
        }
      }

      // 3. Fallback: Offline query engine generic response
      final fallbackResponse = await _queryEngine.executeQuery(
        bookId: state.bookId,
        query: trimmed,
        readerChapter: position.currentChapter,
        readThroughId: position.readThroughId,
      );

      final replyMsg = ChatMessage(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: fallbackResponse,
        timestamp: DateTime.now(),
        source: 'offline_memory',
      );
      state = state.copyWith(
        messages: [...state.messages, replyMsg],
        isThinking: false,
      );
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: 'Error generating response: $e',
      );
    }
  }
}

final queryEngineProvider = Provider<QueryEngine>((ref) {
  final repo = ref.watch(storyMemoryRepositoryProvider);
  return QueryEngine(repository: repo);
});

final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String>(
  (ref, bookId) {
    final queryEngine = ref.watch(queryEngineProvider);
    return ChatController(
      bookId: bookId,
      queryEngine: queryEngine,
    );
  },
);

