import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';

/// Native-branch HTTP client factory (Android / iOS / macOS / Windows / Linux).
///
/// Web never reaches this file: it is only selected through the conditional
/// import in `native_client_factory.dart` when `dart:ffi`-backed libraries are
/// available.
http.Client createPlatformHttpClient() {
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
