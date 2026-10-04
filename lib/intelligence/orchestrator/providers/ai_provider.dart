/// A prompt request to send to an AI provider.
class AiPrompt {
  const AiPrompt({
    required this.systemPrompt,
    required this.userPrompt,
    this.model,
    this.temperature = 0.3,
    this.maxTokens = 1024,
  });

  final String systemPrompt;
  final String userPrompt;
  final String? model;
  final double temperature;
  final int maxTokens;
}

/// Abstract contract for an AI provider (Cloud BYOK, Ollama, Local llama.cpp).
abstract interface class AiProvider {
  String get id;
  String get name;

  /// Checks whether the provider is configured and reachable.
  Future<bool> isAvailable();

  /// Lists available models for this provider.
  Future<List<String>> getAvailableModels();

  /// Completes a prompt and returns the full text response.
  Future<String> complete(AiPrompt prompt);

  /// Streams token deltas from the provider.
  Stream<String> completeStream(AiPrompt prompt);
}

