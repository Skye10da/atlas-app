import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/presentation/providers/browser_providers.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_preference_repository.dart';
import 'package:atlas_app/wtr/infrastructure/repositories/shared_prefs_wtr_session_repository.dart';
import 'package:atlas_app/wtr/infrastructure/services/webview_wtr_session_auxiliary.dart';

/// Session capture/validation for WTR-Lab, backed by the platform WebView
/// cookie store plus the same per-origin JSON repository the browser uses for
/// Cloudflare-protected sessions. Cookies never touch SharedPreferences.
final wtrSessionAuxiliaryProvider = Provider<WtrSessionAuxiliary>((ref) {
  return WebViewWtrSessionAuxiliary(
    sessionStore: ref.watch(browserSessionRepositoryProvider),
  );
});

/// The platform-backed WTR runtime: translation-service preferences persist in
/// SharedPreferences and the session manager's cookies live in the WebView
/// cookie store. Idempotent — once the singleton is configured it is returned
/// as-is, so a second build (or a widget-test override) never re-wires the
/// process-wide state.
final wtrRuntimeProvider = FutureProvider<WtrChapterProvider>((ref) async {
  if (WtrChapterProvider.isConfigured) return WtrChapterProvider.instance;
  final auth = WtrAuthenticationManager(
    sessionRepository: const SharedPrefsWtrSessionRepository(),
    auxiliary: ref.watch(wtrSessionAuxiliaryProvider),
  );
  await auth.initialize();
  WtrChapterProvider.initialize(
    preferenceRepository: const SharedPrefsWtrPreferenceRepository(),
    authManager: auth,
  );
  return WtrChapterProvider.instance;
});

/// The auth manager behind the current runtime. Falls back to the default
/// in-memory manager while the runtime is still configuring so the login
/// screen never blocks on a null.
final wtrAuthManagerProvider = Provider<WtrAuthenticationManager>((ref) {
  final runtime = ref.watch(wtrRuntimeProvider).valueOrNull;
  return runtime?.auth ?? WtrChapterProvider.instance.auth;
});

/// The user's chosen translation service for a given novel (`rawId`), defaulting
/// to the site's account-dependent default (AI when signed in, WebPlus
/// otherwise) when never chosen.
final wtrTranslationServiceProvider =
    FutureProvider.family<WtrTranslationService, int>((ref, rawId) async {
  final runtime = await ref.watch(wtrRuntimeProvider.future);
  return runtime.serviceFor(rawId);
});

/// Creates the WebView engine for the WTR-Lab sign-in screen. Kept as a
/// separate provider so tests can swap in a fake engine.
final wtrLoginEngineFactoryProvider = Provider<BrowserEngineFactory>((ref) {
  return ref.watch(browserEngineFactoryProvider);
});
