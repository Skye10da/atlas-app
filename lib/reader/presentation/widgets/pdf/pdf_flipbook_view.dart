import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:real_page_flip/real_page_flip.dart';

import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

/// Renders a PDF document using [real_page_flip]'s 3D-like [PageFlipWidget]
/// on top of [pdfrx]'s native hardware page rendering and selectable text layers.
class PdfFlipbookView extends StatefulWidget {
  const PdfFlipbookView({
    super.key,
    required this.bookId,
    required this.pdfPath,
    required this.initialPage,
    required this.isNightMode,
    required this.settings,
    required this.onPageChanged,
    required this.onTap,
    this.bookTitle,
    this.bookCoverPath,
    this.controller,
    this.onDocumentReady,
    this.onHighlight,
    this.onAddNote,
    this.onShare,
    this.onListen,
    this.onErase,
  });

  final String bookId;
  final String pdfPath;
  final int initialPage;
  final bool isNightMode;
  final ReadingSettingsEntity settings;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;
  final String? bookTitle;
  final String? bookCoverPath;
  final PageFlipController? controller;
  final void Function(PdfDocument document)? onDocumentReady;

  final void Function(int pageNumber, String text, Color color, int start, int end, {HighlightStyleType styleType})? onHighlight;
  final void Function(int pageNumber, String text, String? sentence)? onAddNote;
  final void Function(int pageNumber, String text)? onShare;
  final void Function(int pageNumber, String text, int start, int end)? onListen;
  final void Function(int pageNumber, int start, int end)? onErase;

  @override
  State<PdfFlipbookView> createState() => _PdfFlipbookViewState();
}

class _PdfFlipbookViewState extends State<PdfFlipbookView> {
  PdfDocument? _document;
  int _totalPages = 0;
  bool _loading = true;
  String? _error;
  late final PageFlipController _flipController;
  final Map<int, ui.Image> _renderedPageCache = {};
  final Map<int, String> _pageTextCache = {};
  final Set<int> _renderingPages = {};

