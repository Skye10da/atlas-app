import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/marketing/domain/services/web_interop.dart';

/// Starts a browser download for a release artifact.
abstract interface class DownloadLauncher {
  Future<void> launch({required String url, required String suggestedFileName});
}

/// Web-native implementation: an invisible anchor click with a `download`
/// attribute. Keeps the visitor on the page and uses the browser's own
/// download flow (dialog, progress, notification) — the file lands without a
/// page navigation.
final class AnchorDownloadLauncher implements DownloadLauncher {
  const AnchorDownloadLauncher();

  @override
  Future<void> launch({
    required String url,
    required String suggestedFileName,
  }) async {
    final triggered = triggerBrowserDownload(url, suggestedFileName);
    if (triggered) return;
    // No DOM available (non-web target, or the anchor path failed hard) —
    // degrade to a plain external navigation, which still starts the
    // download for direct asset URLs.
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
