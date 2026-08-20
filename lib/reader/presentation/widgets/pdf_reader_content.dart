import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_password_dialog.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_reader_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_settings_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// Renders an imported PDF (format == 'pdf') using pdfrx's [PdfViewer].
///
/// Unlike the chapter-based reader, PDFs keep their original pages and render
/// through PDFium. Progress is stored as page / total pages (position = page)
/// so the library's progress bar and "Continue Reading" keep working.
class PdfReaderContent extends ConsumerStatefulWidget {
  const PdfReaderContent({
    super.key,
    required this.bookId,
    required this.pdfPath,
    this.initialPageNumber,
  });

  final String bookId;
  final String pdfPath;

  /// When opening from a chapter/toc entry, jump to this 1-based page instead
  /// of the saved reading position. Null falls back to saved progress.
  final int? initialPageNumber;

  @override
  ConsumerState<PdfReaderContent> createState() => _PdfReaderContentState();
}

const _invertFilter = ColorFilter.matrix(
  [
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ],
);

const _identityFilter = ColorFilter.mode(Colors.white, BlendMode.dst);

class _PdfReaderContentState extends ConsumerState<PdfReaderContent> {
  final _controller = PdfViewerController();
  Timer? _saveDebounce;

  PdfDocument? _document;
  PdfTextSearcher? _textSearcher;
  List<PdfOutlineNode>? _outline;

  bool _progressLoaded = false;
  int _startPage = 1;
  int _currentPage = 0;
  int _totalPages = 0;

  bool _showPanel = false;
  PdfReaderLayoutMode _layoutMode = PdfReaderLayoutMode.facing;

  final _markers = <int, List<PdfMarker>>{};
  final _notes = <int, List<PdfNoteEntry>>{};
  List<PdfPageTextRange> _selection = const [];

  String? _bookLanguage;
  String? _bookTitle;

  final _selectionSpeaker = const SelectionSpeaker();

  bool _controllerListenerAdded = false;

  @override
  void initState() {
    super.initState();
    _loadBookMeta();
    _loadStartPage();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _textSearcher?.dispose();
    if (_controllerListenerAdded) {
      _controller.removeListener(_onControllerChanged);
    }
    super.dispose();
  }

  Future<void> _loadBookMeta() async {
    final repo = DriftReaderRepository(ref.read(databaseProvider));
    final bookResult = await repo.getBookById(widget.bookId);
    if (bookResult is Success<BookEntity>) {
      _bookLanguage = bookResult.value.language;
      _bookTitle = bookResult.value.title;
    }
  }

  Future<void> _loadStartPage() async {
    if (widget.initialPageNumber != null && widget.initialPageNumber! > 0) {
      _startPage = widget.initialPageNumber!;
    } else {
      final repo = DriftReaderRepository(ref.read(databaseProvider));
      try {
        final progressResult = await repo.getReadingProgress(widget.bookId);
        if (progressResult is Success<ReadingProgressSnapshot?> &&
            progressResult.value != null &&
            progressResult.value!.position > 0) {
          _startPage = progressResult.value!.position;
        }
      } catch (_) {
        _startPage = 1;
      }
    }
    if (!mounted) return;
    setState(() => _progressLoaded = true);
  }

  // ------------------------------------------------------------ viewer io

  Future<void> _onViewerReady(PdfDocument document, PdfViewerController controller) async {
    var pageCount = 0;
    try {
      pageCount = document.pages.length;
    } catch (_) {}

    _textSearcher?.dispose();
    final searcher = PdfTextSearcher(controller)..addListener(_onSearchChanged);
    _textSearcher = searcher;
    if (!_controllerListenerAdded) {
      _controller.addListener(_onControllerChanged);
      _controllerListenerAdded = true;
    }

    List<PdfOutlineNode>? outline;
    try {
      outline = await document.loadOutline();
    } catch (_) {
      outline = null;
    }

    if (!mounted) return;
    setState(() {
      _document = document;
      _outline = outline;
      _totalPages = pageCount;
      if (_startPage > _totalPages && _totalPages > 0) {
        _startPage = _totalPages;
      }
      _currentPage = _totalPages > 0 ? _startPage : 0;
    });
  }

