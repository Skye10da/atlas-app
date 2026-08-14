/// Result of a same-origin in-page `fetch`, carrying the pieces a plain body
/// string hides: the HTTP status and the final URL after redirects. Those let
/// the transport tell an expired session (401/403, login redirect) apart from
/// a successful page — a body-only result cannot.
class WebViewFetchResult {
  const WebViewFetchResult({this.body, this.status = 0, this.finalUrl});

  /// Response body text; null when the fetch errored (CORS, network, aborted).
  final String? body;

  /// HTTP status of the final response; 0 when unavailable/errored.
  final int status;

  /// Final URL after redirects; null when unavailable/errored.
  final Uri? finalUrl;

  /// True when the body carries Cloudflare-style bot-challenge markers. A
  /// challenge interstitial is HTTP 403, so it must be told apart from a
  /// genuine auth wall before [isSessionWall] can classify 403s.
  bool get isBotChallenge {
    final lower = body?.toLowerCase() ?? '';
    return lower.contains('just a moment') ||
        lower.contains('attention required') ||
        lower.contains('challenge-platform') ||
        lower.contains('cf_chl');
  }

  /// True when the server answered with an auth/session wall rather than
  /// content: an explicit 401, a non-Cloudflare 403, or a redirect onto a
  /// login/auth endpoint. A Cloudflare 403 challenge is *not* a wall — the
  /// silent web view retries through those.
  bool get isSessionWall {
    if (status == 401) return true;
    if (status == 403) return !isBotChallenge;
    final url = finalUrl;
    if (url == null) return false;
    final host = url.host.toLowerCase();
    final path = url.path.toLowerCase();
    return host.contains('login') ||
        host.contains('signin') ||
        host.contains('auth') ||
        path.contains('/login') ||
        path.contains('/signin') ||
        path.contains('/auth') ||
        path.contains('/account');
  }
}
