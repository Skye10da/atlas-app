import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/design_system/molecules/confirm_delete_dialog.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/application/library_backup_service.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class DangerZoneScreen extends ConsumerWidget {
  const DangerZoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Danger Zone ⚠',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formContentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // 1. Warning Notice Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colors.onErrorContainer,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.smMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Irreversible Data Actions',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Actions on this screen permanently delete your content and reading history. Please proceed with caution.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onErrorContainer.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Safe Harbor: Export / Restore Backup First
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Library Backup & Restore',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Save your entire library, reading progress, bookmarks, and vocabulary into a portable JSON backup file.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('Restore Backup'),
                          onPressed: () => _restoreBackup(context, ref),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Export Backup'),
                          onPressed: () => _exportBackup(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Destructive Action: Delete All Books
              _DangerCard(
                icon: Icons.delete_sweep_rounded,
                title: 'Delete Entire Library',
                description: 'Permanently removes all ebooks, web novels, chapters, bookmarks, and reading history from this device.',
                buttonLabel: 'Delete All Books',
                onPressed: () => _confirmDeleteAllBooks(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Destructive Action: Delete All Novels
              _DangerCard(
                icon: Icons.auto_stories_rounded,
                title: 'Delete All Web Novels',
                description: 'Removes all downloaded online novels while keeping local EPUB and PDF files in your library.',
                buttonLabel: 'Delete Novels',
                onPressed: () => _confirmDeleteAllNovels(context, ref),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAllBooks(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Entire Library?',
      message: 'This will permanently remove all books, chapters, reading progress, and bookmarks. This action cannot be undone.',
      confirmLabel: 'Delete Everything',
    );
    if (confirmed == true && context.mounted) {
      await _deleteAllBooks(context, ref);
    }
  }

  Future<void> _deleteAllBooks(BuildContext context, WidgetRef ref) async {
    final deleteActions = ref.read(libraryDeleteProvider);
    final result = await deleteActions.deleteAll();
    if (!context.mounted) return;

    if (result is Success) {
      ref.invalidate(libraryBooksProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All books deleted.')));
    } else if (result is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result.error.userMessage}')),
      );
    }
  }

  Future<void> _confirmDeleteAllNovels(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete All Web Novels?',
      message: 'This will remove all downloaded web novels and chapter cache.',
      confirmLabel: 'Delete Novels',
    );
    if (confirmed == true && context.mounted) {
      await _deleteAllNovels(context, ref);
    }
  }

  Future<void> _deleteAllNovels(BuildContext context, WidgetRef ref) async {
    final deleteActions = ref.read(libraryDeleteProvider);
    final booksAsync = await ref.read(libraryBooksProvider.future);
    final novels = switch (booksAsync) {
      Success(value: final list) => list.where((b) => b.isNovel).toList(),
      Failure() => <BookEntity>[],
    };
    for (final novel in novels) {
      await deleteActions.delete(novel.id);
    }
    if (!context.mounted) return;
    ref.invalidate(libraryBooksProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All web novels deleted.')));
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);
    final path = await backupService.exportBackupToFile();
    if (!context.mounted) return;

    if (path != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Backup exported successfully:\n$path')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup export cancelled or failed.')),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);
    final result = await backupService.restoreBackupFromFile();
    if (!context.mounted) return;

    switch (result) {
      case Success(:final value):
        ref.invalidate(libraryBooksProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${value.booksRestored} books, ${value.bookmarksRestored} bookmarks, and ${value.wordsRestored} words.',
            ),
          ),
        );
      case Failure(:final error):
        messenger.showSnackBar(
          SnackBar(content: Text('Restore failed: ${error.userMessage}')),
        );
    }
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
