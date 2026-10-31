import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_app/intelligence/application/query/intent_matcher.dart';
import 'package:atlas_app/intelligence/application/query/query_engine.dart';
import 'package:atlas_app/intelligence/application/query/query_intent.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/infrastructure/persistence/ai_credentials_store.dart';
import 'package:atlas_app/intelligence/orchestrator/ai_orchestrator.dart';
import 'package:atlas_app/intelligence/orchestrator/context/context_assembler.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/cloud_byok_provider.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ollama_provider.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/provider_registry.dart';
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
    Future<AiOrchestrator?> Function()? orchestratorResolver,
  })  : _queryEngine = queryEngine,
        _orchestrator = orchestrator,
        _orchestratorResolver = orchestratorResolver,
        super(ChatState(bookId: bookId));

  final QueryEngine _queryEngine;
  final AiOrchestrator? _orchestrator;
  final Future<AiOrchestrator?> Function()? _orchestratorResolver;

  /// The orchestrator injected at construction wins; otherwise it is resolved
  /// lazily (once per message) from the user's configured AI providers.
  Future<AiOrchestrator?> _resolveOrchestrator() async {
    final injected = _orchestrator;
    if (injected != null) return injected;
    return _orchestratorResolver?.call();
  }
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

      QueryAnswer? offlineAnswer;
      if (isFactualIntent) {
        // Try Layer 2 offline query engine first. The typed answer tells us
        // whether the engine actually resolved facts from story memory (vs.
        // replying "couldn't find"), without sniffing response strings.
        offlineAnswer = await _queryEngine.executeQueryDetailed(
          bookId: state.bookId,
          query: trimmed,
          readerChapter: position.currentChapter,
          readThroughId: position.readThroughId,
        );

        // If Layer 2 resolved with useful content, respond immediately
        if (offlineAnswer.isResolved) {
          final replyMsg = ChatMessage(
            id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            content: offlineAnswer.text,
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
      final orchestrator = await _resolveOrchestrator();
      if (orchestrator != null) {
        try {
          final historyPayload = state.messages
              .map((m) => ChatMessagePayload(role: m.role, content: m.content))
              .toList();

          final aiResponse = await orchestrator.executeTask(
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
      final fallbackResponse = offlineAnswer?.text ??
          await _queryEngine.executeQuery(
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

/// Lazily builds the Layer 3 orchestrator from the BYOK settings the user
/// saved in the "AI & BYOK Settings" screen (`atlas_intel_*` keys). Returns
/// null while the user has the "100% Offline Story Memory" mode selected,
/// which makes the chat fall back to the offline Layer 2 query engine only.
///
/// Resolved once per message by the chat controller via `ref.read(.future)`,
/// so the provider chain is only constructed when the user actually chats.
final aiOrchestratorProvider = FutureProvider<AiOrchestrator?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final active = prefs.getString('atlas_intel_active_provider') ?? 'offline';
  if (active == 'offline') return null;

  // Secrets come from the secure credential store (DPAPI/Keychain/Keystore);
  // this also transparently migrates legacy plaintext keys on first load.
  final credentials = await ref.watch(aiCredentialsStoreProvider).loadCredentials();
  String? keyOf(AiSecretKey key) {
    final value = credentials[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  final geminiKey = keyOf(AiSecretKey.gemini);
  final openaiKey = keyOf(AiSecretKey.openai);
  final openrouterKey = keyOf(AiSecretKey.openrouter);
  final anthropicKey = keyOf(AiSecretKey.anthropic);
  final zenKey = keyOf(AiSecretKey.opencodezen);
  final ollamaEndpointRaw = prefs.getString('atlas_intel_ollama_endpoint')?.trim();
  final ollamaEndpoint =
      (ollamaEndpointRaw == null || ollamaEndpointRaw.isEmpty) ? null : ollamaEndpointRaw;

  // Every provider is registered: an unconfigured one simply reports
  // unavailable and is skipped by the registry's fallback chain.
  final providers = <AiProvider>[
    if (ollamaEndpoint != null) OllamaProvider(endpoint: ollamaEndpoint),
    CloudByokProvider(providerType: CloudProviderType.gemini, apiKey: geminiKey),
    CloudByokProvider(providerType: CloudProviderType.openai, apiKey: openaiKey),
    CloudByokProvider(providerType: CloudProviderType.openRouter, apiKey: openrouterKey),
    CloudByokProvider(providerType: CloudProviderType.opencodeZen, apiKey: zenKey),
    CloudByokProvider(providerType: CloudProviderType.anthropic, apiKey: anthropicKey),
  ];

  final String? activeProviderId = switch (active) {
    'ollama' => 'ollama',
    'cloud_gemini' => 'cloud_gemini',
    'cloud_openai' => 'cloud_openai',
    'cloud_openrouter' => 'cloud_openrouter',
    'cloud_opencodezen' => 'cloud_opencodezen',
    'cloud_anthropic' => 'cloud_anthropic',
    _ => null,
  };

  return AiOrchestrator(
    registry: ProviderRegistry(
      initialProviders: providers,
      defaultActiveProviderId: activeProviderId,
    ),
    assembler: ContextAssembler(
      repository: ref.watch(storyMemoryRepositoryProvider),
    ),
  );
});

final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String>(
  (ref, bookId) {
    final queryEngine = ref.watch(queryEngineProvider);
    return ChatController(
      bookId: bookId,
      queryEngine: queryEngine,
      orchestratorResolver: () => ref.read(aiOrchestratorProvider.future),
    );
  },
);

