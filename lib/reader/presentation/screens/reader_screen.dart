import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_shimmer.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_content.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    DriftLibraryRepository(db).markAsOpened(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(readerRepositoryProvider);
    final settingsAsync = ref.watch(readingSettingsProvider);

    return settingsAsync.when(
      loading: () => _readerShimmer,
      error: (_, _) => _readerShimmer,
      data: (settings) => ReaderContent(
        repo: repo,
        bookId: widget.bookId,
        settings: settings,
      ),
    );
  }

  Widget get _readerShimmer => Scaffold(
    backgroundColor: ReadingViewTheme.light.background,
    body: const ChapterShimmer(vt: ReadingViewTheme.light),
  );
}
