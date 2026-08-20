import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/content_acquisition/content_acquisition_engine.dart';
import 'package:atlas_app/core/content_acquisition/models/content_category.dart';
import 'package:atlas_app/core/content_acquisition/models/novel_model.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/services/import_service.dart';
import 'package:atlas_app/core/design_system/tokens/animation.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';
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
  final isWide = MediaQuery.of(context).size.width >= 900;

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

class _ImportUrlSheet extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<_ImportUrlSheet> createState() => _ImportUrlSheetState();
}

class _ImportUrlSheetState extends ConsumerState<_ImportUrlSheet>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _animController;
  bool _urlValid = false;
  _SheetStage _stage = _SheetStage.input;
  NovelModel? _preview;
  String? _error;
  bool _loading = false;
  bool _expanding = false;

  // File mode state
  List<int>? _fileBytes;
  String? _fileName;

  // Cover bytes fetched through the transport stack (Cloudflare-safe).
  Uint8List? _coverBytes;

  // Progress
  final _progress = ValueNotifier<double>(0);
  bool _progressDone = false;
  ImportOutcome? _outcome;
  Timer? _autoDismissTimer;
  String? _clipboardUrl;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _validate(widget.initialUrl!);
    }

    _checkClipboard();

    if (widget.previewModel != null) {
      _preview = widget.previewModel;
      _stage = _SheetStage.preview;
      _fetchCoverBytes(widget.previewModel!);
    } else if (widget.skipInputStage && widget.initialUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    _urlController.dispose();
    _focusNode.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final uri = Uri.tryParse(value);
    final valid = uri != null && uri.hasScheme && uri.hasAuthority;
    if (valid != _urlValid) setState(() => _urlValid = valid);
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == _urlController.text) return;
      final uri = Uri.tryParse(text);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        if (mounted) setState(() => _clipboardUrl = text);
      }
    } catch (_) {}
  }

  void _pasteFromClipboard() {
    if (_clipboardUrl == null) return;
    _urlController.text = _clipboardUrl!;
    _validate(_clipboardUrl!);
    setState(() => _clipboardUrl = null);
  }

  String get _fileModeTitle {
    return widget.title.isNotEmpty ? widget.title : 'Import from device';
  }

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf', 'atlas'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _error = 'Could not read file';
          _loading = false;
        });
        return;
      }
      _fileBytes = bytes;
      _fileName = file.name;

      final ext = _fileName!.toLowerCase();
      NovelModel model;
      if (ext.endsWith('.atlas')) {
        final service = ref.read(atlasSourceImportServiceProvider);
        model = await service.extractMetadata(bytes, file.name);
      } else if (ext.endsWith('.pdf')) {
        final service = ref.read(pdfImportServiceProvider);
        model = await service.extractMetadata(bytes, file.name);
      } else {
        final service = ref.read(libraryImportServiceProvider);
        model = await service.extractMetadata(bytes, file.name);
      }
      if (!mounted) return;
      setState(() {
        _preview = model;
        _stage = _SheetStage.preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to read file: $e';
        _loading = false;
      });
    }
  }

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

  // ── Stage transitions ──────────────────────────────────────────────────

  Future<void> _fetchMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final engine = ref.read(contentAcquisitionEngineProvider);
      final model = await engine.fetchMetadata(url);
      if (!mounted) return;
      setState(() {
        _preview = model;
        _stage = _SheetStage.preview;
        _loading = false;
      });
      _fetchCoverBytes(model);
    } on ImportException catch (e) {
      if (!mounted) return;
      final retryable = !e.message.contains('No source plugin');
      setState(() {
        _error = e.message;
        _loading = false;
        _retryable = retryable;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch metadata: $e';
        _loading = false;
        _retryable = true;
      });
    }
  }

  bool _retryable = false;

  /// Fetches the cover image bytes through the same transport stack used by
  /// the image pipeline (WebViewTransport → CookieTransport → HttpTransport)
  /// so Cloudflare-protected cover URLs load correctly. Runs in the background
  /// after the preview is shown — failures are silent and fall back to
  /// [Image.network].
  void _fetchCoverBytes(NovelModel model) {
    if (model.coverBytes != null) return;
    final url = model.coverUrl;
    if (url == null || url.isEmpty) return;
    final pipeline = ref.read(imagePipelineProvider);
    pipeline.transport
        .fetchBytes(Uri.parse(url))
        .then((bytes) {
          if (!mounted || bytes.isEmpty) return;
          setState(() => _coverBytes = Uint8List.fromList(bytes));
        })
        .catchError((_) {});
  }

  Future<void> _startImport() async {
    if (_preview == null) return;
    setState(() {
      _stage = _SheetStage.progress;
      _progress.value = 0;
      _progressDone = false;
    });
    _animController
      ..stop()
      ..duration = const Duration(milliseconds: 1200);
    unawaited(_animController.repeat());

    final engine = ref.read(contentAcquisitionEngineProvider);
    final url = widget.initialUrl ?? _urlController.text.trim();
    final future = widget.onImport != null
        ? widget.onImport!(
            _fileBytes,
            _fileName,
            url,
            (p) => _progress.value = p,
          )
        : engine.importAndSave(url, onProgress: (p) => _progress.value = p);

    try {
      final result = await future;
      if (!mounted) return;
      _animController
        ..stop()
        ..duration = const Duration(milliseconds: 600);
      await _animController.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _progressDone = true;
        _outcome = result;
      });
      _animController.duration = const Duration(milliseconds: 400);
      await _animController.forward(from: 0);
      if (!mounted) return;
      setState(() => _stage = _SheetStage.done);
      _autoDismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _stage == _SheetStage.done) {
          Navigator.of(context).pop();
        }
      });
    } on ImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _stage = _SheetStage.input;
        _retryable = false;
      });
    } on ImportRedirect catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'This page requires a browser to import. Try opening it in the browser tab.';
        _stage = _SheetStage.input;
        _retryable = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Import failed: $e';
        _stage = _SheetStage.input;
        _retryable = true;
      });
    }
  }

  String _progressStageLabel(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p < 0.3) return 'Resolving source…';
    if (p < 0.5) return 'Fetching metadata…';
    if (p < 0.8) return 'Downloading chapters…';
    if (p < 0.95) return 'Saving to library…';
    return 'Finalizing…';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dismissible =
        _stage == _SheetStage.input || _stage == _SheetStage.preview;

    return PopScope(
      canPop: dismissible,
      child: Align(
        alignment: widget.isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: widget.isDesktop
              ? const BoxConstraints(maxWidth: 480)
              : const BoxConstraints(),
          child: Material(
            color: cs.surfaceContainerLow,
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: widget.isDesktop
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
                  child: switch (_stage) {
                    _SheetStage.input => _buildInputStage(cs),
                    _SheetStage.preview => _buildPreviewStage(cs),
                    _SheetStage.progress => _buildProgressStage(cs),
                    _SheetStage.done => _buildDoneStage(cs),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stage 1: Input ─────────────────────────────────────────────────────

  Widget _buildInputStage(ColorScheme cs) {
    return switch (widget.mode) {
      ImportSheetMode.url => _buildUrlInputStage(cs),
      ImportSheetMode.file => _buildFileInputStage(cs),
      ImportSheetMode.combined => _buildCombinedInputStage(cs),
    };
  }

  /// The all-in-one input screen: URL field, file picker, and browse sources
  /// all on a single page. No mode switching — the user picks whichever path
  /// suits them.
  Widget _buildCombinedInputStage(ColorScheme cs) {
    final source = _detectSource(_urlController.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Bring a new story into your library — from the web, your files, or a curated source.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ── URL text field ─────────────────────────────────────────────
        TextField(
          controller: _urlController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'https://royalroad.com/fiction/...',
            labelText: 'Book or novel URL',
            prefixIcon: const Icon(Icons.link, size: 20),
            suffixIcon: _urlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _urlController.clear();
                      _validate('');
                      _focusNode.requestFocus();
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
          onChanged: (v) {
            _validate(v);
            setState(() {});
          },
          onSubmitted: _urlValid && !_loading ? (_) => _fetchMetadata() : null,
        ),
        if (_clipboardUrl != null && _urlController.text.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pasteFromClipboard,
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: cs.primary),
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
        ] else if (_urlController.text.isNotEmpty && _urlValid) ...[
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
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
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
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
                if (_retryable)
                  TextButton(
                    onPressed: _fetchMetadata,
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_error == null)
          SizedBox(
            height: AppSpacing.touchTarget,
            child: FilledButton(
              onPressed: _urlValid && !_loading ? _fetchMetadata : null,
              child: _loading
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
        // ── Divider: pick a file ──────────────────────────────────────
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
        // ── File picker ───────────────────────────────────────────────
        SizedBox(
          height: AppSpacing.touchTarget,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: _loading
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
        // ── Divider: browse sources ───────────────────────────────────
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
        // ── Browse sources link ───────────────────────────────────────
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

  Widget _buildFileInputStage(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: AppSpacing.md),
        Text(
          _fileModeTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pick an ebook, PDF, or Atlas package from your device',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
        if (_error != null) ...[
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
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
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
            onPressed: _loading ? null : _pickFile,
            child: _loading
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

  Widget _buildUrlInputStage(ColorScheme cs) {
    final source = _detectSource(_urlController.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Paste a URL to import a book or novel',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _urlController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            labelText: widget.labelText,
            prefixIcon: const Icon(Icons.link, size: 20),
            suffixIcon: _urlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _urlController.clear();
                      _validate('');
                      _focusNode.requestFocus();
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
          onChanged: (v) {
            _validate(v);
            setState(() {});
          },
          onSubmitted: _urlValid && !_loading ? (_) => _fetchMetadata() : null,
        ),
        if (_clipboardUrl != null && _urlController.text.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pasteFromClipboard,
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: cs.primary),
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
        ] else if (_urlController.text.isNotEmpty && _urlValid) ...[
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
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
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
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
                if (_retryable)
                  TextButton(
                    onPressed: _fetchMetadata,
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_error == null)
          SizedBox(
            height: AppSpacing.touchTarget,
            child: FilledButton(
              onPressed: _urlValid && !_loading ? _fetchMetadata : null,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.buttonLabel),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  // ── Stage 2: Preview ───────────────────────────────────────────────────

  Widget _buildPreviewStage(ColorScheme cs) {
    final novel = _preview;
    if (novel == null) return const SizedBox.shrink();
    const maxGenres = 5;
    final genres = novel.genres.take(maxGenres).toList();
    final overflowCount = novel.genres.length - maxGenres;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Import this ${novel.category == ContentCategory.novel ? 'novel' : 'book'}?',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            child: SizedBox(
              width: 100,
              height: 150,
              child: _buildCoverImage(novel, cs),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          novel.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (novel.author != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'by ${novel.author}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
        _buildMetadataRow(novel, cs),
        if (novel.description != null && novel.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    novel.description!,
                    maxLines: _expanding ? null : 3,
                    overflow: _expanding ? null : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (novel.description!.length > 120)
                    GestureDetector(
                      onTap: () =>
                          setLocalState(() => _expanding = !_expanding),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          _expanding ? 'Show less' : 'Show more',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: cs.primary),
                        ),
                      ),
                    ),
                ],
              );
            },
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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: AppSpacing.touchTarget,
          child: FilledButton(
            onPressed: _startImport,
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
            onPressed: () => setState(() {
              _stage = _SheetStage.input;
              _error = null;
            }),
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(NovelModel novel, ColorScheme cs) {
    final items = <Widget>[];
    if (novel.rating != null) {
      items.add(_metadataItem(Icons.star_rounded, '${novel.rating}', cs));
    }
    if (novel.chapterCount > 0) {
      items.add(
        _metadataItem(Icons.book_outlined, '${novel.chapterCount} ch', cs),
      );
    }
    if (novel.language != null) {
      items.add(_metadataItem(Icons.language, novel.language!, cs));
    }
    if (novel.status != null) {
      items.add(_metadataItem(Icons.info_outline, novel.status!, cs));
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

  Widget _metadataItem(IconData icon, String text, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.book,
        size: 40,
        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildCoverImage(NovelModel novel, ColorScheme cs) {
    final bytes = _coverBytes ?? novel.coverBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverPlaceholder(cs),
      );
    }
    if (novel.coverUrl != null) {
      return Image.network(
        novel.coverUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverPlaceholder(cs),
      );
    }
    return _coverPlaceholder(cs);
  }

  // ── Stage 3: Progress ──────────────────────────────────────────────────

  Widget _buildProgressStage(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(),
        const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
        AnimatedBuilder(
          animation: Listenable.merge([_animController, _progress]),
          builder: (_, _) {
            final real = _progress.value;
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
                        progress: _animController.value,
                        done: _progressDone,
                        color: _progressDone
                            ? const Color(0xFF34C759)
                            : Theme.of(context).colorScheme.primary,
                        size: 72,
                      ),
                      Text(
                        _progressDone ? '100%' : '$percent%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _progressDone
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
                  _progressDone ? 'Done' : _progressStageLabel(_progress.value),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Stage 4: Done ──────────────────────────────────────────────────────

  Widget _buildDoneStage(ColorScheme cs) {
    final isNovel = _preview?.category == ContentCategory.novel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            '"${_preview?.title ?? 'Your item'}" is now in your library.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: AppSpacing.touchTarget,
          child: FilledButton(
            onPressed: () {
              _autoDismissTimer?.cancel();
              Navigator.of(context).pop(_outcome);
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
              _autoDismissTimer?.cancel();
              Navigator.of(context).pop();
            },
            child: const Text('Stay in library'),
          ),
        ),
      ],
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
