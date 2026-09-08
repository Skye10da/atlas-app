import 'package:http/http.dart' as http;

/// Centralized utility for detecting Cloudflare and anti-bot challenge interstitials.
///
/// Serves as a single source of truth across HTTP transports, WebViews, and
/// fetch results.
abstract final class ChallengeDetector {
  /// Well-known substrings identifying bot challenges across Cloudflare,
  /// Turnstile, DDoS-Guard, and similar mitigations. `just a moment` /
  /// `attention required` are intentionally NOT in this list — they appear
  /// verbatim in novel dialogue and cause false positives (e.g. "My Cuckhold
  /// System" chapter 4). Cloudflare challenges are always identified by the
  /// more specific `cf_*` / `challenge-platform` markers or the title.
  static const List<String> challengeMarkers = [
    'challenge-platform',
    'cf_chl_opt',
    'cf_chl',
    'cf-turnstile',
    'cf-chl-widget',
    '__cf_chl_',
    'cf-please-wait',
    'cf-under-attack',
    'checking if the site connection is secure',
    'ddos-guard',
    // Broad anti-bot / captcha markers — keep, but they are rare in prose
    'datadome',
    'hcaptcha',
    'imperva',
    'incapsula',
  ];

  /// Checks if [body] contains any bot-check challenge marker. For
  /// `just a moment` / `attention required` we only treat it as a challenge
  /// when the HTML title is the Cloudflare title — avoids flagging story
  /// text that happens to contain those phrases.
  /// Checks if [title] represents a known bot challenge interstitial title.
  static bool _isChallengeTitle(String title) {
    final t = title.toLowerCase().trim();
    return t.contains('just a moment') ||
        t.contains('attention required') ||
        t.contains('checking your browser') ||
        t.contains('security check') ||
        t.contains('ddos-guard') ||
        t == 'cloudflare' ||
        t.startsWith('cloudflare ') ||
        t.endsWith(' | cloudflare') ||
        t.contains('shieldsquare') ||
        t.contains('robot or human') ||
        t.contains('verify you are human') ||
        t.contains('bot verification');
  }

  /// Checks if `challenge-platform` indicates an actual challenge page rather
  /// than Cloudflare's JavaScript Detections (JSD) telemetry script, which is
  /// injected on every legitimate page behind Cloudflare Bot Management.
  static bool _hasChallengePlatform(String lower) {
    if (!lower.contains('challenge-platform')) return false;
    if (lower.contains('/cdn-cgi/challenge-platform/scripts/jsd') &&
        !lower.contains('/chl_page') &&
        !lower.contains('id="challenge-platform"') &&
        !lower.contains("id='challenge-platform'")) {
      return false;
    }
    return true;
  }

  /// Checks if [body] contains any bot-check challenge marker.
  static bool isChallengeBody(String body) {
    if (body.isEmpty) return false;
    final lower = body.toLowerCase();

    final titleMatch = RegExp(
      r'<title\b[^>]*>\s*([^<]*)',
      caseSensitive: false,
    ).firstMatch(body);
    final title = titleMatch?.group(1)?.trim().toLowerCase();

    // 1. If a document title exists and is a known challenge title, it is definitely a challenge.
    if (title != null && _isChallengeTitle(title)) {
      return true;
    }

    // 2. If a document title exists and is NOT a challenge title, the page is
    // an actual content page (e.g. novel chapter). Legitimate pages should not
    // be misclassified due to embedded comment widgets (turnstile, hcaptcha),
    // Cloudflare JSD scripts, or dialogue containing "just a moment".
    if (title != null && title.isNotEmpty) {
      // Only flag if explicit full-page challenge DOM containers are present.
      if (lower.contains('id="challenge-error-text"') ||
          lower.contains("id='challenge-error-text'") ||
          lower.contains('id="challenge-stage"') ||
          lower.contains("id='challenge-stage'") ||
          lower.contains('cf_chl_opt')) {
        return true;
      }
      return false;
    }

    // 3. Document has no <title> (e.g. headless fragments, raw HTML snippets).
    for (final marker in challengeMarkers) {
      if (lower.contains(marker)) return true;
      if (marker == 'challenge-platform') {
        if (_hasChallengePlatform(lower)) return true;
      } else if (lower.contains(marker)) {
        return true;
      }
    }
    // Title-gated check for the two generic phrases — only a challenge if
    // the document title itself is the Cloudflare interstitial title.

    // Title-less fragment containing Cloudflare's generic interstitial phrase.
    if (lower.contains('just a moment') ||
        lower.contains('attention required')) {
      final title = RegExp(
        r'<title>\s*([^<]*)',
        caseSensitive: false,
      ).firstMatch(body)?.group(1)?.trim().toLowerCase();
      if (title != null &&
          (title.contains('just a moment') ||
              title.contains('attention required'))) {
        return true;
      }
      return true;
    }

    return false;
  }

  /// Checks if an HTTP response represents a bot challenge.
  ///
  /// Considers response headers (such as `cf-mitigated`), status codes (403,
  /// 503, 429, and 200 with interstitial body), and HTML title/body content.
  static bool isChallengeResponse(http.Response response) {
    final status = response.statusCode;

    // Check Cloudflare specific mitigation header
    final cfMitigated = response.headers['cf-mitigated'] ?? '';
    if (cfMitigated.isNotEmpty && cfMitigated.toLowerCase().contains('challenge')) {
      return true;
    }

    // Only 403, 503, 429, or 200 (masquerading challenge body) are challenges
    if (status != 403 && status != 503 && status != 429 && status != 200) {
      return false;
    }

    if (isChallengeBody(response.body)) return true;

    if (status == 403 || status == 503 || status == 429) {
      final title = RegExp(
        // r'<title>\s*([^<]*)',
        r'<title\b[^>]*>\s*([^<]*)',
        caseSensitive: false,
      ).firstMatch(response.body)?.group(1)?.trim();
      // return title == 'Just a moment...' ||
      //     title == 'Attention Required! | Cloudflare';
      if (title != null && _isChallengeTitle(title)) {
        return true;
      }
    }

    return false;
  }
}

