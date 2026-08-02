import 'package:atlas_app/core/content_engine/plugins/plugin_manifest.dart';
import 'package:atlas_app/core/content_engine/plugins/plugin_permissions.dart';
import 'package:atlas_app/core/content_engine/transport/cached_transport.dart';
import 'package:atlas_app/core/content_engine/transport/http_transport.dart';
import 'package:atlas_app/core/content_engine/transport/offline_transport.dart';
import 'package:atlas_app/core/content_engine/transport/stealth_transport.dart';
import 'package:atlas_app/core/content_engine/transport/transport.dart';

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
    switch (plugin.transport) {
      case 'http':
        return HttpTransport();
      case 'stealth':
        final delays = permissions?.requestDelayMs ?? const [800, 2000];
        return StealthTransport(
          inner: HttpTransport(),
          minDelay: Duration(milliseconds: delays.isNotEmpty ? delays.first : 800),
          maxDelay: Duration(milliseconds: delays.length > 1 ? delays.last : 2000),
        );
      case 'cached':
        return CachedTransport(inner: HttpTransport());
      case 'offline':
        final cache = offlineCache;
        if (cache == null) {
          throw const TransportException(
            'offline transport requires an offline cache to be configured',
          );
        }
        return cache;
      default:
        throw UnknownTransportException(plugin.transport);
    }
  }
}
