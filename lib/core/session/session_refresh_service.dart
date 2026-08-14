import 'package:flutter/foundation.dart';

/// A request to re-establish an expired webview session for [origin] through a
/// visible quick webview loaded at [seedUrl] (usually the novel's source URL,
/// so the page runs the real bot challenge and lands on content).
@immutable
class SessionRefreshRequest {
  const SessionRefreshRequest({required this.origin, this.seedUrl});

  final Uri origin;
  final Uri? seedUrl;
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
  void markInvalid(Uri origin) {
    lastInvalidOrigin.value = origin;
  }

  /// Whether [origin] was already auto-refreshed this run and not yet cleared.
  bool hasAutoRefreshed(Uri origin) => _autoRefreshed.contains(_key(origin));

  void markAutoRefreshed(Uri origin) => _autoRefreshed.add(_key(origin));

  /// Re-establishes the session for [origin] by running the installed driver
  /// (the quick webview). Returns true on success. Clears the latch regardless,
  /// so the auto flow never loops on the same failure.
  Future<bool> ensureFresh(Uri origin, {Uri? seedUrl}) async {
    final run = driver;
    if (run == null) {
      clearInvalid();
      return false;
    }
    final result = await run(
      SessionRefreshRequest(origin: origin, seedUrl: seedUrl),
    );
    clearInvalid();
    return result;
  }

  void clearInvalid() {
    lastInvalidOrigin.value = null;
    _autoRefreshed.clear();
  }

  String _key(Uri origin) => origin.toString();
}
