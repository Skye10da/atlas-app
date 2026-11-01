import 'package:http/http.dart' as http;

/// Web implementation of the app's configured HTTP client: the browser owns
/// TLS and connection handling, so a plain `http.Client` (BrowserClient) is
/// all that is needed — and the only thing that can exist, because `dart:io`'s
/// HttpClient is a stub on the web target.
http.Client createConfiguredHttpClientImpl() => http.Client();
