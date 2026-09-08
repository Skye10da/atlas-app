import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/design_system/tokens/animation.dart';
import 'package:atlas_app/core/design_system/tokens/breakpoints.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
import 'package:atlas_app/core/import/file_open_providers.dart';
import 'package:atlas_app/library/presentation/providers/library_provider.dart';
import 'package:atlas_app/library/presentation/widgets/import_progress_dialog.dart'
    show ProgressPainter;

enum _SheetStage { input, preview, progress, done }

/// Determines what the input stage renders.
///
/// * [url] — a URL text field only (used by the browser import).
/// * [file] — a file picker button only.
/// * [combined] — URL field, file picker, and browse-sources link all on one
///   screen (used by the library's all-in-one "Add to library" sheet).
enum ImportSheetMode { url, file, combined }

/// Shows the unified import bottom sheet.
///
/// Returns [ImportOutcome] on success, or null if the user cancelled.
/// When [mode] is [ImportSheetMode.url], a URL text field is shown.
/// When [mode] is [ImportSheetMode.file], a file picker button is shown.
/// When [mode] is [ImportSheetMode.combined], a URL field, file picker, and
/// browse-sources link are all rendered on the same input screen.
/// When [initialUrl] is provided the input field is pre-filled.
/// When [skipInputStage] is true the sheet jumps directly to preview
/// (requires [initialUrl] or [previewModel]).
/// When [previewModel] is provided the preview stage is pre-populated
/// without an extra metadata fetch.
/// When [onImport] is provided it is called instead of the engine's
/// default import (used by the browser for WebView routing, or for
/// local file imports). For file modes the callback receives the picked
/// [List<int> bytes] and [String fileName]; for URL mode they are null
/// and the callback receives the URL instead.
Future<ImportOutcome?> showImportUrlSheet(
  BuildContext context, {
  ImportSheetMode mode = ImportSheetMode.url,
  String title = 'Import from link',
  String labelText = 'URL',
  String hintText = 'https://royalroad.com/fiction/...',
  String buttonLabel = 'Import',
  String? initialUrl,
  bool skipInputStage = false,
  NovelModel? previewModel,
  Future<ImportOutcome> Function(
    List<int>? bytes,
    String? fileName,
    String? url,
    void Function(double) onProgress,
  )?
  onImport,
}) {
  final isWide = AppBreakpoints.isWide(context);

  return showGeneralDialog<ImportOutcome>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, _, child) {
      if (isWide) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          ),
        );
      }
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
    pageBuilder: (context, _, _) => _ImportUrlSheet(
      mode: mode,
      title: title,
      labelText: labelText,
      hintText: hintText,
      buttonLabel: buttonLabel,
      initialUrl: initialUrl,
      skipInputStage: skipInputStage,
      previewModel: previewModel,
      onImport: onImport,
      isDesktop: isWide,
    ),
  );
}

class _ImportUrlSheet extends HookConsumerWidget {
  const _ImportUrlSheet({
    required this.mode,
    required this.title,
    required this.labelText,
    required this.hintText,
    required this.buttonLabel,
    this.initialUrl,
    this.skipInputStage = false,
    this.previewModel,
    this.onImport,
    this.isDesktop = false,
  });

  final ImportSheetMode mode;
  final String title;
  final String labelText;
  final String hintText;
  final String buttonLabel;
  final String? initialUrl;
  final bool skipInputStage;
  final NovelModel? previewModel;
  final Future<ImportOutcome> Function(
    List<int>? bytes,
    String? fileName,
    String? url,
    void Function(double) onProgress,
  )?
  onImport;
  final bool isDesktop;

