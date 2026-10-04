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

    yield* provider.completeStream(
      AiPrompt(
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
        model: task.preferredModel,
        temperature: task.temperature,
      ),
    );
  }
}

