import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/updater/domain/changelog_text.dart';

void main() {
  group('ChangelogText.render', () {
    test('strips heading markers but keeps the heading text', () {
      expect(
        ChangelogText.render('# Added\n## Fixed\n### Internal'),
        'Added\nFixed\nInternal',
      );
    });

    test('bullets are indented so SelectableText keeps the hierarchy', () {
      expect(
        ChangelogText.render('- one\n* two'),
        '  •  one\n  •  two',
      );
    });

    test('links collapse to label + url', () {
      expect(
        ChangelogText.render('See [release](https://example.com) now.'),
        'See release (https://example.com) now.',
      );
    });

    test('images collapse to a placeholder', () {
      expect(
        ChangelogText.render('![](https://example.com/screen.png)'),
        '(image: )',
      );
    });

    test('bold markers are removed', () {
      expect(ChangelogText.render('**Very** fast'), 'Very fast');
    });

    test('blank-line runs collapse away entirely', () {
      expect(
        ChangelogText.render('a\n\n\n\nb'),
        'a\nb',
      );
    });

    test('windows line endings and trailing blanks are normalized', () {
      expect(
        ChangelogText.render('# Fixed\r\n- crash on boot\r\n\r\n\r\n'),
        'Fixed\n  •  crash on boot',
      );
    });

    test('a typical release body renders readably', () {
            const body = '# Atlas 1.0.9\n\n'
          '**Highlights**\n\n'
          '- In-app updater polish ([#12](https://github.com/x/y/pull/12))\n'
          '- Faster cold start\n';      expect(
        ChangelogText.render(body),
        'Atlas 1.0.9\n'
            'Highlights\n'
            '  •  In-app updater polish '
            '(#12 (https://github.com/x/y/pull/12))\n'
            '  •  Faster cold start',
      );
    });
  });
}
