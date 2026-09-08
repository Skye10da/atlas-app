// ignore_for_file: avoid_dynamic_calls

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';

/// Provides the Cronet/Chromium version bundled with `cronet_http` on Android.
///
/// On Android the `CronetEngine` reports its full version string (e.g.
/// `118.0.5993.111`). That major version is the only correct value for
/// `sec-ch-ua`; deriving it from the WebView UA can mismatch and becomes a
/// fingerprinting signal. On other platforms or when the engine is
/// unavailable the provider returns `null` and callers fall back to UA
/// parsing.
abstract final class CronetVersionProvider {
  static String? _cachedVersion;
  static Future<String?>? _pending;

  /// Returns the full Cronet version string, e.g. `118.0.5993.111`, or `null`.
  ///
  /// Result is cached for the process lifetime. Safe on any platform —
  /// non-Android platforms immediately return `null` without touching JNI.
  static Future<String?> getVersion() {
    if (_cachedVersion != null) return Future.value(_cachedVersion);
    if (_pending != null) return _pending!;
    _pending = _fetch()
        .then((v) {
          _cachedVersion = v;
          return v;
        })
        .whenComplete(() => _pending = null);
    return _pending!;
  }

  /// Synchronous cached value if already resolved, otherwise `null`.
  static String? get cachedVersion => _cachedVersion;

  static Future<String?> _fetch() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final version = await _fetchViaCronet();
      return version;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchViaCronet() async {
    CronetEngine? engine;
    try {
      engine = CronetEngine.build();
      // Access the underlying `jb.CronetEngine.versionString` via dynamic
      // to avoid needing a public getter. `CronetEngine._engine` is
      // library-private, so we bypass static checking with `dynamic`.
      final dynamic dynEngine = engine;
      final dynamic jbEngine = dynEngine._engine;
      final dynamic jStr = jbEngine.versionString;
      if (jStr == null) return null;
      final String? dartStr =
          jStr.toDartString(releaseOriginal: true) as String?;
      return dartStr;
    } catch (_) {
      return null;
    } finally {
      try {
        engine?.close();
      } catch (_) {}
    }
  }
}
