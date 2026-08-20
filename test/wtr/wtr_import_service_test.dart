import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_import_service.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

const _wtrSourceId = '29058';
const _wtrSourceUrl = 'https://wtr-lab.com/en/novel/29058/'
    'charm-is-full-i-have-become-a-male-god-since-high-school';
const _wtrSourceName = 'WTR-LAB';

/// Auxiliary that always reports cookies present so the auth manager reaches the
/// authenticated state (where the no-preference default is AI).
class _FakeAuxiliary implements WtrSessionAuxiliary {
  @override
  String get origin => 'https://wtr-lab.com';

  @override
  Future<void> captureCookies() async {}

  @override
  Future<bool> hasSessionCookies() async => true;

  @override
  Future<void> clearCookies() async {}
}

Future<WtrChapterProvider> _signedInProvider() async {
  final auth = WtrAuthenticationManager(
    sessionRepository: InMemoryWtrSessionRepository(),
    auxiliary: _FakeAuxiliary(),
  );
  await auth.completeLogin();
  return WtrChapterProvider(
    preferenceRepository: InMemoryWtrPreferenceRepository(),
    authManager: auth,
  );
}

void main() {
  // group('WtrTranslationService.fromQueryParam', () {
  //   test('maps explicit service params', () {
  //     expect(WtrTranslationService.fromQueryParam('web'), WtrTranslationService.web);
  //     expect(
  //       WtrTranslationService.fromQueryParam('webplus'),
  //       WtrTranslationService.webPlus,
  //     );
  //     expect(WtrTranslationService.fromQueryParam('ai'), WtrTranslationService.ai);
  //   });

  //   test('returns null for absent or unknown params', () {
  //     expect(WtrTranslationService.fromQueryParam(null), isNull);
  //     expect(WtrTranslationService.fromQueryParam(''), isNull);
  //     expect(WtrTranslationService.fromQueryParam('bogus'), isNull);
  //   });
  // });

  group('applyWtrServiceFromImportedUrl', () {
    setUp(() async {
      WtrChapterProvider.overrideForTest(await _signedInProvider());
    });

    tearDown(WtrChapterProvider.reset);

    test('pins webplus when the URL carries ?service=webplus', () async {
      await applyWtrServiceFromImportedUrl(
        '$_wtrSourceUrl/chapter-1?service=webplus',
        sourceId: _wtrSourceId,
        sourceUrl: _wtrSourceUrl,
        sourceName: _wtrSourceName,
      );
      expect(
        await WtrChapterProvider.instance.serviceFor(29058),
        WtrTranslationService.webPlus,
      );
    });

    test('pins web when the URL carries ?service=web', () async {
      await applyWtrServiceFromImportedUrl(
        '$_wtrSourceUrl/chapter-1?service=web',
        sourceId: _wtrSourceId,
        sourceUrl: _wtrSourceUrl,
        sourceName: _wtrSourceName,
      );
      expect(
        await WtrChapterProvider.instance.serviceFor(29058),
        WtrTranslationService.web,
      );
    });

    test('pins ai when the URL carries ?service=ai', () async {
      await applyWtrServiceFromImportedUrl(
        '$_wtrSourceUrl/chapter-1?service=ai',
        sourceId: _wtrSourceId,
        sourceUrl: _wtrSourceUrl,
        sourceName: _wtrSourceName,
      );
      expect(
        await WtrChapterProvider.instance.serviceFor(29058),
        WtrTranslationService.ai,
      );
    });

    test('leaves the default untouched when the URL has no service param',
        () async {
      await applyWtrServiceFromImportedUrl(
        '$_wtrSourceUrl/chapter-1',
        sourceId: _wtrSourceId,
        sourceUrl: _wtrSourceUrl,
        sourceName: _wtrSourceName,
      );
      // Signed-in default is AI; nothing was pinned.
      expect(
        await WtrChapterProvider.instance.serviceFor(29058),
        WtrTranslationService.ai,
      );
    });

    test('ignores non-WTR sources', () async {
      await applyWtrServiceFromImportedUrl(
        'https://novelfull.net/some-novel/chapter-1?service=web',
        sourceId: 'novel-1',
        sourceUrl: 'https://novelfull.net/some-novel',
        sourceName: 'NovelFull',
      );
      expect(
        await WtrChapterProvider.instance.serviceFor(42),
        WtrTranslationService.ai,
      );
    });

    test('ignores URLs with no resolvable rawId', () async {
      await applyWtrServiceFromImportedUrl(
        'https://wtr-lab.com/other/page?service=webplus',
        sourceId: 'not-a-number',
        sourceUrl: 'https://wtr-lab.com/other/page',
        sourceName: _wtrSourceName,
      );
      expect(
        await WtrChapterProvider.instance.serviceFor(9999),
        WtrTranslationService.ai,
      );
    });
  });
}
