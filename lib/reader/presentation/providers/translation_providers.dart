import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/translation_repository.dart';
import 'package:atlas_app/reader/infrastructure/repositories/shared_prefs_translation_repository.dart';
import 'package:atlas_app/wtr/domain/entities/supported_language.dart';
import 'package:atlas_app/wtr/domain/services/google_translate_languages_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_web_translate_service.dart';

/// Persistence behind the reader's per-novel translation preference.
final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return const SharedPrefsTranslationRepository();
});

/// The saved target language for [bookId], or null when never chosen.
///
/// Uses whatever languages have already been fetched, falling back to the
/// curated static [SupportedLanguage.defaults] list.  This means the reader
/// never blocks on a network call just to resolve a language code — the full
/// list is fetched lazily in the background and Riverpod auto-rebuilds when
/// it arrives.
final targetLanguageProvider =
    FutureProvider.family<SupportedLanguage?, String>((ref, bookId) async {
      final languages = ref.watch(supportedLanguagesProvider).valueOrNull ??
          SupportedLanguage.defaults;
      return ref
          .watch(translationRepositoryProvider)
          .loadTargetLanguage(bookId, languages: languages);
    });

/// Synchronous mirror of [translationEnabledProvider] — defaults to false (off).
/// Used by reader fast-paths to skip async Riverpod awaits on cached chapter opens.
final translationEnabledSyncProvider = StateProvider.family<bool, String>((
  ref,
  bookId,
) => false);

/// Whether on-device translation is enabled for [bookId]. Only meaningful for
/// non-WTR novels — WTR translation is driven by the translation-service
/// selector instead.
final translationEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) async {
  final enabled = await ref.watch(translationRepositoryProvider).loadEnabled(bookId);
  ref.read(translationEnabledSyncProvider(bookId).notifier).state = enabled;
  return enabled;
});

/// Mutation surface for translation preferences.
final translationControllerProvider = Provider<TranslationController>((ref) {
  return TranslationController(ref.watch(translationRepositoryProvider), ref);
});

class TranslationController {
  TranslationController(this._repo, [this._ref]);

  final TranslationRepository _repo;
  final Ref? _ref;

  Future<void> setTargetLanguage(
    String bookId,
    SupportedLanguage language,
  ) async {
    await _repo.saveTargetLanguage(bookId, language);
  }

  Future<void> setEnabled(String bookId, bool enabled) async {
    await _repo.saveEnabled(bookId, enabled);
    _ref?.read(translationEnabledSyncProvider(bookId).notifier).state = enabled;
    _ref?.invalidate(translationEnabledProvider(bookId));
  }
}

/// All languages supported by Google Translate, fetched at runtime with a
/// curated fallback list for offline use.
final supportedLanguagesProvider = FutureProvider<List<SupportedLanguage>>((
  ref,
) async {
  const service = GoogleTranslateLanguagesService();
  final transport = ref.watch(googleTranslateTransportProvider);
  return service.fetchSupportedLanguages(transport);
});

/// On-device Google translation, shared by the reader's non-WTR translation
/// toggle and the WTR Web/WebPlus pipeline.
final googleTranslateServiceProvider = Provider<WtrWebTranslateService>(
  (ref) => const WtrWebTranslateService(),
);

/// Plain-HTTP transport for the on-device Google translate endpoint — the same
/// public endpoint must never ride a plugin's WebView transport.  Uses a short
/// timeout so an offline reader doesn't hang on translation before falling
/// back to the original text.
final googleTranslateTransportProvider = Provider<Transport>((ref) {
  return HttpTransport(
    client: ref.watch(httpClientProvider),
    timeout: const Duration(seconds: 5),
  );
});
