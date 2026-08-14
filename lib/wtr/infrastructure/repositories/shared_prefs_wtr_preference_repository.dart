import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';

/// `SharedPreferences`-backed [WtrPreferenceRepository].
///
/// Only the *translation-service choice* is stored here — a non-sensitive UI
/// preference. Session credentials are never written to SharedPreferences.
class SharedPrefsWtrPreferenceRepository implements WtrPreferenceRepository {
  const SharedPrefsWtrPreferenceRepository();

  static String _key(int rawId) => 'wtr_translation_service_$rawId';

  @override
  Future<WtrTranslationService?> loadService(int rawId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(rawId));
    if (value == null) return null;
    return WtrTranslationService.fromApiValue(value);
  }

  @override
  Future<void> saveService(int rawId, WtrTranslationService service) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(rawId), service.apiValue);
  }
}