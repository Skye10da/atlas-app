import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Computes SHA-256 checksums for content versioning and plugin verification.
class ContentHasher {
  const ContentHasher();

  String sha256Of(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  String sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();
}
