import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_sheet.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_translation_service.dart';
import 'package:atlas_app/wtr/domain/repository_interfaces/wtr_preference_repository.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/domain/services/wtr_chapter_provider.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReaderSettingsSheet', () {
    testWidgets(
      'shows a Translate tab for WTR-Lab novels and, on service change, '
      'drops the downloaded chapter so the reader refetches it',
      (tester) async {
        final db = AppDatabase.memory();
        final wtr = WtrChapterProvider(
          preferenceRepository: InMemoryWtrPreferenceRepository(),
          authManager: WtrAuthenticationManager(),
        );
        final tempDir = Directory.systemTemp.createTempSync('reader_settings');
        final file = File(p.join(tempDir.path, '0.txt'));
        file.writeAsStringSync('old translation text');

        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion(
                id: const Value('b1_ch0'),
                bookId: const Value('b1'),
                index: const Value(0),
                title: const Value('Chapter 1'),
                contentPath: Value(file.path),
                wordCount: const Value(100),
                pageCount: const Value(1),
                contentState: Value(ContentState.availableOffline.index),
                version: const Value(2),
                checksum: const Value('abc'),
                previousVersionRef: const Value('b1_ch0'),
                createdAt: Value(DateTime(2025, 1, 1)),
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              wtrRuntimeProvider.overrideWith((ref) async => wtr),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ReaderSettingsSheet(
                  initialSettings: ReadingSettingsEntity(),
                  bookId: 'b1',
                  rawId: 29058,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Translate'), findsOneWidget);

        await tester.tap(find.text('Translate'));
        await tester.pumpAndSettle();

        // Starts on WebPlus (the signed-out default).
        expect(find.text('WebPlus'), findsOneWidget);
        expect(find.text('AI'), findsOneWidget);

        await tester.tap(find.text('Web'));
        await tester.pumpAndSettle();

        expect(await wtr.serviceFor(29058), WtrTranslationService.web);
        // The chapter was downloaded; switching the service must drop the stale
        // on-disk text so the next read refetches under the new service.
        expect(file.existsSync(), isFalse);
        await db.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    testWidgets(
      'shows the Translate tab for non-WTR-Lab novels with the translation '
      'toggle instead of the WTR service selector',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ReaderSettingsSheet(
                  initialSettings: ReadingSettingsEntity(),
                  bookId: 'b1',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Every novel now has a Translate tab; non-WTR novels get the toggle.
        expect(find.text('Translate'), findsOneWidget);
        await tester.tap(find.text('Translate'));
        await tester.pumpAndSettle();

        expect(find.text('Translate this novel'), findsOneWidget);
        expect(find.text('WebPlus'), findsNothing);
        expect(find.text('AI'), findsNothing);
      },
    );
  });
}
