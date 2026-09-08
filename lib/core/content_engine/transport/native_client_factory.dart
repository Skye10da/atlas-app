import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';

/// Returns the best available [http.Client] matching the runtime platform:
///
/// - **Android**: [CronetClient] (Chromium network stack, authentic Chrome TLS ClientHello, HTTP/2 + HTTP/3)
/// - **iOS / macOS**: [CupertinoClient] (Apple URLSession stack, authentic Safari/WebKit TLS ClientHello, HTTP/2 + HTTP/3)
/// - **Windows / Linux / Web**: standard [http.Client] (dart:io IOClient / BrowserClient)
http.Client createNativeClient() {
  if (kIsWeb) return http.Client();

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      try {
        return CronetClient.defaultCronetEngine();
      } catch (_) {
        return http.Client();
      }
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      try {
        return CupertinoClient.defaultSessionConfiguration();
      } catch (_) {
        return http.Client();
      }
    default:
      return http.Client();
  }
}

