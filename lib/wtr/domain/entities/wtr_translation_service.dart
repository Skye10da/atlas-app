/// The content-retrieval services a WTR-Lab chapter can be read with.
///
/// These are *user-selectable preferences for a WTR-Lab novel*, not separate
/// sources. `web`, `webPlus` and `ai` map to the `translate` value the site's
/// `POST /api/reader/get` endpoint accepts (and mirror the `?service=` URL
/// param on the chapter page: `web`, `webplus`, and no param for `ai`).
///
/// [aiPlus] is the exception: it is an *Atlas-side* mode, not a WTR-Lab
/// service. Chapters are fetched exactly like [web] (source-language text)
/// and translated on-device by the user's own AI provider (Gemini, OpenAI,
/// …) using the per-novel glossary — so its [apiValue] is only a
/// persistence key, and [WtrChapterProvider.resolveTranslate] sends
/// `web`'s value to the server for it.
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
  ai('ai', 'AI', 'AI translation into English — requires a WTR-Lab account'),

  /// Atlas-side glossary-aware AI translation through the user's own AI
  /// provider (Gemini / OpenAI / OpenRouter / OpenCode Zen / Anthropic).
  /// Fetches source-language text like [web], then translates locally with
  /// the per-novel glossary injected into the prompt. No WTR-Lab account,
  /// but requires an API key configured in Settings → AI Translation.
  aiPlus(
    'aiplus',
    'AI+',
    'Glossary-aware AI translation using your own AI-provider API key',
  );

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
