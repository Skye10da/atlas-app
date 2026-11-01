import 'package:atlas_app/core/logging/logger.dart';

/// Landing-page conversion analytics.
///
/// Deliberately contract-first: event *names and params* are fixed by this
/// class so any reporter swap (Plausible, Umami, GA) is a one-file change.
/// The default reporter logs through [AppLogger] — zero third-party script,
/// no cookies, still visible in dev console and easily wired to a JS
/// `fetch` beacon from the web bootstrap later.
abstract final class LandingAnalytics {
  /// Fired when the landing page is rendered with a device already resolved.
  static const String viewEvent = 'landing_view';

  /// Fired when a visitor taps the smart download button.
  static const String downloadClickEvent = 'download_click';

  /// Fired when a visitor picks a specific platform from the manual grid.
  static const String platformPickEvent = 'download_platform_pick';

  /// Fired when the primary action had to fall back to the releases page.
  static const String fallbackClickEvent = 'download_fallback_click';

  /// Fires one event. [params] values must be analytics-reporter friendly
  /// (strings/bools/numbers); os/arch/version strings follow the taxonomy in
  /// docs/plans/landing_upgrade_plan.md.
  static void event(
    String name, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    AppLogger.info('landing-event $name $params');
  }
}
