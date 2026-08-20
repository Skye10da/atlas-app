import 'package:flutter/foundation.dart';

/// A request to re-establish an expired webview session for [origin] through a
/// visible quick webview loaded at [seedUrl] (usually the novel's source URL,
/// so the page runs the real bot challenge and lands on content).
@immutable
class SessionRefreshRequest {
  const SessionRefreshRequest({
    required this.origin,
    this.seedUrl,
    this.verificationProbe,
  });

  final Uri origin;
  final Uri? seedUrl;

  /// Optional check the refresh webview polls to decide that verification has
  /// *actually* passed — stricter than "the origin has cookies", which can be
  /// true before a bot challenge is solved (WTR-LAB sets cookies immediately).
  /// When the WTR reader API answers without `requireTurnstile`, verification
  /// has really landed. Falls back to the generic cookie probe when null.
  final Future<bool> Function()? verificationProbe;
}

/// Process-wide latch + driver seam for the "session expired" flow.
///
/// The transport layer (core, no `BuildContext`) cannot push UI, so when a
/// fetch hits an auth wall it calls [markInvalid] and this service records it.
/// The app layer watches [lastInvalidOrigin] (the reader's error state, or the
/// chapter loader's auto-refresh) and calls [ensureFresh], which runs the
/// [driver] installed by the app root — the quick webview screen that loads the
/// source, waits out the bot check, captures fresh cookies, and pops back to
/// the previous screen. The caller then retries the failed fetch.
class SessionRefreshService {
  SessionRefreshService._();

  static final SessionRefreshService instance = SessionRefreshService._();

  /// Origin of the most recent session-expired fetch failure; null once
  /// cleared or refreshed. Cleared when a refresh completes (success or not)
  /// so the auto flow never loops on the same failure.
  final ValueNotifier<Uri?> lastInvalidOrigin = ValueNotifier<Uri?>(null);

  /// The URL that triggered the session wall (usually the chapter URL), kept in
  /// sync with [lastInvalidOrigin] so the refresh webview can open the *page
  /// that needs re-verification* rather than the site root. Null when the
  /// failure carried no useful seed URL.
  final ValueNotifier<Uri?> lastInvalidSeedUrl = ValueNotifier<Uri?>(null);

  /// Domain-specific "verification passed" probe latched with the last wall —
  /// see [SessionRefreshRequest.verificationProbe]. Null falls back to the
  /// generic cookie-presence probe in the refresh webview.
  Future<bool> Function()? lastInvalidVerificationProbe;

  /// Origins already auto-refreshed this run, so the auto flow fires once per
  /// origin per cycle. Cleared when a refresh completes.
  final Set<String> _autoRefreshed = {};

  /// App-installed UI driver (see `app_session_refresh_bridge.dart`). Runs the
  /// quick webview and reports whether the session was re-established.
  Future<bool> Function(SessionRefreshRequest request)? driver;

  /// Reduces a URL to its origin (`scheme://host[:port]`), or null when it
  /// cannot be parsed / has no host.
  static Uri? originOf(String? url) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.host.isEmpty) return null;
    return uri.replace(path: '/', query: null, fragment: null);
  }

  static bool sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.port == b.port;

  /// Records that a fetch for [origin] failed on an auth/session wall.
  ///
  /// [seedUrl] — when known — is the page that needs the bot check passed
  /// (normally the chapter URL, with the active `?service=` param), used as the
  /// refresh webview's initial page. [verificationProbe] — when supplied — is
  /// how the refresh webview knows verification has truly passed (stronger than
  /// "cookies exist"), e.g. a site-specific API call that stops returning a bot
  /// challenge.
  void markInvalid(
    Uri origin, {
    Uri? seedUrl,
    Future<bool> Function()? verificationProbe,
  }) {
    lastInvalidOrigin.value = origin;
    lastInvalidSeedUrl.value = seedUrl;
    lastInvalidVerificationProbe = verificationProbe;
  }

  /// Whether [origin] was already auto-refreshed this run and not yet cleared.
  bool hasAutoRefreshed(Uri origin) => _autoRefreshed.contains(_key(origin));

  void markAutoRefreshed(Uri origin) => _autoRefreshed.add(_key(origin));

  /// Re-establishes the session for [origin] by running the installed driver
  /// (the quick webview). Returns true on success. Clears the latch regardless,
  /// so the auto flow never loops on the same failure.
  Future<bool> ensureFresh(
    Uri origin, {
    Uri? seedUrl,
    Future<bool> Function()? verificationProbe,
  }) async {
    final run = driver;
    if (run == null) {
      clearInvalid();
      return false;
    }
    final result = await run(
      SessionRefreshRequest(
        origin: origin,
        seedUrl: seedUrl,
        verificationProbe: verificationProbe ?? lastInvalidVerificationProbe,
      ),
    );
    clearInvalid();
    return result;
  }

  void clearInvalid() {
    lastInvalidOrigin.value = null;
    lastInvalidSeedUrl.value = null;
    lastInvalidVerificationProbe = null;
    _autoRefreshed.clear();
  }

  String _key(Uri origin) => origin.toString();
}