  static const List<AppContextMenuHighlightOption> _highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFD54F), label: 'Sunset Gold'),
    AppContextMenuHighlightOption(color: Color(0xFF81C784), label: 'Emerald Mint'),
    AppContextMenuHighlightOption(color: Color(0xFF64B5F6), label: 'Sky Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFFF8A65), label: 'Coral Orange'),
    AppContextMenuHighlightOption(color: Color(0xFFF06292), label: 'Rose Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFBA68C8), label: 'Electric Violet'),
    AppContextMenuHighlightOption(color: Color(0xFFAEEA00), label: 'Neon Lime'),
    AppContextMenuHighlightOption(color: Color(0xFFFFB74D), label: 'Warm Amber'),
    AppContextMenuHighlightOption(color: Color(0xFF90A4AE), label: 'Slate Graphite'),
  ];

  @override
  void initState() {
    super.initState();
    _flipController = widget.controller ?? PageFlipController();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await PdfDocument.openFile(widget.pdfPath);
      if (!mounted) {
        await doc.dispose();
        return;
      }
      setState(() {
        _document = doc;
        _totalPages = doc.pages.length;
        _loading = false;
      });
      _preloadAdjacentPages(widget.initialPage);
      widget.onDocumentReady?.call(doc);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _preloadAdjacentPages(int pageNumber) {
    if (_document == null || _totalPages == 0) return;
    final pagesToWarm = <int>{
      pageNumber,
      if (pageNumber > 1) pageNumber - 1,
      if (pageNumber > 2) pageNumber - 2,
      if (pageNumber < _totalPages) pageNumber + 1,
      if (pageNumber < _totalPages - 1) pageNumber + 2,
      if (pageNumber < _totalPages - 2) pageNumber + 3,
      if (pageNumber < _totalPages - 3) pageNumber + 4,
    };

    for (final p in pagesToWarm) {
      _renderSinglePdfPage(p);
    }
  }

  Future<void> _renderSinglePdfPage(int pageNumber) async {
    if (_document == null ||
        pageNumber < 1 ||
        pageNumber > _totalPages ||
        _renderedPageCache.containsKey(pageNumber) ||
        _renderingPages.contains(pageNumber)) {
      return;
    }

    _renderingPages.add(pageNumber);
    try {
      final page = _document!.pages[pageNumber - 1];

      // Load plain text if not cached yet
      if (!_pageTextCache.containsKey(pageNumber)) {
        final textObj = await page.loadText();
        if (textObj != null && textObj.fullText.isNotEmpty) {
          _pageTextCache[pageNumber] = textObj.fullText;
        }
      }

      // Target 300+ DPI / Retina sharpness (2160-2880px width)
      final mediaWidth = mounted ? MediaQuery.sizeOf(context).width : 1080.0;
      final dpr = mounted ? MediaQuery.devicePixelRatioOf(context) : 2.0;
      final targetWidth = (mediaWidth * dpr).clamp(1800.0, 3200.0);
      final ratio = page.height / page.width;
      final pdfImg = await page.render(
        fullWidth: targetWidth,
        fullHeight: targetWidth * ratio,
      );
      if (pdfImg != null && mounted) {
        final img = await pdfImg.createImage();
        if (mounted) {
          setState(() {
            _renderedPageCache[pageNumber] = img;
          });
          _flipController.markPageDirty((pageNumber - 1), prewarm: true);
        } else {
          img.dispose();
        }
      }
    } catch (_) {
    } finally {
      _renderingPages.remove(pageNumber);
    }
  }

  @override
  void dispose() {
    for (final img in _renderedPageCache.values) {
      img.dispose();
    }
    _renderedPageCache.clear();
    _pageTextCache.clear();
    _document?.dispose();
    super.dispose();
  }

  EditableTextContextMenuBuilder _contextMenuBuilder(
    int pageNumber,
    String fullText,
  ) {
    return AppContextMenu.builder(
      build: (ctx, editable, anchor) {
        final sel = editable.textEditingValue.selection;
        final hasSelection = sel.isValid &&
            !sel.isCollapsed &&
            sel.start >= 0 &&
            sel.end <= fullText.length &&
            sel.start < sel.end;
        final word = hasSelection
            ? fullText.substring(sel.start, sel.end).trim()
            : '';
        final showSelectionActions = hasSelection && word.isNotEmpty;
        final start = hasSelection ? sel.start : 0;
        final end = hasSelection ? sel.end : 0;

        return AppContextMenu(
          anchor: anchor,
          highlightColors: showSelectionActions ? _highlightPalette : const [],
          initialStyle: HighlightStyleType.solid,
          onHighlightWithStyle: showSelectionActions && widget.onHighlight != null
              ? (color, style) => widget.onHighlight!(
                    pageNumber,
                    word,
                    color,
                    start,
                    end,
                    styleType: style,
                  )
              : null,
          quickActions: [
            AppContextMenuAction(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              onPressed: () {
                final text = editable.textEditingValue.text;
                final s = editable.textEditingValue.selection;
                if (s.isValid &&
                    !s.isCollapsed &&
                    s.start >= 0 &&
                    s.end <= text.length &&
                    s.start < s.end) {
                  final data = text.substring(s.start, s.end);
                  Clipboard.setData(ClipboardData(text: data));
                } else if (word.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: word));
                }
              },
            ),
            if (showSelectionActions && widget.onAddNote != null)
              AppContextMenuAction(
                label: 'Note',
                icon: Icons.edit_note_rounded,
                onPressed: () => widget.onAddNote!(pageNumber, word, word),
              ),
            if (showSelectionActions && widget.onShare != null)
              AppContextMenuAction(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: () => widget.onShare!(pageNumber, word),
              ),
            if (showSelectionActions && widget.onListen != null)
              AppContextMenuAction(
                label: 'Listen',
                icon: Icons.play_circle_outline_rounded,
                onPressed: () =>
                    widget.onListen!(pageNumber, word, start, end),
              ),
          ],
          listActions: [
            if (showSelectionActions)
              AppContextMenuAction(
                label: 'Look up "$word"',
                icon: Icons.translate_rounded,
                onPressed: () {
                  AppSheet.show(
                    context: ctx,
                    id: 'word_lookup',
                    initialHeight: 0.7,
                    child: WordLookupSheet(
                      word: word,
                      sourceSentence: word,
                      sourceTitle: 'Page $pageNumber',
                    ),
                  );
                },
              ),
            AppContextMenuAction(
              label: 'Select all',
              icon: Icons.select_all_rounded,
              onPressed: () => editable.selectAll(SelectionChangedCause.toolbar),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _document == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Failed to open PDF document.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 1200;
    final useDoubleSpread = isDesktop && widget.settings.useBookSpread;

    final count = useDoubleSpread
        ? ((_totalPages + 1) ~/ 2)
        : _totalPages;

    final initialIdx = useDoubleSpread
        ? ((widget.initialPage - 1) ~/ 2).clamp(0, count - 1)
        : (widget.initialPage - 1).clamp(0, count - 1);

    final supportsSound = !kIsWeb && !Platform.isWindows;
    final isEdgesOnly = widget.settings.pageFlipGestureZone == PageFlipGestureZone.edgesOnly;
    final edgeRatio = isEdgesOnly ? 0.20 : 0.08;
    final sensitivity = isEdgesOnly ? 0.30 : 0.50;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: PageFlipWidget(
        key: ValueKey('pdf_flip_${useDoubleSpread ? "spread" : "single"}_$_totalPages'),
        controller: _flipController,
        itemCount: count,
        initialIndex: initialIdx,
        spreadMode: useDoubleSpread
            ? PageFlipSpreadMode.doubleSpread
            : PageFlipSpreadMode.single,
        config: PageFlipConfig(
          enableSound: supportsSound && widget.settings.enablePageFlipSound,
          enableHaptics: widget.settings.enablePageFlipHaptics,
          edgeTapWidthRatio: edgeRatio,
          sensitivity: sensitivity,
          snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.always,
          performanceProfile: DevicePerformanceProfile.high,
          snapshotPerformanceProfile: DevicePerformanceProfile.high,
          maxSnapshotPixelRatio: 3.0,
          cutoffForward: 0.35,
          cutoffPrevious: 0.35,
        ),
        onPageChanged: (index) {
          final targetPage = useDoubleSpread ? (index * 2 + 1) : (index + 1);
          final clampedPage = targetPage.clamp(1, _totalPages);
          _preloadAdjacentPages(clampedPage);
          widget.onPageChanged(clampedPage);
        },
        itemBuilder: (context, index) {
          if (useDoubleSpread) {
            final leftPageNum = index * 2 + 1;
            final rightPageNum = leftPageNum + 1;
            return Row(
              children: [
                Expanded(
                  child: leftPageNum <= _totalPages
                      ? _buildPageWidget(leftPageNum)
                      : const SizedBox(),
                ),
                Container(
                  width: 1,
                  color: Colors.black12,
                ),
                Expanded(
                  child: rightPageNum <= _totalPages
                      ? _buildPageWidget(rightPageNum)
                      : const SizedBox(),
                ),
              ],
            );
          }

          return _buildPageWidget(index + 1);
        },
      ),
    );
  }

  Widget _buildPageWidget(int pageNumber) {
    final cached = _renderedPageCache[pageNumber];
    if (cached != null) {
      final text = _pageTextCache[pageNumber];

      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: RawImage(
              image: cached,
              fit: BoxFit.contain,
            ),
          ),
          if (text != null && text.isNotEmpty)
            Center(
              child: AspectRatio(
                aspectRatio: cached.width / cached.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.transparent,
                    ),
                    contextMenuBuilder: _contextMenuBuilder(pageNumber, text),
                    onTap: widget.onTap,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    _renderSinglePdfPage(pageNumber);
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
