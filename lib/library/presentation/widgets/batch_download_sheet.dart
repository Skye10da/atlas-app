import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/session/session_refresh_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/book_providers.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/core/design_system/molecules/app_toast.dart';

class BatchDownloadSheet extends HookConsumerWidget {
  const BatchDownloadSheet({
    super.key,
    required this.book,
    required this.chapters,
  });

  final BookEntity book;
  final List<ChapterEntity> chapters;

  static Future<void> show(
    BuildContext context, {
    required BookEntity book,
    required List<ChapterEntity> chapters,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchDownloadSheet(book: book, chapters: chapters),
    );
  }

  static String _formatSize(int count) {
    final mb = (count * 0.15).toStringAsFixed(1);
    return '~$mb MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = useState(false);
    final completed = useState(0);
    final targetTotal = useState(0);
    final statusText = useState('');
    // Chapters whose fetch failed, so a bot-check wall can be reported and
    // retried after re-verification instead of silently counted as downloaded.
    final failed = useState<List<ChapterEntity>>([]);
    final reverifying = useState(false);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calculate un-downloaded chapters
    final undownloaded = chapters
        .where((c) => c.contentState != ContentState.availableOffline.index)
        .toList();

    final lastReadIdx = (book.progress01 * chapters.length).round();
    final remainingFromCurrent = chapters
        .skip(lastReadIdx)
        .where((c) => c.contentState != ContentState.availableOffline.index)
        .toList();

    /// Downloads [toDownload] sequentially, tracking failures instead of counting
    /// them as downloaded. Declared as a variable because the failure path
    /// offers a re-verify + retry that calls back into it.
    late Future<void> Function({
      required List<ChapterEntity> toDownload,
      required String label,
    }) startBatchDownload;

    /// Re-runs a failed set after the user clears the site's bot check in the
    /// quick re-verify webview. Also a variable for the same mutual-reference
    /// reason as [startBatchDownload].
    late Future<void> Function(List<ChapterEntity>) reverifyAndDownload;

    Future<void> runBatchDownload({
      required List<ChapterEntity> toDownload,
      required String label,
    }) async {
      if (toDownload.isEmpty) return;

      isDownloading.value = true;
      completed.value = 0;
      targetTotal.value = toDownload.length;
      statusText.value = label;

      final service = ref.read(chapterDownloadServiceProvider);
      final downloadingSet = ref.read(chapterDownloadingSetProvider.notifier);
      final failures = <ChapterEntity>[];

      for (final ch in toDownload) {
        if (!context.mounted) break;
        downloadingSet.update((set) => set..add(ch.id));

        final result = await service.downloadChapter(book.id, ch.index);

        downloadingSet.update((set) => set..remove(ch.id));
        if (!context.mounted) break;
        if (result is Failure) {
          failures.add(ch);
          continue;
        }
        completed.value = completed.value + 1;
      }

      ref.invalidate(novelChaptersProvider(book.id));
      ref.invalidate(bookChaptersProvider(book.id));

      if (!context.mounted) return;
      if (failures.isEmpty) {
        AppToast.show(
          'Downloaded ${completed.value} chapters successfully.',
          tone: AppToastTone.download,
        );
        Navigator.of(context).pop();
        return;
      }

      // Failures surfaced instead of a false "downloaded" claim. A bot check on
      // the source origin keeps the sheet open and offers re-verify + retry;
      // anything else (404s, dead links) just reports the count.
      failed.value = failures;
      final session = SessionRefreshService.instance;
      final bookOrigin = SessionRefreshService.originOf(book.sourceUrl);
      final latched = session.lastInvalidOrigin.value;
      final challenge =
          latched != null &&
          bookOrigin != null &&
          SessionRefreshService.sameOrigin(latched, bookOrigin);

      if (challenge) {
        AppToast.show(
          '${failures.length} chapters blocked by a bot check. Re-verify the '
          'session to download them.',
          tone: AppToastTone.warning,
          duration: const Duration(seconds: 8),
          action: AppToastAction(
            'Re-verify',
            () => unawaited(reverifyAndDownload(failures)),
          ),
        );
      } else {
        AppToast.showError('Failed to download ${failures.length} chapters.');
      }
      if (!challenge) Navigator.of(context).pop();
    }

    /// Re-runs [toDownload] after the user clears the site's bot check in the
    /// quick re-verify webview; fresh cookies are captured for the origin, so
    /// the retried fetches replay them (or are served by the silent webview).
    Future<void> runReverifyAndDownload(List<ChapterEntity> toDownload) async {
      if (reverifying.value) return;
      final session = SessionRefreshService.instance;
      final origin = SessionRefreshService.originOf(book.sourceUrl);
      if (origin == null) return;
      reverifying.value = true;
      failed.value = <ChapterEntity>[];
      try {
        final ok = await session.ensureFresh(
          origin,
          seedUrl: Uri.tryParse(book.sourceUrl ?? ''),
        );
        if (!ok || !context.mounted) return;
        await startBatchDownload(
          toDownload: toDownload,
          label: 'Retrying ${toDownload.length} chapters',
        );
      } finally {
        if (context.mounted) reverifying.value = false;
      }
    }

    startBatchDownload = runBatchDownload;
    reverifyAndDownload = runReverifyAndDownload;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header
            Row(
              children: [
                Icon(
                  Icons.download_for_offline_rounded,
                  color: cs.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Download Chapters',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isDownloading.value)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${undownloaded.length} chapters available for offline reading',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Downloading Progress View
            if (isDownloading.value) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusMd,
                  ),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          statusText.value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${completed.value} / ${targetTotal.value}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusFull,
                      ),
                      child: LinearProgressIndicator(
                        value: targetTotal.value > 0
                            ? completed.value / targetTotal.value
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    if (failed.value.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${failed.value.length} chapters blocked by a bot check.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: reverifying.value
                            ? null
                            : () => unawaited(reverifyAndDownload(failed.value)),
                        icon: reverifying.value
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined, size: 18),
                        label: const Text('Re-verify session & retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Options List
              if (remainingFromCurrent.isNotEmpty) ...[
                _DownloadOptionTile(
                  title: 'Next 10 Chapters',
                  subtitle: _formatSize(10),
                  icon: Icons.filter_1_rounded,
                  enabled: remainingFromCurrent.isNotEmpty,
                  onTap: () => startBatchDownload(
                    toDownload: remainingFromCurrent.take(10).toList(),
                    label: 'Downloading next 10 chapters',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DownloadOptionTile(
                  title: 'Next 25 Chapters',
                  subtitle: _formatSize(25),
                  icon: Icons.filter_2_rounded,
                  enabled: remainingFromCurrent.length > 10,
                  onTap: () => startBatchDownload(
                    toDownload: remainingFromCurrent.take(25).toList(),
                    label: 'Downloading next 25 chapters',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DownloadOptionTile(
                  title: 'Next 50 Chapters',
                  subtitle: _formatSize(50),
                  icon: Icons.filter_3_rounded,
                  enabled: remainingFromCurrent.length > 25,
                  onTap: () => startBatchDownload(
                    toDownload: remainingFromCurrent.take(50).toList(),
                    label: 'Downloading next 50 chapters',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              _DownloadOptionTile(
                title: 'All Remaining (${undownloaded.length} chs)',
                subtitle: _formatSize(undownloaded.length),
                icon: Icons.cloud_download_rounded,
                enabled: undownloaded.isNotEmpty,
                isPrimary: true,
                onTap: () => startBatchDownload(
                  toDownload: undownloaded,
                  label: 'Downloading all remaining chapters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadOptionTile extends StatelessWidget {
  const _DownloadOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: isPrimary
            ? cs.primaryContainer.withValues(alpha: 0.6)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smMd,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isPrimary ? cs.onPrimaryContainer : cs.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPrimary
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPrimary
                              ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isPrimary
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
