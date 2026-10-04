import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atlas_app/core/design_system/atoms/app_button.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/review_item.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';

import 'package:atlas_app/intelligence/presentation/read_through/read_through_selector_sheet.dart';

class ReviewQueueSheet extends ConsumerWidget {
  const ReviewQueueSheet({
    super.key,
    required this.bookId,
    this.readThroughId,
  });

  final String bookId;
  final String? readThroughId;

  static void show(
    BuildContext context, {
    required String bookId,
    String? readThroughId,
  }) {
    AppSheet.show(
      context: context,
      id: 'review_queue_$bookId',
      title: 'Story Review Queue',
      initialHeight: 0.65,
      child: ReviewQueueSheet(bookId: bookId, readThroughId: readThroughId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewQueueControllerProvider(bookId));
    final controller = ref.read(reviewQueueControllerProvider(bookId).notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeRt = ref.watch(activeReadThroughProvider(bookId)).valueOrNull;
    final sessionName = activeRt?.name ?? 'Primary Read';

    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: AppLoading(),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: colors.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'All caught up!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No entity candidates pending review for "$sessionName".',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              ActionChip(
                avatar: const Icon(Icons.history_edu_rounded, size: 14),
                label: Text(sessionName),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: () =>
                    ReadThroughSelectorSheet.show(context, bookId: bookId),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.items.length} Pending Candidates',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.history_edu_rounded, size: 14),
                label: Text(sessionName),
                labelStyle: const TextStyle(fontSize: 11),
                onPressed: () =>
                    ReadThroughSelectorSheet.show(context, bookId: bookId),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _ReviewItemCard(
                item: item,
                onConfirm: () => controller.confirmEntity(item),
                onReject: () => controller.rejectCandidate(item),
                onMerge: () => controller.mergeAlias(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.onConfirm,
    required this.onReject,
    required this.onMerge,
  });

  final ReviewItem item;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isMerge = item.type == ReviewType.mergeCandidates;
    final typeLabel = switch (item.type) {
      ReviewType.newEntity => 'New Entity Candidate',
      ReviewType.mergeCandidates => 'Alias Merge Candidate',
      ReviewType.relationship => 'Relationship Verification',
    };

    final confidencePct = (item.confidenceScore * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$confidencePct% conf',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Ch. ${item.chapterIndex}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.candidateName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isMerge && item.targetName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Merge into: ${item.targetName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.similarityScore != null)
                  Text(
                    '${(item.similarityScore! * 100).toInt()}% match',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            ...item.evidence.take(2).map(
                  (snippet) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.micro),
                    child: Text(
                      '• "$snippet"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isMerge) ...[
                AppButton.text(
                  label: 'Dismiss',
                  onPressed: onReject,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton.secondary(
                  label: 'Separate',
                  onPressed: onConfirm,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton.primary(
                  label: 'Merge',
                  icon: const Icon(Icons.call_merge, size: 16),
                  onPressed: onMerge,
                ),
              ] else ...[
                AppButton.secondary(
                  label: 'Reject',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onReject,
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton.primary(
                  label: 'Confirm',
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: onConfirm,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