  String? _detectSource(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    const knownSources = {
      'royalroad.com': 'Royal Road',
      'www.mvlempyr.io': 'MVLEMPYR',
      'freewebnovel.com': 'FreeWebNovel',
      'readnovelfull.com': 'ReadNovelFull',
      'allnovelfull.net': 'AllNovelFull',
      'novgo.net': 'AllNovelFull',
      'novelfull.net': 'NovelFull',
      'noveldrama.org': 'NovelDrama',
      'live.mangabooth.com': 'Novel Hub',
      'wtr-lab.com': 'WTR-LAB',
      'gutenberg.org': 'Project Gutenberg',
      'www.gutenberg.org': 'Project Gutenberg',
      'openlibrary.org': 'Open Library',
      'www.openlibrary.org': 'Open Library',
      'publicdomainlibrary.org': 'Public Domain Library',
      'www.publicdomainlibrary.org': 'Public Domain Library',
    };
    for (final entry in knownSources.entries) {
      if (host == entry.key || host.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
    return null;
  }

  String _progressStageLabel(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p < 0.3) return 'Resolving source…';
    if (p < 0.5) return 'Fetching metadata…';
    if (p < 0.8) return 'Downloading chapters…';
    if (p < 0.95) return 'Saving to library…';
    return 'Finalizing…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlController = useTextEditingController(text: initialUrl ?? '');
    final focusNode = useFocusNode();
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    final urlValid = useState(false);
    final stage = useState(previewModel != null ? _SheetStage.preview : _SheetStage.input);
    final preview = useState<NovelModel?>(previewModel);
    final error = useState<String?>(null);
    final loading = useState(false);
    final retryable = useState(false);
    final expanding = useState(false);

    final fileBytes = useState<List<int>?>(null);
    final fileName = useState<String?>(null);
    final coverBytes = useState<Uint8List?>(null);

    final progress = useValueNotifier<double>(0);
    final progressDone = useState(false);
    final outcome = useState<ImportOutcome?>(null);
    final autoDismissTimer = useRef<Timer?>(null);
    final clipboardUrl = useState<String?>(null);

    void validate(String value) {
      final uri = Uri.tryParse(value);
      final valid = uri != null && uri.hasScheme && uri.hasAuthority;
      urlValid.value = valid;
    }

    void fetchCoverBytes(NovelModel model) {
      if (model.coverBytes != null) return;
      final url = model.coverUrl;
      if (url == null || url.isEmpty) return;
      final pipeline = ref.read(imagePipelineProvider);
      pipeline.transport
          .fetchBytes(Uri.parse(url))
          .then((bytes) {
            if (!context.mounted || bytes.isEmpty) return;
            coverBytes.value = Uint8List.fromList(bytes);
          })
          .catchError((_) {});
    }

    Future<void> fetchMetadata() async {
      final url = urlController.text.trim();
      if (url.isEmpty) return;
      loading.value = true;
      error.value = null;
      try {
        final engine = ref.read(contentAcquisitionEngineProvider);
        final model = await engine.fetchMetadata(url);
        if (!context.mounted) return;
        preview.value = model;
        stage.value = _SheetStage.preview;
        loading.value = false;
        fetchCoverBytes(model);
      } on ImportException catch (e) {
        if (!context.mounted) return;
        final isRetryable = !e.message.contains('No source plugin');
        error.value = e.message;
        loading.value = false;
        retryable.value = isRetryable;
      } catch (e) {
        if (!context.mounted) return;
        error.value = 'Failed to fetch metadata: $e';
        loading.value = false;
        retryable.value = true;
      }
    }

    bool isBotChallengeError(String? msg) {
      if (msg == null) return false;
      final lower = msg.toLowerCase();
      return lower.contains('bot-check challenge') || lower.contains('cloudflare');
    }

    Future<void> checkClipboard() async {
      try {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text?.trim();
        if (text == null || text.isEmpty || text == urlController.text) return;
        final uri = Uri.tryParse(text);
        if (uri != null && uri.hasScheme && uri.hasAuthority) {
          if (context.mounted) clipboardUrl.value = text;
        }
      } catch (_) {}
    }

    void pasteFromClipboard() {
      if (clipboardUrl.value == null) return;
      urlController.text = clipboardUrl.value!;
      validate(clipboardUrl.value!);
      clipboardUrl.value = null;
    }

    Future<void> pickFile() async {
      loading.value = true;
      error.value = null;
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['epub', 'pdf', 'atlas', 'txt', 'text', 'md', 'markdown'],
          allowMultiple: true,
          withData: true,
        );
        if (!context.mounted) return;
        if (result == null || result.files.isEmpty) {
          loading.value = false;
          return;
        }

        if (result.files.length > 1) {
          final importer = ref.read(openedFileImportServiceProvider);
          stage.value = _SheetStage.progress;
          progress.value = 0;
          progressDone.value = false;

          int importedCount = 0;
          final total = result.files.length;
          for (int i = 0; i < total; i++) {
            final file = result.files[i];
            final bytes = file.bytes;
            if (bytes != null) {
              progress.value = (i / total);
              await importer.importBytes(bytes, file.name);
              importedCount++;
            }
          }
          progress.value = 1.0;
          ref.invalidate(libraryBooksProvider);

          if (!context.mounted) return;
          progressDone.value = true;
          final res = ImportOutcome(
            bookId: 'batch:$importedCount',
            category: ContentCategory.book,
          );
          outcome.value = res;
          stage.value = _SheetStage.done;
          autoDismissTimer.value = Timer(const Duration(seconds: 3), () {
            if (context.mounted && stage.value == _SheetStage.done) {
              Navigator.of(context).pop(res);
            }
          });
          return;
        }

        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) {
          error.value = 'Could not read file';
          loading.value = false;
          return;
        }
        fileBytes.value = bytes;
        fileName.value = file.name;

        final ext = file.name.toLowerCase();
        NovelModel model;
        if (ext.endsWith('.atlas')) {
          final service = ref.read(atlasSourceImportServiceProvider);
          model = await service.extractMetadata(bytes, file.name);
        } else if (ext.endsWith('.pdf')) {
          final service = ref.read(pdfImportServiceProvider);
          model = await service.extractMetadata(bytes, file.name);
        } else if (ext.endsWith('.txt') ||
            ext.endsWith('.text') ||
            ext.endsWith('.md') ||
            ext.endsWith('.markdown')) {
          final service = ref.read(textImportServiceProvider);
          model = await service.extractMetadata(bytes, file.name);
        } else {
          final service = ref.read(libraryImportServiceProvider);
          model = await service.extractMetadata(bytes, file.name);
        }
        if (!context.mounted) return;
        preview.value = model;
        stage.value = _SheetStage.preview;
        loading.value = false;
      } catch (e) {
        if (!context.mounted) return;
        error.value = 'Failed to read file: $e';
        loading.value = false;
      }
    }

    Future<void> startImport() async {
      if (preview.value == null) return;
      stage.value = _SheetStage.progress;
      progress.value = 0;
      progressDone.value = false;

      animController
        ..stop()
        ..duration = const Duration(milliseconds: 1200);
      unawaited(animController.repeat());

      final engine = ref.read(contentAcquisitionEngineProvider);
      final url = initialUrl ?? urlController.text.trim();
      final future = onImport != null
          ? onImport!(
              fileBytes.value,
              fileName.value,
              url,
              (p) => progress.value = p,
            )
          : engine.importAndSave(url, onProgress: (p) => progress.value = p);

      try {
        final result = await future;
        if (!context.mounted) return;
        animController
          ..stop()
          ..duration = const Duration(milliseconds: 600);
        await animController.forward(from: 0);
        if (!context.mounted) return;
        progressDone.value = true;
        outcome.value = result;

        animController.duration = const Duration(milliseconds: 400);
        await animController.forward(from: 0);
        if (!context.mounted) return;
        stage.value = _SheetStage.done;
        autoDismissTimer.value = Timer(const Duration(seconds: 5), () {
          if (context.mounted && stage.value == _SheetStage.done) {
            Navigator.of(context).pop();
          }
        });
      } on ImportException catch (e) {
        if (!context.mounted) return;
        error.value = e.message;
        stage.value = _SheetStage.input;
        retryable.value = false;
      } on ImportRedirect catch (_) {
        if (!context.mounted) return;
        error.value =
            'This page requires a browser to import. Try opening it in the browser tab.';
        stage.value = _SheetStage.input;
        retryable.value = false;
      } catch (e) {
        if (!context.mounted) return;
        error.value = 'Import failed: $e';
        stage.value = _SheetStage.input;
        retryable.value = true;
      }
    }

    useEffect(() {
      animController.repeat();
      if (initialUrl != null) {
        validate(initialUrl!);
      }
      checkClipboard();

      if (previewModel != null) {
        fetchCoverBytes(previewModel!);
      } else if (skipInputStage && initialUrl != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => fetchMetadata());
      }

      return () {
        autoDismissTimer.value?.cancel();
      };
    }, const []);

    final cs = Theme.of(context).colorScheme;
    final dismissible =
        stage.value == _SheetStage.input || stage.value == _SheetStage.preview;

    Widget buildHandle() {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    Widget coverPlaceholder() {
      return Container(
        color: cs.surfaceContainerHighest,
        child: Icon(
          Icons.book,
          size: 40,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      );
    }

    Widget buildCoverImage(NovelModel novel) {
      final bytes = coverBytes.value ?? novel.coverBytes;
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => coverPlaceholder(),
        );
      }
      if (novel.coverUrl != null) {
        return Image.network(
          novel.coverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => coverPlaceholder(),
        );
      }
      return coverPlaceholder();
    }

    Widget metadataItem(IconData icon, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    Widget buildMetadataRow(NovelModel novel) {
      final items = <Widget>[];
      if (novel.rating != null) {
        items.add(metadataItem(Icons.star_rounded, '${novel.rating}'));
      }
      if (novel.chapterCount > 0) {
        items.add(metadataItem(Icons.book_outlined, '${novel.chapterCount} ch'));
      }
      if (novel.language != null) {
        items.add(metadataItem(Icons.language, novel.language!));
      }
      if (novel.status != null) {
        items.add(metadataItem(Icons.info_outline, novel.status!));
      }
      if (items.isEmpty) return const SizedBox.shrink();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            items[i],
          ],
        ],
      );
    }

    Widget buildPreviewStage() {
      final novel = preview.value;
      if (novel == null) return const SizedBox.shrink();
      const maxGenres = 5;
      final genres = novel.genres.take(maxGenres).toList();
      final overflowCount = novel.genres.length - maxGenres;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Import this ${novel.category == ContentCategory.novel ? 'novel' : 'book'}?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              child: SizedBox(
                width: 100,
                height: 150,
                child: buildCoverImage(novel),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            novel.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (novel.author != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'by ${novel.author}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: [
                for (final g in genres)
                  Chip(
                    label: Text(g),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: cs.secondaryContainer,
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                if (overflowCount > 0)
                  Chip(
                    label: Text('+$overflowCount'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: cs.tertiaryContainer,
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onTertiaryContainer,
                    ),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          buildMetadataRow(novel),
          if (novel.description != null && novel.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  novel.description!,
                  maxLines: expanding.value ? null : 3,
                  overflow: expanding.value ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (novel.description!.length > 120)
                  GestureDetector(
                    onTap: () => expanding.value = !expanding.value,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        expanding.value ? 'Show less' : 'Show more',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              ),
              child: Text(
                novel.source,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSpacing.touchTarget,
            child: FilledButton(
              onPressed: startImport,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Import now'),
                  SizedBox(width: AppSpacing.sm),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: AppSpacing.touchTarget,
            child: TextButton(
              onPressed: () {
                stage.value = _SheetStage.input;
                error.value = null;
              },
              child: const Text('Back'),
            ),
          ),
        ],
      );
    }

    Widget buildProgressStage() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
          AnimatedBuilder(
            animation: Listenable.merge([animController, progress]),
            builder: (_, _) {
              final real = progress.value;
              final percent = (real.clamp(0.0, 1.0) * 100).round();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ProgressPainter(
                          progress: animController.value,
                          done: progressDone.value,
                          color: progressDone.value
                              ? const Color(0xFF34C759)
                              : Theme.of(context).colorScheme.primary,
                          size: 72,
                        ),
                        Text(
                          progressDone.value ? '100%' : '$percent%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: progressDone.value
                                ? const Color(0xFF34C759)
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    progressDone.value ? 'Done' : _progressStageLabel(progress.value),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          ),
        ],
      );
    }

    Widget buildDoneStage() {
      final isNovel = preview.value?.category == ContentCategory.novel;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ProgressPainter(
                  progress: 1.0,
                  done: true,
                  color: Color(0xFF34C759),
                  size: 72,
                ),
                Icon(Icons.check, size: 36, color: Color(0xFF34C759)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isNovel ? 'Novel added!' : 'Book added!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              '"${preview.value?.title ?? 'Your item'}" is now in your library.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.touchTarget,
            child: FilledButton(
              onPressed: () {
                autoDismissTimer.value?.cancel();
                Navigator.of(context).pop(outcome.value);
              },
              child: Text(isNovel ? 'Open novel' : 'Open book'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.touchTarget,
            child: TextButton(
              onPressed: () {
                autoDismissTimer.value?.cancel();
                Navigator.of(context).pop();
              },
              child: const Text('Stay in library'),
            ),
          ),
        ],
      );
    }

    Widget buildCombinedInputStage() {
      final source = _detectSource(urlController.text);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bring a new story into your library — from the web, your files, or a curated source.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: urlController,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'https://royalroad.com/fiction/...',
              labelText: 'Book or novel URL',
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        urlController.clear();
                        validate('');
                        focusNode.requestFocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: validate,
            onSubmitted: urlValid.value && !loading.value ? (_) => fetchMetadata() : null,
          ),
          if (clipboardUrl.value != null && urlController.text.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: pasteFromClipboard,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.paste, size: 16, color: cs.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Paste from clipboard',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (source != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusFull,
                  ),
                ),
                child: Text(
                  source,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ] else if (urlController.text.isNotEmpty && urlValid.value) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusFull,
                  ),
                ),
                child: Text(
                  'Custom URL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          error.value!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  if (retryable.value || isBotChallengeError(error.value)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        if (retryable.value)
                          TextButton(
                            onPressed: fetchMetadata,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                    if (isBotChallengeError(error.value))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Silent solve failed for this site. Use the Browser Import button — it captures session cookies directly from the live page. Or import anyway and tap ‘Re-verify session’ in the reader if the book appears with missing chapters.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.85)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (error.value == null)
            SizedBox(
              height: AppSpacing.touchTarget,
              child: FilledButton(
                onPressed: urlValid.value && !loading.value ? fetchMetadata : null,
                child: loading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Import from URL'),
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    'or pick a file',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          SizedBox(
            height: AppSpacing.touchTarget,
            child: OutlinedButton.icon(
              onPressed: loading.value ? null : pickFile,
              icon: loading.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_rounded, size: 20),
              label: const Text('Pick file from device'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Supported: .epub, .pdf, .atlas',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    'or explore',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/sources');
            },
            icon: Icon(Icons.explore_rounded, size: 18, color: cs.primary),
            label: Text(
              'Browse curated sources',
              style: TextStyle(color: cs.primary),
            ),
          ),
        ],
      );
    }

    Widget buildFileInputStage() {
      final fileTitle = title.isNotEmpty ? title : 'Import from device';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(
            fileTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick an ebook, PDF, or Atlas package from your device',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: cs.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (error.value != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      error.value!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            height: AppSpacing.touchTarget,
            child: FilledButton(
              onPressed: loading.value ? null : pickFile,
              child: loading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_open, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Text('Pick file'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Supported: .epub, .pdf, .atlas files',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    Widget buildUrlInputStage() {
      final source = _detectSource(urlController.text);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Paste a URL to import a book or novel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: urlController,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        urlController.clear();
                        validate('');
                        focusNode.requestFocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: validate,
            onSubmitted: urlValid.value && !loading.value ? (_) => fetchMetadata() : null,
          ),
          if (clipboardUrl.value != null && urlController.text.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: pasteFromClipboard,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.paste, size: 16, color: cs.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Paste from clipboard',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (source != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusFull,
                  ),
                ),
                child: Text(
                  source,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ] else if (urlController.text.isNotEmpty && urlValid.value) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusFull,
                  ),
                ),
                child: Text(
                  'Custom URL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          error.value!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  if (retryable.value || isBotChallengeError(error.value)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        if (retryable.value)
                          TextButton(
                            onPressed: fetchMetadata,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                    if (isBotChallengeError(error.value))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Silent solve failed — use the Browser Import button (captures session cookies directly from the live page). If already imported, open the book and tap ‘Re-verify session’ in the reader.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.85)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (error.value == null)
            SizedBox(
              height: AppSpacing.touchTarget,
              child: FilledButton(
                onPressed: urlValid.value && !loading.value ? fetchMetadata : null,
                child: loading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(buttonLabel),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
        ],
      );
    }

    Widget buildInputStage() {
      return switch (mode) {
        ImportSheetMode.url => buildUrlInputStage(),
        ImportSheetMode.file => buildFileInputStage(),
        ImportSheetMode.combined => buildCombinedInputStage(),
      };
    }

    return PopScope(
      canPop: dismissible,
      child: Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: isDesktop
              ? const BoxConstraints(maxWidth: 480)
              : const BoxConstraints(),
          child: Material(
            color: cs.surfaceContainerLow,
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: isDesktop
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: AnimatedSize(
                duration: AppAnimation.medium,
                curve: AppAnimation.defaultCurve,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: switch (stage.value) {
                    _SheetStage.input => buildInputStage(),
                    _SheetStage.preview => buildPreviewStage(),
                    _SheetStage.progress => buildProgressStage(),
                    _SheetStage.done => buildDoneStage(),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
