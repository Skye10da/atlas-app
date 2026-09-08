import 'package:flutter/foundation.dart';

/// Utilities for generating authentic browser headers matching modern browsers.
abstract final class BrowserHeaderUtils {
  /// Extracts the major Chrome version from a User-Agent string, or returns null.
  static String? extractChromeMajorVersion(String userAgent) {
    final match = RegExp(r'Chrome/(\d+)').firstMatch(userAgent);
    return match?.group(1);
  }

  /// Derives the `sec-ch-ua` header string matching the given [userAgent].
  ///
  /// If [cronetVersion] is provided (Android Cronet runtime version, e.g.
  /// `118.0.5993.111`), its major version takes precedence — it is the
  /// authentic Chromium version bundled with `cronet_http`. Otherwise falls
  /// back to parsing `Chrome/xxx` from the UA string.
  /// Returns null if the browser is not Chromium-based (e.g. Safari or Firefox).
  static String? secChUa(String userAgent, {String? cronetVersion}) {
    String? major;
    if (cronetVersion != null && cronetVersion.isNotEmpty) {
      final firstDot = cronetVersion.split('.').first.trim();
      if (int.tryParse(firstDot) != null) {
        major = firstDot;
      }
    }
    major ??= extractChromeMajorVersion(userAgent);
    if (major == null) return null;
    return '"Chromium";v="$major", "Not(A:Brand";v="24", "Google Chrome";v="$major"';
  }

  /// Detects whether the User-Agent represents a mobile client (`?1` vs `?0`).
  static String secChUaMobile(String userAgent) {
    final lower = userAgent.toLowerCase();
    final isMobile =
        lower.contains('mobile') ||
        lower.contains('android') ||
        lower.contains('iphone') ||
        lower.contains('ipad');
    return isMobile ? '?1' : '?0';
  }

  /// Detects the platform string for `sec-ch-ua-platform` (e.g. `"Windows"`, `"Android"`).
  static String secChUaPlatform(String userAgent) {
    final lower = userAgent.toLowerCase();
    if (lower.contains('windows')) return '"Windows"';
    if (lower.contains('android')) return '"Android"';
    if (lower.contains('mac os x') || lower.contains('macintosh')) {
      if (lower.contains('iphone') || lower.contains('ipad')) return '"iOS"';
      return '"macOS"';
    }
    if (lower.contains('iphone') || lower.contains('ipad')) return '"iOS"';
    if (lower.contains('linux')) return '"Linux"';

    // Fallback to runtime platform
    if (kIsWeb) return '"Windows"';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '"Android"';
      case TargetPlatform.iOS:
        return '"iOS"';
      case TargetPlatform.macOS:
        return '"macOS"';
      case TargetPlatform.windows:
        return '"Windows"';
      case TargetPlatform.linux:
        return '"Linux"';
      default:
        return '"Windows"';
    }
  }

  /// Builds a complete set of browser headers matching a top-level page navigation.
  ///
  /// If [cronetVersion] is supplied (Android Cronet runtime version), it is
  /// used for `sec-ch-ua` instead of parsing the UA — avoids mismatched
  /// claimed-vs-actual Chrome version fingerprint.
  static Map<String, String> buildBrowserHeaders({
    required String userAgent,
    Map<String, String>? existingHeaders,
    String? cronetVersion,
  }) {
    final headers = <String, String>{...?existingHeaders};

    headers.putIfAbsent('User-Agent', () => userAgent);
    headers.putIfAbsent(
      'Accept',
      () =>
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    );
    headers.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    // `br` (Brotli) is not decoded by dart:io HttpClient on Windows
    // (BoringSSL) — advertising it makes some origins return Brotli bytes
    // that then fail as `FormatException: Invalid UTF-8` when we do
    // `response.body`. Keep `gzip, deflate` which dart:io/Cronet handle.
    final acceptEncoding = () {
      if (kIsWeb) return 'gzip, deflate, br';
      // Cronet (Android) and URLSession (iOS/macOS) handle br; dart:io does not.
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return 'gzip, deflate, br';
        default:
          return 'gzip, deflate';
      }
    }();
    headers.putIfAbsent('Accept-Encoding', () => acceptEncoding);
    headers.putIfAbsent('Upgrade-Insecure-Requests', () => '1');

    final chUa = secChUa(userAgent, cronetVersion: cronetVersion);
    if (chUa != null) {
      headers.putIfAbsent('sec-ch-ua', () => chUa);
      headers.putIfAbsent('sec-ch-ua-mobile', () => secChUaMobile(userAgent));
      headers.putIfAbsent(
        'sec-ch-ua-platform',
        () => secChUaPlatform(userAgent),
      );
    }

    headers.putIfAbsent('sec-fetch-dest', () => 'document');
    headers.putIfAbsent('sec-fetch-mode', () => 'navigate');
    headers.putIfAbsent('sec-fetch-site', () => 'none');
    headers.putIfAbsent('sec-fetch-user', () => '?1');

    return headers;
  }
}
