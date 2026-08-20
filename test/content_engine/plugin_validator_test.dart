import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/content_engine/plugins/plugin_validator.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_session_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/domain/services/wtr_session_auxiliary.dart';

/// A WTR session auxiliary that always reports session cookies present, so the
/// auth manager can be driven to the authenticated state in tests.
class _AuthenticatedWtrAuxiliary implements WtrSessionAuxiliary {
  @override
  String get origin => 'https://wtr-lab.com';

  @override
  Future<void> captureCookies() async {}

  @override
  Future<bool> hasSessionCookies() async => true;

  @override
  Future<void> clearCookies() async {}
}

void main() {
  setUp(() async {
    // The wtrlab template defaults to the AI translation service (English),
    // which requires an authenticated WTR-Lab session — provide one so the
    // chapter fixture can be exercised.
    final auth = WtrAuthenticationManager(
      sessionRepository: InMemoryWtrSessionRepository(),
      auxiliary: _AuthenticatedWtrAuxiliary(),
    );
    await auth.completeLogin();
    WtrChapterProvider.overrideForTest(WtrChapterProvider(authManager: auth));
  });

  tearDown(WtrChapterProvider.reset);

  test(
    'atlas-plugins/ passes PluginValidator (schema, checksums, fixtures)',
    () async {
      final issues = await PluginValidator().validateAll(
        Directory('atlas-plugins'),
      );
      expect(
        issues,
        isEmpty,
        reason: issues.isEmpty
            ? null
            : 'validation issues:\n'
                  '${issues.map((i) => ' - $i').join('\n')}\n'
                  'Re-run the tools if checksums/registry are stale.',
      );
    },
  );

  test('a tampered fixture fails validation', () async {
    final tempDir = await Directory.systemTemp.createTemp('validator_test');
    final pluginDir = Directory('${tempDir.path}${Platform.pathSeparator}fake');
    await pluginDir.create(recursive: true);
    await File(
      '${pluginDir.path}${Platform.pathSeparator}plugin.json',
    ).writeAsString('''
{
  "id": "fake",
  "name": "Fake",
  "sourceName": "Fake",
  "version": "1.0.0",
  "templateId": "html",
  "baseUrl": "https://example.com",
  "transport": "http",
  "capabilities": ["chapterList", "chapterContent"]
}
''');
    await Directory(
      '${pluginDir.path}${Platform.pathSeparator}tests${Platform.pathSeparator}fixtures',
    ).create(recursive: true);
    await File(
      '${pluginDir.path}${Platform.pathSeparator}tests'
      '${Platform.pathSeparator}fixtures${Platform.pathSeparator}chapter.html',
    ).writeAsString(
      '<html><body><div class="content"><p>Wrong text.</p>'
      '</div></body></html>',
    );
    await File(
      '${pluginDir.path}${Platform.pathSeparator}tests'
      '${Platform.pathSeparator}expected.json',
    ).writeAsString(
      jsonEncode({
        'chapter': {
          'url': 'https://example.com/chapter/1',
          'method': 'chapterContent',
          'textContains': ['Expected text'],
        },
      }),
    );

    final issues = await PluginValidator().validateAll(tempDir);
    expect(
      issues.where((i) => i.category == 'fixture'),
      isNotEmpty,
      reason: 'expected a fixture failure for the mismatched text',
    );
    await tempDir.delete(recursive: true);
  });
}
