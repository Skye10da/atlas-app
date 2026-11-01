import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/native_client_factory_io.dart'
    // Web never touches the FFI-backed clients (cronet_http → dart:ffi via
    // jni, cupertino_http → dart:ffi via objective_c) — those libraries are
    // not available on the web target at all, so they must live behind this
    // conditional import. The web branch simply hands out a plain
    // [http.Client] (BrowserClient).
    if (dart.library.js_interop) 'package:atlas_app/core/content_engine/transport/native_client_factory_web.dart';

/// Returns the best available [http.Client] matching the runtime platform:
///
/// - **Android**: [CronetClient] (Chromium network stack, authentic Chrome TLS ClientHello, HTTP/2 + HTTP/3)
/// - **iOS / macOS**: [CupertinoClient] (Apple URLSession stack, authentic Safari/WebKit TLS ClientHello, HTTP/2 + HTTP/3)
/// - **Windows / Linux / Web**: standard [http.Client] (dart:io IOClient / BrowserClient)
http.Client createNativeClient() => createPlatformHttpClient();
