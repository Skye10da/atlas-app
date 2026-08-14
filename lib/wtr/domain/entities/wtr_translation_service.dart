/// The three content-retrieval services WTR-Lab offers for a chapter.
///
/// These are *user-selectable preferences for a WTR-Lab novel*, not separate
/// sources. Each maps to the `translate` value the site's
/// `POST /api/reader/get` endpoint accepts (and mirrors the `?service=` URL
/// param on the chapter page: `web`, `webplus`, and no param for `ai`).
enum WtrTranslationService {
  /// The standard site translation (Cloudflare-protected, no account needed).
  web('web', 'Web', 'Default web translation'),

  /// The "WebPlus" service (Cloudflare-protected, no account needed).
  webPlus('webplus', 'WebPlus', 'Enhanced web translation'),

  /// The AI translation service. Requires signing in to a WTR-Lab account so
  /// Atlas can reuse the authenticated browser session.
  ai('ai', 'AI', 'AI translation — requires a WTR-Lab account');

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
}
