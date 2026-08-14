import 'package:atlas_app/browser/domain/entities/browser_session_cookie.dart';

/// Persists the platform WebView's cookies per origin, so a restart can
/// re-seed the same-origin cookie set into the store before a background web
/// view silently navigates there (see `silent_web_view_service.dart`).
abstract interface class BrowserSessionRepositoryInterface {
  /// Snapshots the platform cookie store for [origin] and persists whatever is
  /// still unexpired. Best-effort: platform/store failures are swallowed.
  Future<void> captureForOrigin(Uri origin);

  /// Returns unexpired saved cookies for [origin]; empty when none exist.
  Future<List<BrowserSessionCookie>> loadForOrigin(Uri origin);
}