  void _onDocumentChanged(PdfDocument? document) {
    if (document == null) {
      _textSearcher?.dispose();
      _textSearcher = null;
      _outline = null;
      _document = null;
      _markers.clear();
      _notes.clear();
      _selection = const [];
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    final page = _controller.pageNumber;
    if (page != null && page > 0) {
      _onPageChanged(page);
    }
  }

  void _onPageChanged(int? page) {
    if (!mounted || _totalPages == 0) return;
    final target = ((page ?? _currentPage).clamp(1, _totalPages)).toInt();
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _saveProgress);
  }

  // ------------------------------------------------------------- actions

  Future<void> _goToPage(int pageNumber) async {
    if (_totalPages == 0) return;
    final target = pageNumber.clamp(1, _totalPages);
    await _controller.goToPage(pageNumber: target);
    _onPageChanged(target);
  }

  void _zoomIn() {
    if (_controller.isReady) _controller.zoomUp();
  }

  void _zoomOut() {
    if (_controller.isReady) _controller.zoomDown();
  }

  void _toggleLayoutMode() {
    setState(() {
      _layoutMode = switch (_layoutMode) {
        PdfReaderLayoutMode.single => PdfReaderLayoutMode.continuous,
        PdfReaderLayoutMode.continuous => PdfReaderLayoutMode.facing,
        PdfReaderLayoutMode.facing => PdfReaderLayoutMode.single,
      };
    });
    _controller.invalidate();
  }

  void _deleteMarker(PdfMarker marker) {
    setState(() {
      final list = _markers[marker.range.pageNumber];
      list?.remove(marker);
      if (list?.isEmpty ?? false) {
        _markers.remove(marker.range.pageNumber);
      }
    });
  }

  void _goToMarker(PdfMarker marker) {
    if (!_controller.isReady) return;
    final rect = _controller.calcRectForRectInsidePage(
      pageNumber: marker.range.pageNumber,
      rect: marker.range.bounds,
    );
    _controller.ensureVisible(rect);
  }

  void _goToNote(PdfNoteEntry note) {
    _goToPage(note.pageNumber);
  }

  void _deleteNote(PdfNoteEntry note) {
    setState(() {
      final list = _notes[note.pageNumber];
      list?.remove(note);
      if (list?.isEmpty ?? false) {
        _notes.remove(note.pageNumber);
      }
    });
  }

  void _goToOutlineNode(PdfOutlineNode node) {
    final dest = node.dest;
    if (dest != null) _controller.goToDest(dest);
  }

  Future<void> _onTextSelectionChange(PdfTextSelection selection) async {
    final ranges = await selection.getSelectedTextRanges();
    if (!mounted) return;
    setState(() => _selection = ranges);
  }

  static const _highlightPalette = [
    AppContextMenuHighlightOption(color: Color(0xFFFFF176), label: 'Yellow'),
    AppContextMenuHighlightOption(color: Color(0xFFA5D6A7), label: 'Green'),
    AppContextMenuHighlightOption(color: Color(0xFF90CAF9), label: 'Blue'),
    AppContextMenuHighlightOption(color: Color(0xFFF48FB1), label: 'Pink'),
    AppContextMenuHighlightOption(color: Color(0xFFCE93D8), label: 'Purple'),
  ];

