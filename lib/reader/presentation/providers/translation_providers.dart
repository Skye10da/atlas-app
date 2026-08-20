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
final targetLanguageProvider =
    FutureProvider.family<SupportedLanguage?, String>((ref, bookId) async {
      final languages = await ref.watch(supportedLanguagesProvider.future);
      return ref
          .watch(translationRepositoryProvider)
          .loadTargetLanguage(bookId, languages: languages);
    });

/// Whether on-device translation is enabled for [bookId]. Only meaningful for
/// non-WTR novels — WTR translation is driven by the translation-service
/// selector instead.
final translationEnabledProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) {
  return ref.watch(translationRepositoryProvider).loadEnabled(bookId);
});

/// Mutation surface for translation preferences.
final translationControllerProvider = Provider<TranslationController>((ref) {
  return TranslationController(ref.watch(translationRepositoryProvider));
});

class TranslationController {
  TranslationController(this._repo);

  final TranslationRepository _repo;

  Future<void> setTargetLanguage(
    String bookId,
    SupportedLanguage language,
  ) async {
    await _repo.saveTargetLanguage(bookId, language);
  }

  Future<void> setEnabled(String bookId, bool enabled) async {
    await _repo.saveEnabled(bookId, enabled);
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
/// public endpoint must never ride a plugin's WebView transport.
final googleTranslateTransportProvider = Provider<Transport>((ref) {
  return HttpTransport(client: ref.watch(httpClientProvider));
});
