import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/native_client_factory.dart';

void main() {
  group('native_client_factory', () {
    test('returns a non-null http.Client instance on current platform', () {
      final client = createNativeClient();
      expect(client, isA<http.Client>());
      client.close();
    });
  });
}

