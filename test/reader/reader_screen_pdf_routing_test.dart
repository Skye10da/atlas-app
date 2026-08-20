import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/database/database.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/reader/presentation/screens/reader_screen.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf_reader_content.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_content.dart';
import 'package:go_router/go_router.dart';

BooksCompanion _book({
  required String id,
  required String format,
  required String filePath,
}) => BooksCompanion(
  id: Value(id),
  title: Value('Test $id'),
  format: Value(format),
  filePath: Value(filePath),
  totalChapters: const Value(0),
  createdAt: Value(DateTime(2025, 1, 1)),
  updatedAt: Value(DateTime(2025, 1, 1)),
);

Future<void> _pumpReader(
  WidgetTester tester,
  AppDatabase db,
  String bookId,
) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: '/reader/$bookId',
    routes: [
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) =>
            ReaderScreen(bookId: state.pathParameters['bookId']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_screen_pdf_test');
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('PDF books open the native PDF reader, not the chapter reader', (
    WidgetTester tester,
  ) async {
    final bookDir = Directory(p.join(tempDir.path, 'books', 'pdf_book'));
    bookDir.createSync(recursive: true);
    File(
      p.join(bookDir.path, 'book.pdf'),
    ).writeAsBytesSync([0x25, 0x50, 0x44, 0x46]);

    await db
        .into(db.books)
        .insert(_book(id: 'pdf', format: 'pdf', filePath: bookDir.path));

    await _pumpReader(tester, db, 'pdf');

    expect(find.byType(PdfReaderContent), findsOneWidget);
    expect(find.byType(ReaderContent), findsNothing);
  });

  testWidgets('non-PDF formats still use the chapter reader', (
    WidgetTester tester,
  ) async {
    await db
        .into(db.books)
        .insert(_book(id: 'epub', format: 'epub', filePath: tempDir.path));

    await _pumpReader(tester, db, 'epub');

    expect(find.byType(PdfReaderContent), findsNothing);
  });
}
