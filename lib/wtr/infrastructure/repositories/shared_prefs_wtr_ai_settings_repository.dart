import 'package:atlas_app/wtr/domain/entities/wtr_ai_provider.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_ai_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed store for the WTR "AI+" translation settings:
/// the active provider plus a per-provider API key and model.
///
/// Mirrors `SharedPrefsWtrPreferenceRepository`. API keys are device-local
/// secrets that are only ever transmitted to the provider endpoint the user
/// configured; SharedPreferences matches where the rest of the WTR
/// preferences live.
class SharedPrefsWtrAiSettingsRepository {
  const SharedPrefsWtrAiSettingsRepository();

  static const _providerKey = 'wtr_ai_provider';
  static String _apiKeyKey(WtrAiProviderId p) => 'wtr_ai_api_key_${p.id}';
  static String _modelKey(WtrAiProviderId p) => 'wtr_ai_model_${p.id}';

  Future<WtrAiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var settings = WtrAiSettings(
      provider:
          WtrAiProviderId.fromId(prefs.getString(_providerKey)) ??
          WtrAiProviderId.gemini,
    );
    for (final provider in WtrAiProviderId.values) {
      settings = settings.withApiKey(
        provider,
        prefs.getString(_apiKeyKey(provider)),
      );
      // Only persist an explicit choice; the default is implied.
      final model = prefs.getString(_modelKey(provider));
      if (model != null) {
        settings = settings.withModel(provider, model);
      }
    }
    return settings;
  }

  Future<void> save(WtrAiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider.id);
    for (final provider in WtrAiProviderId.values) {
      await _setOrRemove(
        prefs,
        _apiKeyKey(provider),
        settings.apiKeyFor(provider),
      );
      // Only explicit choices are stored so "unset" and "default" stay
      // identical on disk.
      await _setOrRemove(
        prefs,
        _modelKey(provider),
        settings.storedModelFor(provider),
      );
    }
  }

  /// Test hook: drops every stored AI-translation preference.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
    for (final provider in WtrAiProviderId.values) {
      await prefs.remove(_apiKeyKey(provider));
      await prefs.remove(_modelKey(provider));
    }
  }

  static Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}
