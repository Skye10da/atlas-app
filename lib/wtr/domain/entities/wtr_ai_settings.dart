import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';

/// The user's AI-translation configuration for the WTR "AI+" mode.
///
/// Holds the *active* provider plus a per-provider API key and model, so
/// switching providers never loses the credentials of the previous one.
/// Values live in SharedPreferences (see
/// [SharedPrefsWtrAiSettingsRepository]); API keys are device-local and are
/// only ever sent to the provider the user configured.
class WtrAiSettings {
  const WtrAiSettings({
    this.provider = WtrAiProviderId.gemini,
    Map<String, String> apiKeys = const {},
    Map<String, String> models = const {},
  }) : _apiKeys = apiKeys,
       _models = models;

  /// The provider AI+ currently translates with.
  final WtrAiProviderId provider;

  final Map<String, String> _apiKeys;
  final Map<String, String> _models;

  /// API key stored for [p], if any.
  String? apiKeyFor(WtrAiProviderId p) => _apiKeys[p.id];

  /// Model stored for [p], falling back to that provider's default when the
  /// user has not picked one yet.
  String modelFor(WtrAiProviderId p) => _models[p.id] ?? p.defaultModel;

  /// The model explicitly chosen for [p], or null when it still resolves to
  /// the provider default. Persistence uses this to keep "unset" and
  /// "default" indistinguishable on disk.
  String? storedModelFor(WtrAiProviderId p) => _models[p.id];

  /// The key AI+ would use right now.
  String? get activeApiKey => apiKeyFor(provider);

  /// The model AI+ would use right now.
  String get activeModel => modelFor(provider);

  /// True when the active provider has both a key and a model, i.e. an AI+
  /// request can be attempted at all.
  bool get isConfigured =>
      (activeApiKey ?? '').isNotEmpty && activeModel.isNotEmpty;

  /// Switches the active provider without touching any credentials.
  WtrAiSettings withProvider(WtrAiProviderId p) => p == provider
      ? this
      : WtrAiSettings(provider: p, apiKeys: _apiKeys, models: _models);

  /// Sets (or clears, when blank/null) [p]'s API key.
  WtrAiSettings withApiKey(WtrAiProviderId p, String? value) {
    final next = {..._apiKeys};
    if (value == null || value.isEmpty) {
      next.remove(p.id);
    } else {
      next[p.id] = value;
    }
    return WtrAiSettings(provider: provider, apiKeys: next, models: _models);
  }

  /// Sets (or resets to the provider default, when blank/null) [p]'s model.
  WtrAiSettings withModel(WtrAiProviderId p, String? value) {
    final next = {..._models};
    if (value == null || value.isEmpty || value == p.defaultModel) {
      next.remove(p.id);
    } else {
      next[p.id] = value;
    }
    return WtrAiSettings(provider: provider, apiKeys: _apiKeys, models: next);
  }
}
