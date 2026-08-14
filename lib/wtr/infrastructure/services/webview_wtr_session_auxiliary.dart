import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:atlas_app/browser/domain/repository_interfaces/browser_session_repository_interface.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

/// [WtrSessionAuxiliary] backed by the app's existing browser-session
/// infrastructure: the platform WebView cookie store (the persistent,
/// OS-backed browser session storage) plus the per-origin JSON session
/// repository that re-seeds those cookies after a restart.
///
/// WTR credentials are treated exactly like every other browser session Atlas
/// stores: they live in the cookie store / browser-session repository, never
/// in application preferences, and never in logs.
class WebViewWtrSessionAuxiliary implements WtrSessionAuxiliary {
  WebViewWtrSessionAuxiliary({
    required this.sessionStore,
    Uri? origin,
  }) : _origin = origin ?? Uri.parse('https://wtr-lab.com');

  final BrowserSessionRepositoryInterface sessionStore;
  final Uri _origin;

  @override
  String get origin => _origin.toString();

  @override
  Future<void> captureCookies() async {
    try {
      await sessionStore.captureForOrigin(_origin);
    } on Object catch (e) {
      AppLogger.warning('Failed to capture WTR-Lab session: $e');
    }
  }

  @override
  Future<bool> hasSessionCookies() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri.uri(_origin),
      );
      return cookies.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> clearCookies() async {
    try {
      // Only WTR-Lab cookies are removed — the shared browser session store is
      // never swept as a side effect of logging out of this one origin.
      await CookieManager.instance().deleteCookies(
        url: WebUri.uri(_origin),
      );
    } on Object catch (e) {
      AppLogger.warning('Failed to clear WTR-Lab cookies: $e');
    }
  }
}
