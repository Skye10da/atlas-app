/// WTR-Lab's browser-session plumbing, isolated behind a seam so the auth
/// manager stays testable without the WebView plugin.
///
/// Capturing/probing/clearing the WTR session means talking to the platform
/// WebView cookie store and the app's per-origin browser-session repository —
/// the same mechanism Atlas already uses for Cloudflare-style browser sessions.
/// The interface keeps those platform touches out of the pure domain logic.
abstract interface class WtrSessionAuxiliary {
  /// Origin the WTR session is scoped to.
  String get origin;

  /// Snapshots the platform cookie store for the WTR origin and persists it
  /// (so a restart can re-seed the authenticated session). Best-effort.
  Future<void> captureCookies();

  /// True when the platform cookie store currently has cookies for the WTR
  /// origin — i.e. a usable authenticated session.
  Future<bool> hasSessionCookies();

  /// Removes the WTR cookies from the platform store (logout / change account).
  Future<void> clearCookies();
}
