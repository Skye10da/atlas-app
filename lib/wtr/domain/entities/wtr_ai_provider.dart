/// The AI providers Atlas can use for the WTR-Lab "AI+" translation mode.
///
/// Each value identifies one remote API. Three client shapes cover all five
/// providers: Gemini's native `generateContent`, the OpenAI
/// `chat/completions` shape (OpenAI, OpenRouter, OpenCode Zen), and
/// Anthropic's Messages API.
enum WtrAiProviderId {
  gemini('gemini', 'Gemini'),
  openai('openai', 'OpenAI'),
  openRouter('openrouter', 'OpenRouter'),
  opencodeZen('opencodezen', 'OpenCode Zen'),
  anthropic('anthropic', 'Anthropic');

  const WtrAiProviderId(this.id, this.label);

  /// Stable persistence key used by the settings repository.
  final String id;

  /// Human-readable name shown in the settings screen.
  final String label;

  static WtrAiProviderId? fromId(String? id) {
    if (id == null) return null;
    for (final provider in values) {
      if (provider.id == id) return provider;
    }
    return null;
  }
}

extension WtrAiProviderModels on WtrAiProviderId {
  /// Curated model IDs shown when the live `/models` fetch fails, and the
  /// source of each provider's default ([fallbackModels.first]).
  ///
  /// Kept short and conservative; the dynamic fetch plus the free-text
  /// override in Settings are the primary paths, so staleness here only
  /// degrades gracefully.
  List<String> get fallbackModels => switch (this) {
    WtrAiProviderId.gemini => [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.5-flash-lite',
    ],
    WtrAiProviderId.openai => ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
    // OpenCode Zen serves most models through chat/completions; its
    // GPT-5.x "Sol/Terra/Luna" tier uses the Responses API instead and is
    // intentionally absent here.
    WtrAiProviderId.opencodeZen => [
      'glm-5.2',
      'kimi-k3',
      'deepseek-v4-pro',
      'minimax-m3',
    ],
    WtrAiProviderId.openRouter => [
      'google/gemini-2.5-flash',
      'openai/gpt-4o-mini',
      'anthropic/claude-sonnet-4.5',
    ],
    WtrAiProviderId.anthropic => ['claude-haiku-4-5', 'claude-sonnet-4-5'],
  };

  /// Model assumed before the user picks one explicitly.
  String get defaultModel => fallbackModels.first;
}
