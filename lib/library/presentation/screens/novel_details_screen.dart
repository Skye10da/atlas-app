import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/application/chapter_update_service.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/atoms/book_badge.dart';
import 'package:atlas_app/core/design_system/molecules/confirm_delete_dialog.dart';
import 'package:atlas_app/core/design_system/molecules/milestone_celebration_dialog.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/router/navigation.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/intelligence/application/ingestion/story_backfill_service.dart';
import 'package:atlas_app/library/infrastructure/repositories/drift_library_repository.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/notifications/infrastructure/notification_service.dart';
import 'package:atlas_app/library/presentation/providers/novel_actions_controller.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart';
import 'package:atlas_app/library/presentation/widgets/novel/genre_tag_row.dart';
import 'package:atlas_app/intelligence/presentation/entity_browser/entity_browser_sheet.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';
import 'package:atlas_app/intelligence/presentation/review_queue/review_queue_sheet.dart';
import 'package:atlas_app/library/presentation/widgets/novel/chapter_number_picker.dart';
import 'package:atlas_app/library/presentation/widgets/novel/novel_detail_header.dart';
import 'package:atlas_app/intelligence/presentation/widgets/story_characters_section.dart';
import 'package:atlas_app/intelligence/presentation/widgets/story_recap_card.dart';
import 'package:atlas_app/library/presentation/widgets/novel/source_attribution.dart';
import 'package:atlas_app/library/presentation/widgets/novel/synopsis_card.dart';
import 'package:atlas_app/intelligence/presentation/widgets/reader_intelligence_sheet.dart';
import 'package:atlas_app/wtr/domain/entities/wtr_novel_identity.dart';
import 'package:atlas_app/wtr/presentation/widgets/wtr_translation_selector.dart';

class NovelDetailsScreen extends HookConsumerWidget {
  const NovelDetailsScreen({
    super.key,
    required this.bookId,
    this.isEmbedded = false,
    this.onClose,
  });

