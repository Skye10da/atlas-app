import 'package:atlas_app/intelligence/orchestrator/providers/ai_provider.dart';

/// Manages registered AI providers, active provider selection, and fallback resolution.
class ProviderRegistry {
  ProviderRegistry({
    List<AiProvider> initialProviders = const [],
    String? defaultActiveProviderId,
  })  : _providers = Map.fromEntries(initialProviders.map((p) => MapEntry(p.id, p))),
        _activeProviderId = defaultActiveProviderId;

  final Map<String, AiProvider> _providers;
  String? _activeProviderId;

  List<AiProvider> get allProviders => _providers.values.toList();

  String? get activeProviderId => _activeProviderId;

  void registerProvider(AiProvider provider) {
    _providers[provider.id] = provider;
  }

  void setActiveProvider(String? providerId) {
    _activeProviderId = providerId;
  }

  AiProvider? get activeProvider {
    if (_activeProviderId != null && _providers.containsKey(_activeProviderId)) {
      return _providers[_activeProviderId];
    }
    return _providers.values.isNotEmpty ? _providers.values.first : null;
  }

  /// Returns the first available provider in the priority chain.
  Future<AiProvider?> resolveAvailableProvider() async {
    // 1. Try currently active provider first
    final current = activeProvider;
    if (current != null && await current.isAvailable()) {
      return current;
    }

    // 2. Iterate through fallback chain
    for (final provider in _providers.values) {
      if (provider.id != current?.id && await provider.isAvailable()) {
        return provider;
      }
    }

    return null;
  }
}