  Widget? _buildContextMenu(BuildContext context, PdfViewerContextMenuBuilderParams params) {
    if (!params.isTextSelectionEnabled) return null;
    final delegate = params.textSelectionDelegate;
    if (!delegate.hasSelectedText) return null;

    return AppContextMenu(
      externallyPositioned: true,
      anchor: Offset.zero,
      highlightColors: _highlightPalette,
      onHighlightSelected: _applyHighlightForSelection,
      quickActions: [
        AppContextMenuAction(
          label: 'Copy',
          icon: Icons.content_copy_rounded,
          onPressed: delegate.copyTextSelection,
        ),
        AppContextMenuAction(
          label: 'Note',
          icon: Icons.edit_note_rounded,
          onPressed: _addNoteForSelection,
        ),
        AppContextMenuAction(
          label: 'Listen',
          icon: Icons.play_circle_outline_rounded,
          onPressed: () => _listenToSelection(params),
        ),
      ],
      listActions: [
        AppContextMenuAction(
          label: 'Look up',
          icon: Icons.translate_rounded,
          onPressed: () => _lookupSelection(params),
        ),
        if (_selection.any(_hasOverlappingMarker))
          AppContextMenuAction(
            label: 'Erase highlight',
            icon: Icons.format_color_reset_rounded,
            destructive: true,
            onPressed: _eraseSelection,
          ),
        AppContextMenuAction(
          label: 'Select all',
          icon: Icons.select_all_rounded,
          onPressed: delegate.selectAllText,
        ),
      ],
      onDismiss: params.dismissContextMenu,
    );
  }

  bool _hasOverlappingMarker(PdfPageTextRange range) {
    final markers = _markers[range.pageNumber];
    if (markers == null) return false;
    return markers.any(
      (m) =>
          m.range.pageNumber == range.pageNumber &&
          m.range.start < range.end &&
          m.range.end > range.start,
    );
  }

  Future<String> _selectedText(PdfViewerContextMenuBuilderParams params) async {
    try {
      return await params.textSelectionDelegate.getSelectedText();
    } catch (_) {
      return _selection.map((r) => r.text).join();
    }
  }

  void _applyHighlightForSelection(Color color) {
    if (!mounted) return;
    setState(() {
      for (final range in _selection) {
        _markers
            .putIfAbsent(range.pageNumber, () => [])
            .add(PdfMarker(range, color));
      }
      _selection = const [];
    });
  }

  void _eraseSelection() {
    setState(() {
      for (final range in _selection) {
        final markers = _markers[range.pageNumber];
        if (markers == null) continue;
        markers.removeWhere(
          (m) => m.range.start < range.end && m.range.end > range.start,
        );
        if (markers.isEmpty) _markers.remove(range.pageNumber);
      }
      _selection = const [];
    });
  }