  final String bookId;
  final bool isEmbedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(
        ref
            .read(novelActionsControllerProvider.notifier)
            .acknowledgeUpdates(bookId),
      );
      // Kick the low-priority story-memory backfill (no-op when coverage is
      // healthy); the progress chip renders below while it runs.
      unawaited(maybeStartStoryBackfill(ref, bookId));
      return null;
    }, [bookId]);

    final backfillProgress = ref.watch(storyBackfillProgressProvider(bookId));

    final bookAsync = ref.watch(bookDetailsProvider(bookId));
    final actionsState = ref.watch(novelActionsControllerProvider);

    return bookAsync.when(
      loading: () => isEmbedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: AppLoading()),
      error: (err, _) => isEmbedded
          ? Center(child: Text('Failed to load novel: $err'))
          : Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Failed to load novel: $err')),
            ),
      data: (book) {
        final isWtrLab = isWtrLabSource(
          sourceUrl: book.sourceUrl,
          sourceName: book.sourceName,
        );
        final wtrRawId = isWtrLab
            ? wtrRawIdOf(sourceId: book.sourceId, sourceUrl: book.sourceUrl)
            : null;

        Future<void> toggleTracking() async {
          final db = ref.read(databaseProvider);
          final newTracking = !book.updateTrackingEnabled;
          await DriftLibraryRepository(
            db,
          ).setUpdateTracking(book.id, newTracking);
          if (newTracking) {
            unawaited(
              UpdateNotificationService.instance.ensureNovelChannel(
                bookId: book.id,
                title: book.title,
              ),
            );
          } else {
            unawaited(
              UpdateNotificationService.instance.deleteNovelChannel(book.id),
            );
          }
          ref.invalidate(bookDetailsProvider(bookId));
          ref.invalidate(libraryBooksProvider);
        }

        // Floating pill action row, overlaid on the pane so it sits on top of
        // the blurred cover backdrop. Replaces the old full-width icon bar.
        Widget pillBar() => Row(
          children: [
            _PillButton(
              icon: isEmbedded ? Icons.close : Icons.arrow_back_rounded,
              tooltip: isEmbedded ? 'Close' : 'Back',
              onPressed: isEmbedded ? onClose : () => popOrGoToLibrary(context),
            ),
            const Spacer(),
            _PillButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Check for updates',
              busy: actionsState.isLoading,
              onPressed: actionsState.isLoading
                  ? null
                  : () => ref
                        .read(novelActionsControllerProvider.notifier)
                        .checkForUpdates(context, bookId),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (book.isNovel) ...[
              _PillButton(
                icon: book.updateTrackingEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                tooltip: book.updateTrackingEnabled
                    ? 'Stop tracking updates'
                    : 'Track updates',
                onPressed: toggleTracking,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            _PillMenuButton(
              tooltip: 'More',
              onSelected: (value) {
                switch (value) {
                  case 'intelligence':
                    ReaderIntelligenceSheet.show(
                      context,
                      bookId: book.id,
                      bookTitle: book.title,
                      chapterIndex:
                          (ref
                                  .read(lastReadChapterProvider(book.id))
                                  .valueOrNull
                                  ?.index ??
                              0) +
                          1,
                    );
                  case 'codex':
                    EntityBrowserSheet.show(
                      context,
                      bookId: book.id,
                      readThroughId: _activeReadThroughId(ref, book.id),
                    );
                  case 'review':
                    ReviewQueueSheet.show(
                      context,
                      bookId: book.id,
                      readThroughId: _activeReadThroughId(ref, book.id),
                    );
                  case 'sessions':
                    ReadThroughSelectorSheet.show(context, bookId: book.id);
                  case 'repair':
                    _repairNovelIndex(context, ref, book);
                  case 'export':
                    _exportNovel(context, ref, book);
                  case 'delete':
                    _confirmDelete(context, ref, bookId);
                }
              },
              itemBuilder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                return [
                  const PopupMenuItem(
                    value: 'intelligence',
                    child: ListTile(
                      leading: Icon(Icons.psychology_outlined),
                      title: Text('Story Intelligence'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'codex',
                    child: ListTile(
                      leading: Icon(Icons.menu_book_rounded),
                      title: Text('Codex'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'review',
                    child: ListTile(
                      leading: Icon(Icons.verified_outlined),
                      title: Text('Review queue'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sessions',
                    child: ListTile(
                      leading: Icon(Icons.auto_stories_rounded),
                      title: Text('Read-through sessions'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: book.isNovel ? 'repair' : null,
                    child: const ListTile(
                      leading: Icon(Icons.healing_outlined),
                      title: Text('Repair chapter list'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.file_upload_outlined),
                      title: Text('Export'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text(
                        'Delete novel',
                        style: TextStyle(color: cs.error),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ];
              },
            ),
          ],
        );

        NovelDetailHeader headerFor(NovelDetailLayout layout) =>
            NovelDetailHeader(
              book: book,
              layout: layout,
              isEmbedded: isEmbedded,
            );

        final wtrSelector = wtrRawId == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: WtrTranslationSelector(
                  rawId: wtrRawId,
                  onServiceChanged: () => ref
                      .read(novelActionsControllerProvider.notifier)
                      .changeWtrService(bookId),
                ),
              );

        // About: genres, synopsis, source.
        final aboutColumn = <Widget>[
          const SizedBox(height: AppSpacing.md),
          GenreTagRow(book: book),
          const SizedBox(height: AppSpacing.lg),
          SynopsisCard(book: book),
          const SizedBox(height: AppSpacing.lg),
          SourceAttribution(book: book),
        ];

        // Story: recap, characters, reading stats.
        List<Widget> storyColumn({
          required bool scrollCharacters,
          required int maxCharacters,
        }) => [
          const SizedBox(height: AppSpacing.md),
          if (backfillProgress?.running ?? false)
            _StoryMemoryProgressChip(progress: backfillProgress!),
          StoryRecapCard(bookId: book.id),
          StoryCharactersSection(
            bookId: book.id,
            scroll: scrollCharacters,
            maxVisible: maxCharacters,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ReadingTriviaCard(book: book),
        ];

        Widget pane(List<Widget> children) => RefreshIndicator(
          onRefresh: () => ref
              .read(novelActionsControllerProvider.notifier)
              .checkForUpdates(context, bookId, showSnackbars: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [...children, const SizedBox(height: AppSpacing.xxl)],
          ),
        );

        // Phone / side panel: one column. >= 600dp: info on the left, story on
        // the right. >= 1000dp: wider left column with a smaller cover.
        final content = LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final twoPane = !isEmbedded && width >= 600;
            if (!twoPane) {
              // Pill bar floats over the pane, on top of the header backdrop.
              return Stack(
                children: [
                  pane([
                    headerFor(NovelDetailLayout.compact),
                    wtrSelector,
                    ...storyColumn(scrollCharacters: true, maxCharacters: 12),
                    ...aboutColumn,
                    const SizedBox(height: AppSpacing.lg),
                    // Chapter arrangement lives at the very bottom of the page.
                    ChapterNumberPicker(book: book),
                  ]),
                  Positioned(left: 8, right: 8, top: 8, child: pillBar()),
                ],
              );
            }
            final desktop = width >= 1000;
            final cs = Theme.of(context).colorScheme;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: desktop ? 372 : 300,
                  // Pill bar floats over this pane, on top of the header
                  // backdrop (same treatment as the single-column layout).
                  child: Stack(
                    children: [
                      pane([
                        headerFor(
                          desktop
                              ? NovelDetailLayout.desktop
                              : NovelDetailLayout.tablet,
                        ),
                        wtrSelector,
                        ...aboutColumn,
                      ]),
                      Positioned(left: 8, right: 8, top: 8, child: pillBar()),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: pane(
                    [
                      ...storyColumn(
                        scrollCharacters: false,
                        maxCharacters: desktop ? 7 : 8,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Chapter arrangement lives at the bottom of the pane.
                      ChapterNumberPicker(book: book),
                    ],
                  ),
                ),
              ],
            );
          },
        );

        if (isEmbedded) return content;
        return Scaffold(body: SafeArea(bottom: false, child: content));
      },
    );
  }

  static String _activeReadThroughId(WidgetRef ref, String bookId) =>
      ref.read(activeReadThroughProvider(bookId)).valueOrNull?.id ?? 'default';

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String bookId,
  ) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete novel?',
      message:
          'This will permanently remove the novel and all reading progress.',
      confirmLabel: 'Delete',
    );
    if (confirmed == true && context.mounted) {
      final db = ref.read(databaseProvider);
      final repo = DriftLibraryRepository(db);
      final r = await repo.deleteBook(bookId);
      if (context.mounted) {
        if (r is Success) {
          ref.invalidate(libraryBooksProvider);
          popOrGoToLibrary(context);
        } else if (r is Failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.error.userMessage)));
        }
      }
    }
  }

  static Future<void> _repairNovelIndex(
    BuildContext context,
    WidgetRef ref,
    BookEntity book,
  ) async {
    final service = ref.read(chapterUpdateServiceProvider);
    final repairFuture = service.repairBookIndex(book.id);
    final opened = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ImportProgressDialog(future: repairFuture, label: 'Repairing...'),
    );
    if (opened == null || !context.mounted) return;
    final BookRepairResult result = await repairFuture;
    if (!context.mounted) return;
    final message = result.error ??
        (result.changed
            ? 'Repaired "${result.title}": removed '
                '${result.removedDuplicates} duplicate chapter(s), '
                'index rebuilt (${result.totalChapters} chapters).'
            : 'Chapter list looks healthy (${result.totalChapters} chapters).');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    ref.invalidate(bookDetailsProvider(book.id));
    ref.invalidate(libraryBooksProvider);
  }

  static Future<void> _exportNovel(
    BuildContext context,
    WidgetRef ref,
    BookEntity book,
  ) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ExportFormatSheet(book: book),
    );
    if (format == null || !context.mounted) return;

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !context.mounted) return;

    final service = ref.read(novelExportServiceProvider);
    final progress = ValueNotifier<double>(0);

    final Future<Result<String>> exportFuture;
    if (format == 'epub') {
      exportFuture = service.exportToEpub(
        bookId: book.id,
        outputDirectory: dir,
        onFetchProgress: (done, total) =>
            progress.value = total == 0 ? 1 : done / total,
      );
    } else {
      exportFuture = service.exportSourceLink(
        bookId: book.id,
        outputDirectory: dir,
      );
    }

    if (!context.mounted) {
      try {
        await exportFuture;
      } catch (_) {}
      return;
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(
        future: exportFuture,
        progress: progress,
        label: 'Exporting...',
      ),
    );

    if (!context.mounted) return;
    final result = await exportFuture;
    final message = switch (result) {
      Success(value: final path) => 'Exported to $path',
      Failure(error: final error) => error.userMessage,
    };
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExportFormatSheet extends StatelessWidget {
  const _ExportFormatSheet({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Export ${book.title}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            _listTile(
              icon: Icons.menu_book_rounded,
              iconColor: cs.primary,
              title: 'EPUB (full text)',
              subtitle: 'Self-contained offline file with every chapter.',
              onTap: () => Navigator.of(context).pop('epub'),
            ),
            _listTile(
              icon: Icons.link_rounded,
              iconColor: cs.tertiary,
              title: 'Atlas link (.atlas)',
              subtitle:
                  'Lightweight package relinking to the original source; '
                  'chapters re-fetch on demand.',
              onTap: () => Navigator.of(context).pop('atlas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

/// Slim 'Building story memory …' chip shown while the background backfill
/// run populates story memory for chapters the reader never opened.
class _StoryMemoryProgressChip extends StatelessWidget {
  const _StoryMemoryProgressChip({required this.progress});

  final StoryBackfillProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 16, color: cs.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Building story memory '
              '${progress.covered}/${progress.totalChapters}',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingTriviaCard extends ConsumerWidget {
  const _ReadingTriviaCard({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final progressPercent = book.progressPercent;
    final progressLabel = book.progressLabel2;
    final totalCh = book.totalChapters;
    // Prefer last-read ordinal (exact) over pct-derived rounding which inflates
    // small progress (e.g., chapter 3 of 326 was showing 326/326 when pct rounded to 100).
    final lastRead = ref.watch(lastReadChapterProvider(book.id)).valueOrNull;
    final ordinalRead = lastRead != null ? lastRead.index + 1 : -1;
    final pctRead = (totalCh * book.progress01).round();
    final readCh = ordinalRead > 0 ? ordinalRead : pctRead;
    final remainingCh = (totalCh - readCh).clamp(0, totalCh);
    final estMinutes = remainingCh * 3;
    final estHours = (estMinutes / 60).toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        onTap: () {
          if (progressPercent >= 99.995) {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.firstBookFinished,
              customMessage:
                  'You finished reading ${book.title}! Outstanding journey.',
            );
          } else if (progressPercent >= 50) {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.hundredChapters,
              customMessage:
                  'Over half-way through ${book.title} ($progressLabel%). Keep pushing forward!',
            );
          } else {
            MilestoneCelebrationDialog.show(
              context,
              milestone: MilestoneType.streakThreeDays,
              customMessage:
                  'Reading ${book.title} ($readCh / $totalCh chapters). Great momentum!',
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Reading Insights',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  BookBadge(
                    label: progressPercent >= 99.995
                        ? 'Completed'
                        : (progressPercent > 0.005 ? 'Reading' : 'Unread'),
                    variant: progressPercent >= 99.995
                        ? BookBadgeVariant.tertiary
                        : (progressPercent > 0.005
                              ? BookBadgeVariant.primary
                              : BookBadgeVariant.neutral),
                    isCompact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TriviaCol(label: 'Progress', value: '$progressLabel%'),
                  _TriviaCol(label: 'Read', value: '$readCh / $totalCh'),
                  _TriviaCol(label: 'Est. Left', value: '${estHours}h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriviaCol extends StatelessWidget {
  const _TriviaCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Capsule background shared by the floating pill action row widgets.
Widget _pillContainer(BuildContext context, Widget child) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: cs.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
    ),
    child: child,
  );
}

/// Icon-only capsule button used in the floating pill row over the header.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface.withValues(alpha: onPressed == null ? 0.4 : 1);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: _pillContainer(
            context,
            Icon(icon, size: 20, color: onSurface),
          ),
        ),
      ),
    );
  }
}

/// Capsule trigger for the 'More' popup menu, matching [_PillButton].
class _PillMenuButton extends StatelessWidget {
  const _PillMenuButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
  });

  final String tooltip;
  final ValueChanged<String> onSelected;
  final List<PopupMenuItem<String>> Function(BuildContext) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: _pillContainer(
        context,
        Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurface),
      ),
    );
  }
}
