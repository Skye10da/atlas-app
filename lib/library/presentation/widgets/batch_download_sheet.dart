import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/models/content_state.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';

class BatchDownloadSheet extends ConsumerStatefulWidget {
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
      builder: (ctx) => BatchDownloadSheet(
        book: book,
        chapters: chapters,
      ),
    );
  }

  @override
  ConsumerState<BatchDownloadSheet> createState() => _BatchDownloadSheetState();
}

class _BatchDownloadSheetState extends ConsumerState<BatchDownloadSheet> {
  bool _isDownloading = false;
  int _completed = 0;
  int _targetTotal = 0;
  String _statusText = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calculate un-downloaded chapters
    final undownloaded = widget.chapters
        .where((c) => c.contentState != ContentState.availableOffline.index)
        .toList();

    final lastReadIdx = ((widget.book.progress ?? 0.0) * widget.chapters.length).round();
    final remainingFromCurrent = widget.chapters
        .skip(lastReadIdx)
        .where((c) => c.contentState != ContentState.availableOffline.index)
        .toList();

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
                Icon(Icons.download_for_offline_rounded, color: cs.primary, size: 24),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Download Chapters',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isDownloading)
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
            if (_isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
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
                          _statusText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_completed / $_targetTotal',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                      child: LinearProgressIndicator(
                        value: _targetTotal > 0 ? _completed / _targetTotal : 0.0,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
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
                  onTap: () => _startBatchDownload(
                    chapters: remainingFromCurrent.take(10).toList(),
                    label: 'Downloading next 10 chapters',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DownloadOptionTile(
                  title: 'Next 25 Chapters',
                  subtitle: _formatSize(25),
                  icon: Icons.filter_2_rounded,
                  enabled: remainingFromCurrent.length > 10,
                  onTap: () => _startBatchDownload(
                    chapters: remainingFromCurrent.take(25).toList(),
                    label: 'Downloading next 25 chapters',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _DownloadOptionTile(
                  title: 'Next 50 Chapters',
                  subtitle: _formatSize(50),
                  icon: Icons.filter_3_rounded,
                  enabled: remainingFromCurrent.length > 25,
                  onTap: () => _startBatchDownload(
                    chapters: remainingFromCurrent.take(50).toList(),
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
                onTap: () => _startBatchDownload(
                  chapters: undownloaded,
                  label: 'Downloading all remaining chapters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSize(int count) {
    final mb = (count * 0.15).toStringAsFixed(1);
    return '~$mb MB';
  }

  Future<void> _startBatchDownload({
    required List<ChapterEntity> chapters,
    required String label,
  }) async {
    if (chapters.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _completed = 0;
      _targetTotal = chapters.length;
      _statusText = label;
    });

    final service = ref.read(chapterDownloadServiceProvider);
    final downloadingSet = ref.read(chapterDownloadingSetProvider.notifier);

    for (final ch in chapters) {
      if (!mounted) break;
      downloadingSet.update((set) => set..add(ch.id));

      await service.downloadChapter(widget.book.id, ch.index);

      downloadingSet.update((set) => set..remove(ch.id));
      if (mounted) {
        setState(() {
          _completed++;
        });
      }
    }

    ref.invalidate(novelChaptersProvider(widget.book.id));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $_completed chapters successfully.'),
        ),
      );
      Navigator.of(context).pop();
    }
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
        color: isPrimary ? cs.primaryContainer.withValues(alpha: 0.6) : cs.surfaceContainerLow,
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
                          color: isPrimary ? cs.onPrimaryContainer : cs.onSurface,
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
                  color: isPrimary ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
