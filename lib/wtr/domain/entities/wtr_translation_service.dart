/// The three content-retrieval services WTR-Lab offers for a chapter.
///
/// These are *user-selectable preferences for a WTR-Lab novel*, not separate
/// sources. Each maps to the `translate` value the site's
/// `POST /api/reader/get` endpoint accepts (and mirrors the `?service=` URL
/// param on the chapter page: `web`, `webplus`, and no param for `ai`).
enum WtrTranslationService {
  /// The site's web translation. Serves the *source-language* text — Chinese
  /// for Chinese-origin novels — so it is not an English option. No account
  /// needed.
  web('web', 'Web', 'Google translation, no account needed'),

  /// The "WebPlus" service. Enhanced web translation; no account needed.
  webPlus('webplus', 'WebPlus', 'Enhanced web translation, no account needed'),

  /// The AI translation service. Returns English (machine-translated), which is
  /// the site's default output language. Requires signing in to a WTR-Lab
  /// account so Atlas can reuse the authenticated browser session.
  ai('ai', 'AI', 'AI translation into English — requires a WTR-Lab account');

  const WtrTranslationService(this.apiValue, this.label, this.description);

  /// Value sent as the `translate` field in `POST /api/reader/get`.
  final String apiValue;

  /// Short label shown in the translation selector.
  final String label;

  /// One-line explanation shown next to the selector.
  final String description;

  static WtrTranslationService? fromApiValue(String value) {
    for (final service in values) {
      if (service.apiValue == value) return service;
    }
    return null;
  }

  /// The service a WTR chapter URL explicitly requests via its `?service=`
  /// query param (`web`, `webplus`, `ai`). Returns null when the param is
  /// absent or unknown — meaning the caller should keep the default behavior
  /// (the site's account-dependent default, which is not pinned by the URL).
  static WtrTranslationService? fromQueryParam(String? value) {
    if (value == null || value.isEmpty) return null;
    return fromApiValue(value);
  }
}
