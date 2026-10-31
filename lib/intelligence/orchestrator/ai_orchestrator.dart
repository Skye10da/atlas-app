import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/orchestrator/context/context_assembler.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';
import 'package:atlas_app/intelligence/orchestrator/providers/provider_registry.dart';

class AiTask {
  const AiTask({
    required this.bookId,
    required this.position,
    required this.query,
    this.history = const [],
    this.preferredModel,
    this.temperature = 0.3,
  });

  final String bookId;
  final ReaderPosition position;
  final String query;
  final List<ChatMessagePayload> history;
  final String? preferredModel;
  final double temperature;
}

/// Orchestrates execution of AI tasks across providers with automatic fallback.
class AiOrchestrator {
  AiOrchestrator({
    required ProviderRegistry registry,
    required ContextAssembler assembler,
  })  : _registry = registry,
        _assembler = assembler;

  final ProviderRegistry _registry;
  final ContextAssembler _assembler;

  /// Executes an AI task using the first available provider, falling back if errors occur.
  Future<String> executeTask(AiTask task) async {
    final prompt = await _assembler.assemblePrompt(
      position: task.position,
      userQuery: task.query,
      history: task.history,
    );

    final provider = await _registry.resolveAvailableProvider();
    if (provider == null) {
      throw StateError('No AI providers configured or available.');
    }

    try {
      return await provider.complete(
        AiPrompt(
          systemPrompt: prompt.systemPrompt,
          userPrompt: prompt.userPrompt,
          model: task.preferredModel,
          temperature: task.temperature,
          cacheSystemPrompt: prompt.cacheSystemPrompt,
        ),
      );
    } catch (e) {
      // Attempt fallback to another provider
      for (final fallback in _registry.allProviders) {
        if (fallback.id != provider.id && await fallback.isAvailable()) {
          try {
            return await fallback.complete(
              AiPrompt(
                systemPrompt: prompt.systemPrompt,
                userPrompt: prompt.userPrompt,
                model: task.preferredModel,
                temperature: task.temperature,
                cacheSystemPrompt: prompt.cacheSystemPrompt,
              ),
            );
          } catch (_) {
            continue;
          }
        }
      }
      rethrow;
    }
  }

  /// Streams token deltas from the active available provider.
  ///
  /// Streaming fallback ladder:
  /// 1. The selected provider's stream runs; if it fails *before* emitting a
  ///    first delta, the same provider's non-streaming completion is tried,
  ///    then other available providers (stream, then completion).
  /// 2. Once any delta has been emitted, a mid-stream failure is rethrown —
  ///    silently restarting would duplicate output the user already saw.
  Stream<String> executeStream(AiTask task) async* {
    final prompt = await _assembler.assemblePrompt(
      position: task.position,
      userQuery: task.query,
      history: task.history,
    );

    final provider = await _registry.resolveAvailableProvider();
    if (provider == null) {
      throw StateError('No AI providers configured or available.');
    }

    final candidates = <AiProvider>[
      provider,
      for (final p in _registry.allProviders)
        if (p.id != provider.id && await p.isAvailable()) p,
    ];

    Object? lastError;
    for (final candidate in candidates) {
      var emitted = false;
      // 1. Try the streaming path.
      try {
        await for (final chunk in candidate.completeStream(prompt)) {
          emitted = true;
          yield chunk;
        }
        return;
      } catch (e) {
        if (emitted) rethrow;
        lastError = e;
      }

      // 2. Same provider without streaming (some gateways stream badly but
      //    complete fine).
      try {
        yield await candidate.complete(prompt);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('All AI providers failed.');
  }
}

