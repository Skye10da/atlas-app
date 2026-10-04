import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/design_system/atoms/app_button.dart';
import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/intelligence/domain/entities/read_through.dart';
import 'package:atlas_app/intelligence/presentation/providers/intelligence_providers.dart';

/// Modal bottom sheet allowing readers to manage multiple reading sessions (read-throughs)
/// for a novel with 100% memory and spoiler isolation.
class ReadThroughSelectorSheet extends HookConsumerWidget {
  const ReadThroughSelectorSheet({
    super.key,
    required this.bookId,
  });

  final String bookId;

  static void show(BuildContext context, {required String bookId}) {
    AppSheet.show(
      context: context,
      id: 'read_through_selector_$bookId',
      title: 'Reading Sessions & Memories',
      initialHeight: 0.70,
      child: ReadThroughSelectorSheet(bookId: bookId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = ref.watch(readThroughControllerProvider(bookId));
    final controller = ref.read(readThroughControllerProvider(bookId).notifier);

    return state.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: AppLoading(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load read-throughs: $e'),
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(
                label: 'Retry',
                onPressed: controller.refresh,
              ),
            ],
          ),
        ),
      ),
      data: (readThroughs) {
        return Column(
          children: [
            // Informational header banner
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Each session maintains an isolated story memory graph and spoiler boundary.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Read-through list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: readThroughs.length,
                itemBuilder: (context, index) {
                  final rt = readThroughs[index];
                  final isPrimary = rt.id == 'default';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: rt.isActive
                        ? cs.primaryContainer.withValues(alpha: 0.35)
                        : cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.borderRadiusMd),
                      side: BorderSide(
                        color: rt.isActive
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.4),
                        width: rt.isActive ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: rt.isActive
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        foregroundColor:
                            rt.isActive ? cs.onPrimary : cs.onSurfaceVariant,
                        child: Icon(
                          rt.isActive
                              ? Icons.auto_stories_rounded
                              : Icons.book_outlined,
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              rt.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: rt.isActive
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rt.isActive) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Progress: Chapter ${rt.currentChapter}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!rt.isActive)
                            TextButton(
                              onPressed: () => controller.switchActive(rt.id),
                              child: const Text('Switch'),
                            ),
                          if (!isPrimary)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              color: cs.error,
                              tooltip: 'Delete session',
                              onPressed: () => _showDeleteConfirmation(
                                context,
                                rt: rt,
                                onDelete: () => controller.delete(rt.id),
                              ),
                            ),
                        ],
                      ),
                      onTap: rt.isActive
                          ? null
                          : () => controller.switchActive(rt.id),
                    ),
                  );
                },
              ),
            ),

            // Start new read-through button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: 'Start New Read-Through',
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => _showCreateDialog(
                    context,
                    suggestedIndex: readThroughs.length + 1,
                    onCreate: (name, copyFromDefault) => controller.createNew(
                      name: name,
                      copyFromDefault: copyFromDefault,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog(
    BuildContext context, {
    required int suggestedIndex,
    required Future<ReadThrough?> Function(String name, bool copyFromDefault)
        onCreate,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _CreateReadThroughDialog(
          suggestedIndex: suggestedIndex,
          onCreate: onCreate,
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context, {
    required ReadThrough rt,
    required VoidCallback onDelete,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        return AlertDialog(
          title: const Text('Delete Read-Through?'),
          content: Text(
            'Are you sure you want to delete "${rt.name}"? All isolated story memory, entity graphs, and timeline events for this session will be permanently erased.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _CreateReadThroughDialog extends HookWidget {
  const _CreateReadThroughDialog({
    required this.suggestedIndex,
    required this.onCreate,
  });

  final int suggestedIndex;
  final Future<ReadThrough?> Function(String name, bool copyFromDefault)
      onCreate;

  @override
  Widget build(BuildContext context) {
    final nameController =
        useTextEditingController(text: 'Re-Read #$suggestedIndex');
    final copyCanon = useState(true);
    final isSubmitting = useState(false);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('New Reading Session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Session Name',
                hintText: 'e.g. Re-read 2026',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clone Canon Codex'),
              subtitle: Text(
                'Copy confirmed characters, factions, and relationships from Primary Read into this new session.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: copyCanon.value,
              onChanged: (val) => copyCanon.value = val,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isSubmitting.value
              ? null
              : () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  isSubmitting.value = true;
                  await onCreate(name, copyCanon.value);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: isSubmitting.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
