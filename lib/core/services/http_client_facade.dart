import 'package:http/http.dart' as http;

import 'package:atlas_app/core/services/http_client_io.dart'
    // Web never reaches this branch: `dart:io`'s HttpClient (and the
    // certificate-bypass / connection-timeout tuning below) does not exist on
    // the web target — the browser handles TLS and connections itself.
    if (dart.library.js_interop) 'package:atlas_app/core/services/http_client_web.dart';

/// Returns the app's shared configured [http.Client].
///
/// - Native: an `IOClient` wrapping a tuned `HttpClient` (short connection
///   timeout so a stalled TLS handshake cannot block a request forever).
/// - Web: a plain browser-backed `http.Client`.
http.Client createConfiguredHttpClient() => createConfiguredHttpClientImpl();
