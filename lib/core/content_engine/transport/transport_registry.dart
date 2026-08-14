import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/transport/cached_transport.dart';
import 'package:atlas_app/core/content_engine/transport/cookie_transport.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/offline_transport.dart';
import 'package:atlas_app/core/content_engine/transport/stealth_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';
import 'package:atlas_app/core/content_engine/transport/webview_transport.dart';

class UnknownTransportException implements Exception {
  const UnknownTransportException(this.transportKey);

  final String transportKey;

  @override
  String toString() => 'UnknownTransportException: "$transportKey"';
}

/// Builds the transport named by a plugin's `transport` key. Transport tuning
/// (delay ranges, UA rotation) comes from the plugin's permissions; no
/// per-plugin transport subclassing.
class TransportRegistry {
  const TransportRegistry({this.offlineCache});

  /// Non-null when running offline / against recorded fixtures.
  final OfflineTransport? offlineCache;

  Transport create(PluginManifest plugin, {PluginPermissions? permissions}) {
    final Transport inner;
    switch (plugin.transport) {
      case 'http':
        inner = CookieTransport(inner: HttpTransport());
      case 'stealth':
        final delays = permissions?.requestDelayMs ?? const [800, 2000];
        inner = StealthTransport(
          // Stealth already sets its own rotating User-Agent per request, so
          // CookieTransport's UA fill-in is a no-op here — it only attaches
          // the replayed cookies.
          inner: CookieTransport(inner: HttpTransport()),
          minDelay: Duration(
            milliseconds: delays.isNotEmpty ? delays.first : 800,
          ),
          maxDelay: Duration(
            milliseconds: delays.length > 1 ? delays.last : 2000,
          ),
        );
      case 'cached':
        inner = CachedTransport(inner: CookieTransport(inner: HttpTransport()));
      case 'offline':
        final cache = offlineCache;
        if (cache == null) {
          throw const TransportException(
            'offline transport requires an offline cache to be configured',
          );
        }
        inner = cache;
      default:
        throw UnknownTransportException(plugin.transport);
    }
    // Every transport can also serve through the in-app browser's live web
    // view when one is present (see WebViewFetchService), so bot-protected
    // sites import from the browser instead of failing with a Cloudflare
    // challenge.
    return WebViewTransport(inner: inner);
  }
}
