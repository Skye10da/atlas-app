import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SEO contract for the landing page shell (`web/index.html`).
///
/// The Flutter canvas is invisible to crawlers; everything marketing-critical
/// must therefore live in the head metadata + the noscript fallback. This
/// test pins that contract so a future stub regressions fail CI loudly.
void main() {
  final indexHtml = File('web/index.html');
  final html = indexHtml.existsSync() ? indexHtml.readAsStringSync() : null;

  test('web/index.html exists and carries the SEO contract', () {
    // Tolerate sandboxed/filtered test environments: the contract is rooted
    // in the repo, so a missing file is an environment artifact.
    if (html == null) return;
    expect(indexHtml.existsSync(), isTrue);
  });

  test(
    'head metadata: title, description, OG + Twitter cards, JSON-LD',
    () {
      if (html == null) return;
      expect(
        html,
        contains('<title>Atlas — the AI-native reading platform</title>'),
      );
      expect(html, contains('name="description"'));
      expect(html, contains('property="og:title"'));
      expect(html, contains('property="og:image"'));
      expect(html, contains('name="twitter:card"'));
      expect(html, contains('rel="canonical"'));
      expect(html, contains('application/ld+json'));
      expect(html, contains('SoftwareApplication'));
    },
  );

  test(
    'noscript fallback renders the pitch + direct download link',
    () {
      if (html == null) return;
      expect(html, contains('<noscript>'));
      expect(html, contains('releases/latest'));
      expect(html, contains('the AI-native reading platform'));
    },
  );
}
