import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';

/// WTR-Lab's isolated translation + authentication hub.
///
/// It is the single process-wide resolver the `wtrlab` template consults to
/// decide which request strategy a chapter uses (the `translate` value POSTed
/// to `/api/reader/get`) and whether AI content is allowed to be requested at
/// all. Nothing in the generic source engine (`SourceAdapter`, transports,
/// reader) depends on it; the WTR feature lives entirely behind this class and
/// the template that implements WTR's bespoke API.
///
/// The process-wide [instance] defaults to an in-memory configuration so pure
/// logic (unit tests, cold boot) never touches platform storage. The app wires
/// the real preference/session repositories via [initialize] during bootstrap.
class WtrChapterProvider {
  WtrChapterProvider({
    WtrPreferenceRepository? preferenceRepository,
    WtrAuthenticationManager? authManager,
  })  : _preferences =
            preferenceRepository ?? InMemoryWtrPreferenceRepository(),
        auth = authManager ?? WtrAuthenticationManager();

  static WtrChapterProvider? _instance;
  static bool _configured = false;

  /// True once [initialize] installed the platform-backed configuration, so the
  /// Riverpod bootstrap knows the singleton is app-configured and won't rebuild
  /// it with a second platform store.
  static bool get isConfigured => _configured;

  /// Process-wide resolver used by `WtrLabTemplate` and the presentation layer.
  static WtrChapterProvider get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final created = WtrChapterProvider();
    _instance = created;
    return created;
  }

  /// Replaces the process-wide instance with a platform-backed configuration.
  /// Idempotent-ish: safe to call once during app bootstrap.
  static void initialize({
    required WtrPreferenceRepository preferenceRepository,
    required WtrAuthenticationManager authManager,
  }) {
    _configured = true;
    _instance = WtrChapterProvider(
      preferenceRepository: preferenceRepository,
      authManager: authManager,
    );
  }

  /// Test hook: installs a provider with a controlled preference store / auth
  /// manager so tests never touch process-global state that other tests rely on.
  static void overrideForTest(WtrChapterProvider provider) {
    _instance = provider;
  }

  /// Resets the process-wide instance (used between tests).
  static void reset() {
    _configured = false;
    _instance = null;
  }

  final WtrPreferenceRepository _preferences;
  final WtrAuthenticationManager auth;

  /// The user-selected translation service for [rawId], falling back to
  /// [WtrTranslationService.web] when never chosen.
  Future<WtrTranslationService> serviceFor(int rawId) async {
    return await _preferences.loadService(rawId) ?? WtrTranslationService.web;
  }

  /// Persists the user's chosen translation service for [rawId].
  Future<void> setService(int rawId, WtrTranslationService service) async {
    await _preferences.saveService(rawId, service);
  }

  /// Resolves the `translate` value to POST for [rawId]'s chapters.
  ///
  /// For the AI service this enforces the auth gate first — an unauthenticated
  /// AI request throws [WtrAuthRequiredException] / [WtrSessionExpiredException]
  /// *before* any network call, so Atlas never silently falls back to another
  /// translation service.
  Future<String> resolveTranslate(int rawId) async {
    final service = await serviceFor(rawId);
    if (service == WtrTranslationService.ai) {
      auth.ensureAuthenticatedOrThrow();
    }
    return service.apiValue;
  }
}