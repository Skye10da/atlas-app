import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secret-bearing AI provider credentials Atlas stores for the BYOK layer.
enum AiSecretKey {
  gemini,
  openai,
  openrouter,
  opencodezen,
  anthropic;

  /// SharedPreferences key used by the legacy plaintext implementation.
  String get legacyPrefKey => legacyPrefsNames[this]!;

  /// Stable key inside secure storage.
  String get secureKey => 'atlas_intel_sec_$name';
}

const Map<AiSecretKey, String> legacyPrefsNames = {
  AiSecretKey.gemini: 'atlas_intel_gemini_key',
  AiSecretKey.openai: 'atlas_intel_openai_key',
  AiSecretKey.openrouter: 'atlas_intel_openrouter_key',
  AiSecretKey.opencodezen: 'atlas_intel_opencodezen_key',
  AiSecretKey.anthropic: 'atlas_intel_anthropic_key',
};

/// Storage for AI provider API keys.
///
/// Implementations must keep secrets out of plaintext app data; the caller
/// treats credentials as opaque strings for the configured provider layer.
abstract interface class AiCredentialsStore {
  /// Returns all stored non-empty credentials, mapped per provider.
  Future<Map<AiSecretKey, String>> loadCredentials();

  /// Stores (or removes, when [value] is empty) the credential for [key].
  Future<void> saveCredential(AiSecretKey key, String value);
}

/// Real implementation backed by the platform secure store (Windows DPAPI /
/// macOS Keychain / Linux libsecret / Android Keystore), with one-time
/// migration of the legacy plaintext SharedPreferences keys.
class SecureAiCredentialsStore implements AiCredentialsStore {
  SecureAiCredentialsStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  bool _migrationDone = false;

  @override
  Future<Map<AiSecretKey, String>> loadCredentials() async {
    final result = <AiSecretKey, String>{};

    // Secure storage is the source of truth.
    for (final key in AiSecretKey.values) {
      final value = await _secureStorage.read(key: key.secureKey) ?? '';
      if (value.trim().isNotEmpty) {
        result[key] = value.trim();
      }
    }

    // One-time migration: legacy plaintext keys are moved into secure
    // storage and then erased from SharedPreferences.
    if (!_migrationDone) {
      _migrationDone = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final key in AiSecretKey.values) {
          final legacy = prefs.getString(key.legacyPrefKey)?.trim() ?? '';
          if (legacy.isEmpty) continue;
          if ((result[key] ?? '').isEmpty) {
            await _secureStorage.write(key: key.secureKey, value: legacy);
            result[key] = legacy;
          }
          await prefs.remove(key.legacyPrefKey);
        }
      } catch (_) {
        // Migration is best-effort: unreadable prefs must not break the load.
      }
    }

    return result;
  }

  @override
  Future<void> saveCredential(AiSecretKey key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: key.secureKey);
    } else {
      await _secureStorage.write(key: key.secureKey, value: trimmed);
    }
    // Scrub any legacy plaintext copy so the migration can't resurrect it.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key.legacyPrefKey);
    } catch (_) {}
  }
}

/// In-memory implementation for tests and constrained environments.
class InMemoryAiCredentialsStore implements AiCredentialsStore {
  final _values = <AiSecretKey, String>{};

  @override
  Future<Map<AiSecretKey, String>> loadCredentials() async =>
      Map.unmodifiable(
        _values..removeWhere((_, v) => v.isEmpty),
      );

  @override
  Future<void> saveCredential(AiSecretKey key, String value) async =>
      _values[key] = value.trim();
}
