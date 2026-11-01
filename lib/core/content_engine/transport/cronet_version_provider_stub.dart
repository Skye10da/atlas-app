/// Web implementation of [CronetVersionProvider].
///
/// `cronet_http` (via `jni`) depends on `dart:ffi`, which does not exist on
/// the web target, so this stub keeps the same API and always reports no
/// bundled Chromium version. Callers fall back to User-Agent parsing, exactly
/// as on Windows / Linux where no Cronet engine is installed either.
abstract final class CronetVersionProvider {
  /// Always `null` on web.
  static const String? cachedVersion = null;

  /// Always resolves to `null` on web.
  static Future<String?> getVersion() => Future<String?>.value();
}