  Future<void> _addNoteForSelection() async {
    if (_selection.isEmpty || !mounted) return;
    final first = _selection.first;
    final snippet = _selection.map((r) => r.text).join().trim();
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add note'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your note…',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || !mounted) return;
    final page = first.pageNumber;
    setState(() {
      _notes.putIfAbsent(page, () => []).add(
            PdfNoteEntry(
              pageNumber: page,
              snippet: snippet,
              text: result.trim(),
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  Future<void> _listenToSelection(PdfViewerContextMenuBuilderParams params) async {
    final text = await _selectedText(params);
    if (text.isEmpty || !mounted) return;
    await _selectionSpeaker.speak(
      ref: ref,
      bookId: widget.bookId,
      chapterId: 'pdf',
      text: text,
      language: _bookLanguage ?? 'en',
    );
    if (_selection.isNotEmpty) {
      setState(() => _selection = const []);
    }
  }

  Future<void> _lookupSelection(PdfViewerContextMenuBuilderParams params) async {
    final raw = await _selectedText(params);
    if (!mounted) return;
    final word = raw.split(RegExp(r'\s+')).join(' ').trim();
    if (word.isEmpty) return;
await DraggableBottomSheet.show(
      context: context,
      id: 'word_lookup',
      initialHeight: 0.7,
      child: WordLookupSheet(
        word: word,
        initialLanguage: _bookLanguage ?? 'en',
        sourceSentence: null,
        sourceTitle: _bookTitle ?? 'Page $_currentPage of $_totalPages',
      ),
    );
  }

  void _onLinkTap(PdfLink link) {
    final url = link.url;
    if (url != null) {
      _openUrl(url);
    } else if (link.dest != null) {
      _controller.goToDest(link.dest);
    }
  }

  Future<void> _openUrl(Uri url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open link'),
        content: Text(
          'Open this link in your browser?\n\n$url',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await launchUrl(url);
    }
  }

  Future<void> _saveProgress() async {
    if (_totalPages <= 0) return;
    final repo = DriftReaderRepository(ref.read(databaseProvider));
    await repo.saveProgress(
      userId: 'local',
      bookId: widget.bookId,
      chapterId: 'pdf',
      percentage: _currentPage / _totalPages * 100,
      position: _currentPage,
      totalPositions: _totalPages,
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider).valueOrNull ?? const ReadingSettingsEntity();
    final colorScheme = Theme.of(context).colorScheme;
    final nightMode = colorScheme.brightness == Brightness.dark;
    final background = settings.theme.resolve(colorScheme).background;

    if (!_progressLoaded) {
      return Scaffold(backgroundColor: background, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        backgroundColor: background,
        foregroundColor: nightMode ? Colors.white : Colors.black87,
        toolbarHeight: kToolbarHeight,
        title: Text(
          _totalPages == 0
              ? 'Loading PDF…'
              : 'Page $_currentPage of $_totalPages',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (_totalPages > 0) ...[
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom out',
              onPressed: _zoomOut,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom in',
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: const Icon(Icons.pages),
              tooltip: 'Layout: ${_layoutMode.label}',
              onPressed: _toggleLayoutMode,
            ),
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Search, outline, pages & markers',
              onPressed: () => setState(() => _showPanel = !_showPanel),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Reading settings',
              onPressed: _showSettingsSheet,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _showPanel ? 300 : 0,
            child: _showPanel
                ? ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: 300,
                      child: SizedBox(width: 300, child: _buildPanel(nightMode)),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: ColorFiltered(
              colorFilter: nightMode ? _invertFilter : _identityFilter,
              child: _buildViewer(background, nightMode),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _totalPages > 0 ? _buildBottomBar(nightMode) : null,
    );
  }

  void _showSettingsSheet() {
    DraggableBottomSheet.show(
      context: context,
      id: 'pdf_reader_settings',
      initialHeight: 0.6,
      child: const PdfSettingsSheet(),
    );
  }

  Widget _buildPanel(bool nightMode) {
    return PdfReaderPanel(
      controller: _controller,
      document: _document,
      outline: _outline,
      textSearcher: _textSearcher,
      currentPage: _currentPage,
      markers: _allMarkers,
      notes: _allNotes,
      onOutlineSelected: _goToOutlineNode,
      onPageSelected: _goToPage,
      onMarkerSelected: _goToMarker,
      onMarkerDeleted: _deleteMarker,
      onNoteSelected: _goToNote,
      onNoteDeleted: _deleteNote,
      nightMode: nightMode,
    );
  }

  List<PdfMarker> get _allMarkers => _markers.values.expand((list) => list).toList();

  List<PdfNoteEntry> get _allNotes => _notes.values.expand((list) => list).toList();

  Widget _buildViewer(Color background, bool nightMode) {
    final horizontal = _layoutMode == PdfReaderLayoutMode.continuous;
    return PdfViewer.file(
      widget.pdfPath,
      controller: _controller,
      initialPageNumber: _startPage,
      passwordProvider: () => promptPdfPassword(context),
      params: PdfViewerParams(
        layoutPages: _layoutFor(_layoutMode),
        backgroundColor: background,
        scrollHorizontallyByMouseWheel: horizontal,
        pageAnchor: horizontal ? PdfPageAnchor.left : PdfPageAnchor.top,
        pageAnchorEnd: horizontal ? PdfPageAnchor.right : PdfPageAnchor.bottom,
        textSelectionParams: PdfTextSelectionParams(onTextSelectionChange: _onTextSelectionChange),
        buildContextMenu: _buildContextMenu,
        linkHandlerParams: PdfLinkHandlerParams(onLinkTap: _onLinkTap),
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              handleLinkTap(details.localPosition);
            },
            onDoubleTap: () {
              if (_controller.isReady) _controller.zoomUp(loop: true);
            },
            child: IgnorePointer(
              child: SizedBox(width: size.width, height: size.height),
            ),
          ),
          PdfViewerScrollThumb(
            controller: _controller,
            orientation: horizontal ? ScrollbarOrientation.bottom : ScrollbarOrientation.right,
            thumbSize: const Size(40, 25),
            thumbBuilder: (context, thumbSize, pageNumber, controller) => Container(
              color: nightMode ? Colors.white : Colors.black,
              child: Center(
                child: Text(
                  pageNumber?.toString() ?? '',
                  style: TextStyle(
                    color: nightMode ? Colors.black : Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => Center(
          child: CircularProgressIndicator(
            value: totalBytes != null && totalBytes > 0 ? bytesDownloaded / totalBytes : null,
          ),
        ),
        errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Failed to open this PDF document.'),
                const SizedBox(height: 4),
                Text(
                  '$error',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        pagePaintCallbacks: [
          _paintMarkers,
          if (_textSearcher != null) _textSearcher!.pageTextMatchPaintCallback,
        ],
        onDocumentChanged: _onDocumentChanged,
        onViewerReady: _onViewerReady,
        onPageChanged: _onPageChanged,
      ),
    );
  }

  PdfPageLayoutFunction? _layoutFor(PdfReaderLayoutMode mode) {
    return switch (mode) {
      PdfReaderLayoutMode.single => null,
      PdfReaderLayoutMode.continuous => _horizontalLayout,
      PdfReaderLayoutMode.facing => _facingLayout,
    };
  }

  PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (prev, page) => math.max(prev, page.height)) + params.margin * 2;
    final pageLayouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      pageLayouts.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(x, height));
  }

  PdfPageLayout _facingLayout(List<PdfPage> pages, PdfViewerParams params) {
    const int offset = 1;
    final width = pages.fold(0.0, (prev, page) => math.max(prev, page.width));
    final pageLayouts = <Rect>[];
    var y = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pos = i + offset;
      final isLeft = (pos & 1) == 0;
      final otherSide = (pos ^ 1) - offset;
      final h = (0 <= otherSide && otherSide < pages.length)
          ? math.max(page.height, pages[otherSide].height)
          : page.height;
      pageLayouts.add(
        Rect.fromLTWH(
          isLeft ? width + params.margin - page.width : params.margin * 2 + width,
          y + (h - page.height) / 2,
          page.width,
          page.height,
        ),
      );
      if ((pos & 1) == 1 || i + 1 == pages.length) {
        y += h + params.margin;
      }
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size((params.margin + width) * 2 + params.margin, y),
    );
  }

  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markers = _markers[page.pageNumber];
    if (markers == null || markers.isEmpty) return;
    for (final marker in markers) {
      final paint = Paint()
        ..color = marker.color.withAlpha(90)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        marker.range.bounds
            .toRect(page: page, scaledPageSize: pageRect.size)
            .translate(pageRect.left, pageRect.top),
        paint,
      );
    }
  }

  Widget _buildBottomBar(bool nightMode) {
    final color = nightMode ? Colors.white : Colors.black87;
    return BottomAppBar(
      color: nightMode ? const Color(0xFF121212) : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: color),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          ),
          Expanded(
            child: Slider(
              value: _currentPage.toDouble(),
              min: 1,
              max: math.max(1, _totalPages).toDouble(),
              activeColor: color,
              inactiveColor: color.withAlpha(96),
              onChanged: _totalPages > 1
                  ? (value) => setState(() => _currentPage = value.round().clamp(1, _totalPages))
                  : null,
              onChangeEnd: (value) => _goToPage(value.round()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: color),
            onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}