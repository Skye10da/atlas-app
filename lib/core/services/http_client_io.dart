import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Native implementation of the app's configured HTTP client.
http.Client createConfiguredHttpClientImpl() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (_, _, _) => true;
  // Without this, a stalled TLS negotiation (e.g. "connection terminated
  // during handshake") blocks the request forever.
  httpClient.connectionTimeout = const Duration(seconds: 15);
  return IOClient(httpClient);
}
