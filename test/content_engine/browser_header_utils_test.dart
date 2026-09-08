import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/transport/browser_header_utils.dart';

void main() {
  group('BrowserHeaderUtils', () {
    test('extracts Chrome major version correctly', () {
      const ua1 =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      expect(BrowserHeaderUtils.extractChromeMajorVersion(ua1), '133');

      const uaSafari =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15';
      expect(BrowserHeaderUtils.extractChromeMajorVersion(uaSafari), isNull);
    });

    test('generates matching sec-ch-ua for Chrome UA', () {
      const ua =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      final secChUa = BrowserHeaderUtils.secChUa(ua);
      expect(secChUa, contains('"Chromium";v="133"'));
      expect(secChUa, contains('"Google Chrome";v="133"'));
    });

    test('detects mobile vs desktop from user agent', () {
      const desktopUa =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      expect(BrowserHeaderUtils.secChUaMobile(desktopUa), '?0');

      const androidUa =
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';
      expect(BrowserHeaderUtils.secChUaMobile(androidUa), '?1');

      const iphoneUa =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
      expect(BrowserHeaderUtils.secChUaMobile(iphoneUa), '?1');
    });

    test('detects platform string from user agent', () {
      const winUa =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      expect(BrowserHeaderUtils.secChUaPlatform(winUa), '"Windows"');

      const macUa =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      expect(BrowserHeaderUtils.secChUaPlatform(macUa), '"macOS"');

      const androidUa =
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';
      expect(BrowserHeaderUtils.secChUaPlatform(androidUa), '"Android"');
    });

    test('buildBrowserHeaders populates complete standard navigation headers', () {
      const ua =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
      final headers = BrowserHeaderUtils.buildBrowserHeaders(
        userAgent: ua,
        existingHeaders: {'X-Custom': '123'},
      );

      expect(headers['User-Agent'], ua);
      expect(headers['X-Custom'], '123');
      expect(headers['Accept'], contains('text/html'));
      expect(headers['Accept-Language'], contains('en-US'));
      expect(headers['Accept-Encoding'], contains('gzip'));
      expect(headers['Upgrade-Insecure-Requests'], '1');
      expect(headers['sec-ch-ua'], contains('"Chromium";v="133"'));
      expect(headers['sec-ch-ua-mobile'], '?0');
      expect(headers['sec-ch-ua-platform'], '"Windows"');
      expect(headers['sec-fetch-dest'], 'document');
      expect(headers['sec-fetch-mode'], 'navigate');
      expect(headers['sec-fetch-site'], 'none');
      expect(headers['sec-fetch-user'], '?1');
    });
  });
}

