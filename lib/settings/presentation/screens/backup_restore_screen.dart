import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/application/library_backup_service.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isArchive = true;
  bool _includeOfflineChapters = true;
  bool _includeAnalytics = true;
  bool _includeAnnotations = true;

  bool _isExporting = false;
  bool _isRestoring = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // 1. Info Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: colors.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Library Preservation',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Safeguard your entire library: books, web novels, exact chapter reading positions, bookmarks, notes, vocabulary, and offline chapter files.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Export Card
          _buildExportCard(context, colors, textTheme),
          const SizedBox(height: AppSpacing.lg),

          // 3. Restore Card
          _buildRestoreCard(context, colors, textTheme),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildExportCard(
    BuildContext context,
    ColorScheme colors,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                ),
                child: Icon(Icons.file_download_outlined, color: colors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Export Library Backup',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generate a self-contained archive or portable metadata file.',
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),

          // Format Selection (Segmented Button)
          Text(
            'Backup Package Format',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Full Package (.atlas)'),
                icon: Icon(Icons.folder_zip_outlined, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Metadata Only (.json)'),
                icon: Icon(Icons.code_rounded, size: 16),
              ),
            ],
            selected: {_isArchive},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _isArchive = newSelection.first;
              });
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _isArchive
                ? 'Includes all covers, offline chapter text, book files, and complete reading state. Fully self-contained.'
                : 'Lightweight JSON file containing all books, reading progress, exact positions, and sources.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Options Toggles
          if (_isArchive)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bundle Offline Chapters'),
              subtitle: const Text('Include cached chapter text files in the package'),
              value: _includeOfflineChapters,
              onChanged: _isExporting
                  ? null
                  : (val) => setState(() => _includeOfflineChapters = val),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include Highlights & Notes'),
            subtitle: const Text('Export reader annotations and colored highlights'),
            value: _includeAnnotations,
            onChanged: _isExporting
                ? null
                : (val) => setState(() => _includeAnnotations = val),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include Reading Analytics'),
            subtitle: const Text('Export reading sessions and chapter target goals'),
            value: _includeAnalytics,
            onChanged: _isExporting
                ? null
                : (val) => setState(() => _includeAnalytics = val),
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Buttons
          if (_isExporting)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _statusMessage ?? 'Preparing backup package...',
                  style: textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share'),
                  onPressed: () => _handleShare(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Save Backup File'),
                  onPressed: () => _handleExport(context),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard(
    BuildContext context,
    ColorScheme colors,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
                ),
                child: Icon(Icons.file_upload_outlined, color: colors.secondary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Restore Library Backup',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Import a previous Atlas backup (.atlas, .zip, or .json). Reading progress, exact chapter positions, and offline content will be seamlessly restored.',
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isRestoring)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _statusMessage ?? 'Restoring library...',
                  style: textTheme.bodySmall?.copyWith(color: colors.secondary),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.restore_page_outlined, size: 16),
                label: const Text('Select Backup to Restore'),
                onPressed: () => _handleRestore(context),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'Exporting backup...';
    });

    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);

    try {
      final path = await backupService.exportBackupToFile(
        isArchive: _isArchive,
        includeOfflineChapters: _includeOfflineChapters,
        includeAnalytics: _includeAnalytics,
        includeAnnotations: _includeAnnotations,
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = null;
        });

        if (path != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Backup exported successfully:\n$path'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Backup export cancelled or failed.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = null;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'Preparing backup for sharing...';
    });

    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final ext = _isArchive ? 'atlas' : 'json';
      final fileName = 'atlas_backup_$dateStr.$ext';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, fileName));

      if (_isArchive) {
        final bytes = await backupService.exportBackupArchive(
          includeOfflineChapters: _includeOfflineChapters,
          includeAnalytics: _includeAnalytics,
          includeAnnotations: _includeAnnotations,
        );
        await tempFile.writeAsBytes(bytes);
      } else {
        final jsonString = await backupService.exportBackupJson(
          includeAnalytics: _includeAnalytics,
          includeAnnotations: _includeAnnotations,
        );
        await tempFile.writeAsString(jsonString);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = null;
        });

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFile.path)],
            subject: 'Atlas Library Backup ($dateStr)',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = null;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to share backup: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);

    try {
      // Android's MimeTypeMap doesn't know .atlas, so FileType.custom with
      // ['atlas'] hides the files (greyed out). Use FileType.any on Android
      // to guarantee .atlas visibility; validate after pick. withData ensures
      // bytes are available when path is null (scoped storage / content://).
      final isAndroid = Platform.isAndroid;
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Atlas Backup File',
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : ['atlas', 'zip', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;

      List<int> bytes;
      String resolvedPath;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
        resolvedPath = picked.path ?? picked.name;
      } else if (picked.path != null) {
        final file = File(picked.path!);
        bytes = await file.readAsBytes();
        resolvedPath = file.path;
      } else {
        return;
      }

      final inspectionResult = await backupService.inspectBackupBytes(
        bytes,
        fileName: resolvedPath,
      );

      if (!context.mounted) return;

      switch (inspectionResult) {
        case Failure(:final error):
          messenger.showSnackBar(
            SnackBar(
              content: Text('Invalid backup file: ${error.userMessage}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        case Success(:final value):
          await _showInspectionDialog(context, value, bytes, resolvedPath);
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Restore selection failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showInspectionDialog(
    BuildContext context,
    BackupManifestSummary manifest,
    List<int> bytes,
    String filePath,
  ) async {
    bool cleanRestore = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            final colors = theme.colorScheme;
            final textTheme = theme.textTheme;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Backup Preview'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to restore from "${p.basename(filePath)}".',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Metadata Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statRow('Exported on', manifest.exportedAt.toLocal().toString().split('.').first),
                          _statRow('Books & Novels', '${manifest.booksCount} books, ${manifest.novelsCount} web novels'),
                          _statRow('Chapters', '${manifest.chaptersCount} chapters'),
                          _statRow('Reading Progress', '${manifest.readingProgressCount} books with saved positions'),
                          _statRow('Bookmarks', '${manifest.bookmarksCount} bookmarks'),
                          _statRow('Vocabulary', '${manifest.wordsCount} words'),
                          if (manifest.annotationsCount > 0)
                            _statRow('Annotations', '${manifest.annotationsCount} annotated books'),
                          _statRow('Offline Files', manifest.hasBundledFiles ? 'Bundled covers & chapters' : 'Metadata only'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Restore Mode Selector
                    Text(
                      'Restore Mode',
                      style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    RadioGroup<bool>(
                      groupValue: cleanRestore,
                      onChanged: (bool? val) {
                        if (val != null) {
                          setDialogState(() => cleanRestore = val);
                        }
                      },
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<bool>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Merge with Library'),
                            subtitle: Text('Updates existing items and adds new items'),
                            value: false,
                          ),
                          RadioListTile<bool>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Clean Replace'),
                            subtitle: Text('Replaces existing library with backup contents'),
                            value: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Restore Now'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    setState(() {
      _isRestoring = true;
      _statusMessage = 'Restoring library items and reading positions...';
    });

    final messenger = ScaffoldMessenger.of(context);
    final backupService = ref.read(libraryBackupServiceProvider);

    try {
      final restoreResult = await backupService.restoreBackupBytes(
        bytes,
        fileName: filePath,
        cleanRestore: cleanRestore,
      );

      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _statusMessage = null;
      });

      switch (restoreResult) {
        case Failure(:final error):
          messenger.showSnackBar(
            SnackBar(
              content: Text('Restore failed: ${error.userMessage}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        case Success(:final value):
          ref.invalidate(libraryBooksProvider);
          if (!context.mounted) return;
          await _showSuccessSummaryDialog(context, value);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusMessage = null;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Restore error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessSummaryDialog(
    BuildContext context,
    BackupRestoreSummary summary,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.check_circle_outline, color: colors.primary, size: 36),
          title: const Text('Restore Completed Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Books Restored', '${summary.booksRestored}'),
              _statRow('Web Novels', '${summary.novelsRestored}'),
              _statRow('Chapters', '${summary.chaptersRestored}'),
              _statRow('Reading Positions', '${summary.readingProgressRestored}'),
              _statRow('Bookmarks', '${summary.bookmarksRestored}'),
              _statRow('Characters', '${summary.charactersRestored}'),
              _statRow('Vocabulary', '${summary.wordsRestored}'),
              if (summary.annotationsRestored > 0)
                _statRow('Annotations', '${summary.annotationsRestored} books'),
              if (summary.filesRestored > 0)
                _statRow('Extracted Files', '${summary.filesRestored} files'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

