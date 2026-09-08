import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/content_engine/transport/challenge_detector.dart';

void main() {
  group('ChallengeDetector', () {
    test('detects challenge substrings in HTML body', () {
      expect(
        ChallengeDetector.isChallengeBody('<html>Just a moment...</html>'),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          '<div id="challenge-platform">checking your browser</div>',
        ),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          '<div class="cf-turnstile" data-sitekey="xyz"></div>',
        ),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          'DDoS protection by Cloudflare Ray ID: 1234 cf_chl_opt',
        ),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          'Protected by DataDome, please solve captcha',
        ),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          'Please complete the hCaptcha below',
        ),
        isTrue,
      );
      expect(
        ChallengeDetector.isChallengeBody(
          '<html><body><h1>Chapter 1: The Beginning</h1><p>Normal novel content</p></body></html>',
        ),
        isFalse,
      );
      expect(ChallengeDetector.isChallengeBody(''), isFalse);
    });

    test('detects challenge from http.Response with cf-mitigated header', () {
      final response = http.Response(
        'Access Denied',
        403,
        headers: {'cf-mitigated': 'challenge'},
      );
      expect(ChallengeDetector.isChallengeResponse(response), isTrue);
    });

    test('detects challenge from http.Response with 403 and challenge title', () {
      final response = http.Response(
        '<html><head><title>Just a moment...</title></head></html>',
        403,
      );
      expect(ChallengeDetector.isChallengeResponse(response), isTrue);
    });

    test('detects masquerading 200 challenge response', () {
      final response = http.Response(
        '<html><head><title>Just a moment...</title></head>'
        '<body><div class="cf-turnstile"></div></body></html>',
        200,
      );
      expect(ChallengeDetector.isChallengeResponse(response), isTrue);
    });

    test('does not misclassify legitimate 200 responses', () {
      final response = http.Response(
        '<html><head><title>Chapter 10</title></head><body>Content</body></html>',
        200,
      );
      expect(ChallengeDetector.isChallengeResponse(response), isFalse);
    });

    test('does not misclassify generic 403 without challenge markers', () {
      final response = http.Response(
        '<html><head><title>Forbidden</title></head><body>Forbidden</body></html>',
        403,
      );
      expect(ChallengeDetector.isChallengeResponse(response), isFalse);
    });

    test('does not misclassify pages with Cloudflare JSD telemetry or dialogue', () {
      const realChapter = '''
<!DOCTYPE html>
<html lang="en-US" class="reader-background-document">
<head>
  <title>My Cuckhold System - Chapter 4: Uncompleted Quest | Free Web Novel</title>
</head>
<body>
  <div class="m-read">
    <p>"Just a moment," she pleaded, "pay attention required for this task."</p>
    <div class="cf-turnstile" data-sitekey="123"></div>
  </div>
  <script>
    var a = document.createElement('script');
    a.src = '/cdn-cgi/challenge-platform/scripts/jsd/main.js';
    document.head.appendChild(a);
  </script>
</body>
</html>''';

      expect(ChallengeDetector.isChallengeBody(realChapter), isFalse);
      expect(
        ChallengeDetector.isChallengeResponse(http.Response(realChapter, 200)),
        isFalse,
      );
    });

    test('detects actual Cloudflare orchestrator challenge page', () {
      const challengePage = '''
<!DOCTYPE html>
<html>
<head><title>Just a moment...</title></head>
<body>
  <span id="challenge-error-text">Enable JavaScript</span>
  <script src="/cdn-cgi/challenge-platform/h/g/orchestrate/chl_page/v1?ray=123"></script>
</body>
</html>''';

      expect(ChallengeDetector.isChallengeBody(challengePage), isTrue);
      expect(
        ChallengeDetector.isChallengeResponse(http.Response(challengePage, 200)),
        isTrue,
      );
    });
  });
}

