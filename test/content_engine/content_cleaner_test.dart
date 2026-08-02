import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';

import 'package:atlas_app/core/content_engine/cleaner/content_cleaner.dart';
import 'package:atlas_app/core/content_engine/parser/dom_parser.dart';

void main() {
  const parser = DomParser();
  const cleaner = ContentCleaner();

  Element bodyOf(String html) => parser.parse(html).body!;

  group('ContentCleaner', () {
    test('defaults remove structural noise and ad/social cruft', () {
      final body = bodyOf('''
        <html><body>
          <h1>Title</h1>
          <script>var x = 1;</script>
          <nav><a href="#">Home</a></nav>
          <div class="adsbygoogle">ad</div>
          <div class="comment-section">comments</div>
          <p>Real paragraph.</p>
        </body></html>
      ''');

      cleaner.clean(body);

      expect(body.querySelector('h1'), isNotNull);
      expect(body.querySelector('p'), isNotNull);
      expect(body.querySelector('script'), isNull);
      expect(body.querySelector('nav'), isNull);
      expect(body.querySelector('.adsbygoogle'), isNull);
      expect(body.querySelector('.comment-section'), isNull);
    });

    test('extraStripSelectors layer on top of the defaults', () {
      final body = bodyOf('''
        <html><body>
          <div class="site-specific-ad-slot">ad</div>
          <div class="adsbygoogle">ad</div>
          <p>Real text</p>
        </body></html>
      ''');

      const ContentCleaner(extraStripSelectors: ['.site-specific-ad-slot'])
          .clean(body);

      expect(body.querySelector('.site-specific-ad-slot'), isNull);
      expect(body.querySelector('.adsbygoogle'), isNull);
      expect(body.querySelector('p'), isNotNull);
    });

    test('disableDefaultStrips leaves the default lists out of play', () {
      final body = bodyOf('''
        <html><body>
          <div class="site-specific-ad-slot">ad</div>
          <div class="adsbygoogle">ad</div>
        </body></html>
      ''');

      const ContentCleaner(
        extraStripSelectors: ['.site-specific-ad-slot'],
        disableDefaultStrips: true,
      ).clean(body);

      expect(body.querySelector('.site-specific-ad-slot'), isNull);
      expect(body.querySelector('.adsbygoogle'), isNotNull);
    });

    test('removes comment nodes', () {
      final body = bodyOf('''
        <html><body>
          <!-- top level comment -->
          <p>Before <!-- nested comment --> after</p>
        </body></html>
      ''');

      cleaner.clean(body);

      final html = body.outerHtml;
      expect(html, isNot(contains('top level comment')));
      expect(html, isNot(contains('nested comment')));
    });

    test('removes empty and whitespace-only elements', () {
      final body = bodyOf('''
        <html><body>
          <p></p>
          <p>&nbsp;</p>
          <p>\n  </p>
          <div><span></span></div>
          <p>Keep me</p>
        </body></html>
      ''');

      cleaner.clean(body);

      final html = body.outerHtml;
      expect(html, isNot(contains('<p></p>')));
      expect(html, isNot(contains('&nbsp;')));
      expect(html, isNot(contains('<span>')));
      expect(body.querySelector('p')?.text, 'Keep me');
    });

    test('keeps emptied elements that carry meaningful attributes', () {
      final body = bodyOf('''
        <html><body>
          <div class="chapter-marker"><script>x</script></div>
          <p>Content</p>
        </body></html>
      ''');

      cleaner.clean(body);

      expect(body.querySelector('.chapter-marker'), isNotNull);
    });

    test('drops emptied elements whose only attribute is style', () {
      final body = bodyOf('''
        <html><body>
          <div style="color: red;"><script>x</script></div>
          <p>Content</p>
        </body></html>
      ''');

      cleaner.clean(body);

      expect(body.querySelector('div'), isNull);
    });
  });
}
