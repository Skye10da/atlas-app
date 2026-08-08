import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/import/epub_import_service.dart';
import 'package:atlas_app/core/import/file_open_controller.dart';
import 'package:atlas_app/core/import/opened_file_import_service.dart';
import 'package:atlas_app/core/import/pdf_import_service.dart';
import 'package:atlas_app/library/application/atlas_source_import_service.dart';

final fileOpenControllerProvider = Provider<FileOpenController>((ref) {
  final controller = FileOpenController();
  ref.onDispose(controller.dispose);
  return controller;
});

final openedFileImportServiceProvider = Provider<OpenedFileImportService>((ref) {
  final db = ref.watch(databaseProvider);
  return OpenedFileImportService(
    epubService: EpubImportService(db),
    pdfService: PdfImportService(db),
    atlasService: const AtlasSourceImportService(),
    engine: ref.watch(contentAcquisitionEngineProvider),
  );
});