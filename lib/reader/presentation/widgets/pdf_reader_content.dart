import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/design_system/organisms/app_sheet.dart';
import 'package:atlas_app/core/design_system/widgets/app_context_menu.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';
import 'package:atlas_app/reader/presentation/controllers/reader_chrome_controller.dart';
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/note_editor_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_password_dialog.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_reader_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_settings_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_viewer_models.dart';
import 'package:atlas_app/reader/presentation/widgets/quote_share_card_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_annotations_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_bar_surface.dart';
import 'package:atlas_app/reader/presentation/widgets/reader_chrome_bar.dart';
import 'package:atlas_app/reader/presentation/widgets/word_lookup_sheet.dart';
import 'package:atlas_app/reader/speech/selection_speaker.dart';
import 'package:atlas_app/reader/speech/settings/narration_settings.dart';
import 'package:atlas_app/reader/speech/speech_events.dart';
import 'package:atlas_app/reader/speech/speech_session_builder.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';
import 'package:atlas_app/settings/presentation/providers/settings_provider.dart';

/// Renders an imported PDF (format == 'pdf') using pdfrx's [PdfViewer].
///
/// Fully unified with the core Atlas reader chrome architecture:
/// auto-hides chrome on idle, tap-to-toggle immersion, theme-matched surfaces,
/// persistent highlights with formatting styles, passage notes, quote cards,
/// unified top/bottom navigation bars, responsive right side panel, and TTS narration.
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

const _invertFilter = ColorFilter.matrix([
  -1,
  0,
  0,
  0,
  255,
  0,
  -1,
  0,
  0,
  255,
  0,
  0,
  -1,
  0,
  255,
  0,
  0,
  0,
  1,
  0,
]);

const _identityFilter = ColorFilter.mode(Colors.white, BlendMode.dst);

class _PdfReaderContentState extends ConsumerState<PdfReaderContent>
    with ReaderChromeController {
  final _controller = PdfViewerController();
  Timer? _saveDebounce;

  PdfDocument? _document;
  PdfTextSearcher? _textSearcher;
  List<PdfOutlineNode>? _outline;

  bool _progressLoaded = false;
  int _startPage = 1;
  int _currentPage = 0;
  int _totalPages = 0;

  PdfReaderLayoutMode _layoutMode = PdfReaderLayoutMode.single;

  final _bookmarkedPages = <int>{};
  List<PdfPageTextRange> _selection = const [];

  String? _bookLanguage;
  String? _bookTitle;
  String? _bookCoverPath;

  final _selectionSpeaker = const SelectionSpeaker();
  final _sessionBuilder = const SpeechSessionBuilder();
  StreamSubscription<SpeechEvent>? _speechSub;
  bool _controllerListenerAdded = false;

  @override
  void initState() {
    super.initState();
    _speechSub = ref.read(speechEngineProvider).events.listen(_onSpeechEvent);
    _loadBookMeta();
    _loadStartPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDark =
          Theme.of(context).colorScheme.brightness == Brightness.dark;
      initReaderChrome(isDarkTheme: isDark);
    });
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _saveDebounce?.cancel();
    _textSearcher?.dispose();
    if (_controllerListenerAdded) {
      _controller.removeListener(_onControllerChanged);
    }
    disposeReaderChrome();
    super.dispose();
  }

  void _onSpeechEvent(SpeechEvent event) {
    switch (event) {
      case ChapterFinished(:final chapterId):
        _advanceFromNarration(chapterId);
      case SentenceStarted(:final item):
        ref.read(activeWordBoundaryProvider.notifier).state = null;
        if (item.bookId == widget.bookId) {
          ref.read(activeSpeechItemProvider.notifier).state = item;
        }
      case WordBoundary(:final item, :final start, :final end, :final word):
        ref.read(activeWordBoundaryProvider.notifier).state = WordBoundary(
          item,
          start,
          end,
          word,
        );
      case SpeechStopped() || SpeechCompleted():
        ref.read(activeSpeechItemProvider.notifier).state = null;
        ref.read(activeWordBoundaryProvider.notifier).state = null;
      default:
        break;
    }
  }

  void _advanceFromNarration(String finishedChapterId) {
    if (!mounted) return;
    final autoAdvance =
        ref.read(narrationSettingsProvider).value?.autoAdvanceChapter ?? true;
    if (!autoAdvance) return;
    if (_currentPage < _totalPages) {
      final next = _currentPage + 1;
      _goToPage(next);
      _syncSpeechSession(next, autoPlay: true);
    }
  }

  Future<String> _loadPageText(int pageNumber) async {
    final doc = _document;
    if (doc == null || pageNumber < 1 || pageNumber > doc.pages.length) {
      return '';
    }
    try {
      final page = doc.pages[pageNumber - 1];
      final pageText = await page.loadText();
      return pageText?.fullText ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _syncSpeechSession(int pageNumber, {bool autoPlay = false}) async {
    if (_document == null || pageNumber < 1 || pageNumber > _totalPages) return;
    final chapterId = 'pdf_page_$pageNumber';
    final engine = ref.read(speechEngineProvider);
    if (engine.session?.bookId == widget.bookId &&
        engine.session?.chapterId == chapterId) {
      if (autoPlay) unawaited(engine.start());
      return;
    }

    final content = await _loadPageText(pageNumber);
    if (content.trim().isEmpty) return;

    final settings =
        ref.read(narrationSettingsProvider).value ?? const NarrationSettings();
    final chapter = ChapterEntity(
      id: chapterId,
      bookId: widget.bookId,
      title: 'Page $pageNumber of $_totalPages',
      index: pageNumber - 1,
      contentPath: '',
    );

    final session = _sessionBuilder.build(
      bookId: widget.bookId,
      chapter: chapter,
      content: content,
      language: _bookLanguage ?? 'en',
      settings: settings,
      sentenceIndex: 0,
      coverPath: _bookCoverPath,
      bookTitle: _bookTitle,
      author: null,
    );

    await engine.loadSession(session);
    if (autoPlay) {
      unawaited(engine.start());
    }
  }

  Future<void> _loadBookMeta() async {
    final repo = DriftReaderRepository(ref.read(databaseProvider));
    final bookResult = await repo.getBookById(widget.bookId);
    if (bookResult is Success<BookEntity>) {
      if (mounted) {
        setState(() {
          _bookLanguage = bookResult.value.language;
          _bookTitle = bookResult.value.title;
          _bookCoverPath = bookResult.value.coverPath;
        });
      }
    }
  }

  Future<void> _loadStartPage() async {
    if (widget.initialPageNumber != null && widget.initialPageNumber! > 0) {
      if (mounted) {
        setState(() {
          _startPage = widget.initialPageNumber!;
          _progressLoaded = true;
        });
      }
      return;
    }
    final repo = DriftReaderRepository(ref.read(databaseProvider));
    final result = await repo.getReadingProgress(widget.bookId);
    if (result is Success<ReadingProgressSnapshot?> && result.value != null) {
      final savedPos = result.value!.position;
      if (savedPos > 0 && mounted) {
        setState(() {
          _startPage = savedPos;
          _progressLoaded = true;
        });
        return;
      }
    }
    if (mounted) {
      setState(() => _progressLoaded = true);
    }
  }

  Future<void> _onViewerReady(PdfDocument document, PdfViewerController controller) async {
    if (!_controllerListenerAdded) {
      _controller.addListener(_onControllerChanged);
      _controllerListenerAdded = true;
    }
    _textSearcher?.dispose();
    final searcher = PdfTextSearcher(controller);
    searcher.addListener(_onSearchChanged);

    final outline = await document.loadOutline();

    if (!mounted) return;
    setState(() {
      _document = document;
      _textSearcher = searcher;
      _outline = outline;
      _totalPages = document.pages.length;
      if (_startPage > _totalPages && _totalPages > 0) {
        _startPage = _totalPages;
      }
      _currentPage = _totalPages > 0 ? _startPage : 0;
    });
    if (_currentPage > 0) {
      unawaited(_syncSpeechSession(_currentPage));
    }
  }

  void _onDocumentChanged(PdfDocument? document) {
    if (document == null) {
      _textSearcher?.dispose();
      _textSearcher = null;
      _outline = null;
      _document = null;
      _bookmarkedPages.clear();
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
    unawaited(_syncSpeechSession(target));
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

  void _toggleBookmarkForCurrentPage() {
    if (_currentPage <= 0) return;
    setState(() {
      if (_bookmarkedPages.contains(_currentPage)) {
        _bookmarkedPages.remove(_currentPage);
      } else {
        _bookmarkedPages.add(_currentPage);
      }
    });
  }

  void _deleteMarker(PdfMarker marker) {
    final chapterId = 'pdf_page_${marker.pageNumber}';
    ref.read(annotationsProvider(widget.bookId).notifier).eraseOverlapping(
      chapterId,
      marker.start,
      marker.end,
    );
    _controller.invalidate();
  }

  void _goToMarker(PdfMarker marker) {
    if (!_controller.isReady) return;
    final rect = _controller.calcRectForRectInsidePage(
      pageNumber: marker.pageNumber,
      rect: marker.bounds,
    );
    _controller.ensureVisible(rect);
  }

  void _goToNote(PdfNoteEntry note) {
    _goToPage(note.pageNumber);
  }

  void _deleteNote(PdfNoteEntry note) {
    final chapterId = 'pdf_page_${note.pageNumber}';
    ref.read(annotationsProvider(widget.bookId).notifier).deleteNote(
      chapterId,
      note.id,
    );
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
    AppContextMenuHighlightOption(
      color: Color(0xFFFFD54F),
      label: 'Sunset Gold',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFF81C784),
      label: 'Emerald Mint',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFF64B5F6),
      label: 'Sky Blue',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFFFF8A65),
      label: 'Coral Orange',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFFF06292),
      label: 'Rose Pink',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFFBA68C8),
      label: 'Electric Violet',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFFAEEA00),
      label: 'Neon Lime',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFFFFB74D),
      label: 'Warm Amber',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFF90A4AE),
      label: 'Slate Graphite',
    ),
  ];

  Widget? _buildContextMenu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    if (!params.isTextSelectionEnabled) return null;
    final delegate = params.textSelectionDelegate;
    if (!delegate.hasSelectedText) return null;

    final overlappingHighlight = _findOverlappingHighlight(_selection);
    final hasOverlapping = overlappingHighlight != null ||
        _selection.any(_hasOverlappingMarker);

    return AppContextMenu(
      externallyPositioned: true,
      anchor: Offset.zero,
      highlightColors: _highlightPalette,
      initialStyle:
          overlappingHighlight?.styleType ?? HighlightStyleType.solid,
      onHighlightWithStyle: (color, style) =>
          _applyHighlightForSelectionWithStyle(params, color, style),
      quickActions: [
        AppContextMenuAction(
          label: 'Copy',
          icon: Icons.content_copy_rounded,
          onPressed: delegate.copyTextSelection,
        ),
        AppContextMenuAction(
          label: 'Note',
          icon: Icons.edit_note_rounded,
          onPressed: () => _addNoteForSelection(params),
        ),
        AppContextMenuAction(
          label: 'Share',
          icon: Icons.share_rounded,
          onPressed: () => _shareSelection(params),
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
        if (hasOverlapping)
          AppContextMenuAction(
            label: 'Erase highlight',
            icon: Icons.format_color_reset_rounded,
            destructive: true,
            onPressed: () => _eraseSelection(params),
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

  HighlightEntry? _findOverlappingHighlight(List<PdfPageTextRange> ranges) {
    if (ranges.isEmpty) return null;
    final annotations = ref.read(annotationsProvider(widget.bookId));
    for (final range in ranges) {
      final chapterId = 'pdf_page_${range.pageNumber}';
      final highlights = annotations.highlights[chapterId];
      if (highlights != null) {
        for (final h in highlights) {
          if (h.overlaps(range.start, range.end)) return h;
        }
      }
    }
    return null;
  }

  bool _hasOverlappingMarker(PdfPageTextRange range) {
    final chapterId = 'pdf_page_${range.pageNumber}';
    final highlights =
        ref.read(annotationsProvider(widget.bookId)).highlights[chapterId];
    if (highlights == null) return false;
    return highlights.any((h) => h.overlaps(range.start, range.end));
  }

  Future<List<PdfPageTextRange>> _resolveSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    if (_selection.isNotEmpty) return _selection;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (ranges.isNotEmpty) {
        if (mounted) setState(() => _selection = ranges);
        return ranges;
      }
    } catch (_) {}
    return const [];
  }

  Future<String> _selectedText(PdfViewerContextMenuBuilderParams params) async {
    try {
      final text = await params.textSelectionDelegate.getSelectedText();
      if (text.isNotEmpty) return text;
    } catch (_) {}
    if (_selection.isNotEmpty) {
      return _selection.map((r) => r.text).join();
    }
    final ranges = await _resolveSelection(params);
    return ranges.map((r) => r.text).join();
  }

  Future<void> _applyHighlightForSelectionWithStyle(
    PdfViewerContextMenuBuilderParams params,
    Color color, [
    HighlightStyleType styleType = HighlightStyleType.solid,
  ]) async {
    final ranges = await _resolveSelection(params);
    if (ranges.isEmpty || !mounted) return;
    final notifier = ref.read(annotationsProvider(widget.bookId).notifier);
    for (final range in ranges) {
      notifier.addHighlight(
        chapterId: 'pdf_page_${range.pageNumber}',
        start: range.start,
        end: range.end,
        text: range.text,
        colorValue: color.toARGB32(),
        styleType: styleType,
        bounds: [
          range.bounds.left,
          range.bounds.top,
          range.bounds.right,
          range.bounds.bottom,
        ],
      );
    }
    params.dismissContextMenu();
    _controller.invalidate();
  }

  Future<void> _eraseSelection(PdfViewerContextMenuBuilderParams params) async {
    final ranges = await _resolveSelection(params);
    if (ranges.isEmpty || !mounted) return;
    final notifier = ref.read(annotationsProvider(widget.bookId).notifier);
    for (final range in ranges) {
      notifier.eraseOverlapping(
        'pdf_page_${range.pageNumber}',
        range.start,
        range.end,
      );
    }
    params.dismissContextMenu();
    _controller.invalidate();
  }

  Future<void> _addNoteForSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final ranges = await _resolveSelection(params);
    if (ranges.isEmpty || !mounted) return;
    final first = ranges.first;
    final snippet = ranges.map((r) => r.text).join().trim();
    params.dismissContextMenu();
    await NoteEditorSheet.show(
      context,
      bookId: widget.bookId,
      chapterId: 'pdf_page_${first.pageNumber}',
      selectedText: snippet,
      sentence: snippet,
      chapterTitle: 'Page ${first.pageNumber}',
      highlightStart: first.start,
      highlightEnd: first.end,
    );
  }

  Future<void> _shareSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final ranges = await _resolveSelection(params);
    if (ranges.isEmpty || !mounted) return;
    final first = ranges.first;
    final snippet = ranges.map((r) => r.text).join().trim();
    params.dismissContextMenu();
    await QuoteShareCardSheet.show(
      context,
      quoteText: snippet,
      bookTitle: _bookTitle,
      coverPath: _bookCoverPath,
      chapterTitle: 'Page ${first.pageNumber}',
    );
  }

  Future<void> _listenToSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final text = (await _selectedText(params)).trim();
    if (text.isEmpty || !mounted) return;
    params.dismissContextMenu();
    await _selectionSpeaker.speak(
      ref: ref,
      bookId: widget.bookId,
      chapterId: 'pdf',
      text: text,
      language: _bookLanguage ?? 'en',
    );
  }

  Future<void> _lookupSelection(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final raw = await _selectedText(params);
    if (!mounted) return;
    final word = raw.split(RegExp(r'\s+')).join(' ').trim();
    if (word.isEmpty) return;
    params.dismissContextMenu();
    await AppSheet.show(
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

  List<ChapterEntity> _buildPdfPseudoChapters() {
    if (_totalPages <= 0) return const [];
    return List.generate(
      _totalPages,
      (i) => ChapterEntity(
        id: 'pdf_page_${i + 1}',
        bookId: widget.bookId,
        title: 'Page ${i + 1}',
        index: i,
        contentPath: '',
      ),
    );
  }

  void _openAnnotationsSheet() {
    ReaderAnnotationsSheet.show(
      context,
      bookId: widget.bookId,
      chapters: _buildPdfPseudoChapters(),
      currentChapterId: 'pdf_page_$_currentPage',
      bookTitle: _bookTitle,
      coverPath: _bookCoverPath,
      onJumpToChapter: (chapterId, offset) {
        final pageStr = chapterId.replaceFirst('pdf_page_', '');
        final pageNum = int.tryParse(pageStr);
        if (pageNum != null) {
          _goToPage(pageNum);
        }
      },
    );
  }

  List<PdfMarker> _getMarkersList(ReaderAnnotationsState annotations) {
    final result = <PdfMarker>[];
    for (final entry in annotations.highlights.entries) {
      final pageStr = entry.key.replaceFirst('pdf_page_', '');
      final pageNumber = int.tryParse(pageStr) ?? 1;
      for (final h in entry.value) {
        final bounds = (h.bounds != null && h.bounds!.length >= 4)
            ? PdfRect(h.bounds![0], h.bounds![1], h.bounds![2], h.bounds![3])
            : const PdfRect(0, 0, 0, 0);
        result.add(
          PdfMarker(
            pageNumber: pageNumber,
            start: h.start,
            end: h.end,
            text: h.text,
            bounds: bounds,
            color: h.color,
            styleType: h.styleType,
          ),
        );
      }
    }
    return result;
  }

  List<PdfNoteEntry> _getNotesList(ReaderAnnotationsState annotations) {
    final result = <PdfNoteEntry>[];
    for (final entry in annotations.notes.entries) {
      final pageStr = entry.key.replaceFirst('pdf_page_', '');
      final pageNumber = int.tryParse(pageStr) ?? 1;
      for (final n in entry.value) {
        result.add(
          PdfNoteEntry(
            id: n.id,
            pageNumber: pageNumber,
            snippet: n.sentence,
            text: n.text,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
            colorValue: n.colorValue,
            tags: n.tags,
            styleType: n.styleType,
            highlightStart: n.highlightStart,
            highlightEnd: n.highlightEnd,
          ),
        );
      }
    }
    return result;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(readingSettingsProvider).valueOrNull ??
        const ReadingSettingsEntity();
    final annotations = ref.watch(annotationsProvider(widget.bookId));
    final allMarkers = _getMarkersList(annotations);
    final allNotes = _getNotesList(annotations);

    final colorScheme = Theme.of(context).colorScheme;
    final isNight =
        colorScheme.brightness == Brightness.dark ||
        settings.theme == ReadingViewTheme.midnight ||
        settings.theme == ReadingViewTheme.charcoal;
    final background = settings.theme.resolve(colorScheme).background;
    final accent = settings.theme.resolve(colorScheme).accent;

    if (!_progressLoaded) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final titleText = _bookTitle != null && _bookTitle!.isNotEmpty
        ? '$_bookTitle ($_currentPage/$_totalPages)'
        : (_totalPages == 0 ? 'Loading PDF…' : 'Page $_currentPage of $_totalPages');

    return Scaffold(
      backgroundColor: background,
      appBar: chromeVisible
          ? ReaderBarSurface(
              style: settings.chromeStyle,
              color: colorScheme.surfaceContainerHigh,
              child: ReaderChromeBar(
                title: titleText,
                textColor: colorScheme.onSurface,
                onSettingsTap: _showSettingsSheet,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Back to Library',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  if (_totalPages > 0) ...[
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, size: 18),
                      tooltip: 'Zoom out',
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 18),
                      tooltip: 'Zoom in',
                      onPressed: _zoomIn,
                    ),
                    if (isDesktop) ...[
                      IconButton(
                        icon: Icon(
                          rightPanelVisible
                              ? Icons.view_sidebar_rounded
                              : Icons.view_sidebar_outlined,
                          size: 18,
                          color: colorScheme.onSurface,
                        ),
                        tooltip: 'Toggle outline & panels',
                        onPressed: toggleRightPanel,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    tooltip: 'Reading settings',
                    onPressed: _showSettingsSheet,
                  ),
                ],
              ),
            )
          : null,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (rightPanelVisible || narrationPanelVisible) {
              hideRightPanel();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColorFiltered(
                    colorFilter: isNight ? _invertFilter : _identityFilter,
                    child: _buildViewer(background, isNight),
                  ),
                ),
                if (isDesktop && (rightPanelVisible || narrationPanelVisible))
                  SizedBox(
                    width: ReaderChromeController.rightPanelWidth,
                    child: narrationPanelVisible
                        ? NowPlayingPanel(
                            bookTitle: _bookTitle,
                            coverPath: _bookCoverPath,
                            chapterTitle: 'Page $_currentPage of $_totalPages',
                            accent: accent,
                            onClose: closeNarrationPanel,
                          )
                        : PdfReaderPanel(
                            controller: _controller,
                            document: _document,
                            outline: _outline,
                            textSearcher: _textSearcher,
                            currentPage: _currentPage,
                            markers: allMarkers,
                            notes: allNotes,
                            onOutlineSelected: _goToOutlineNode,
                            onPageSelected: _goToPage,
                            onMarkerSelected: _goToMarker,
                            onMarkerDeleted: _deleteMarker,
                            onNoteSelected: _goToNote,
                            onNoteDeleted: _deleteNote,
                            onClose: hideRightPanel,
                          ),
                  ),
              ],
            ),
            if (!narrationPanelVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NarrationMiniPlayer(
                  bookTitle: _bookTitle,
                  coverPath: _bookCoverPath,
                  chapterTitle: 'Page $_currentPage of $_totalPages',
                  accent: accent,
                  onExpand: isDesktop ? toggleNarrationPanel : null,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: chromeVisible && _totalPages > 0
          ? ReaderBarSurface(
              style: settings.chromeStyle,
              color: colorScheme.surfaceContainerHigh,
              child: PdfBottomNav(
                textColor: colorScheme.onSurface,
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPageSelected: _goToPage,
                onSettingsTap: _showSettingsSheet,
                onOutlineTap: _onOutlineNavTap,
                onBookmarkTap: _toggleBookmarkForCurrentPage,
                isBookmarked: _bookmarkedPages.contains(_currentPage),
                layoutMode: _layoutMode,
                onToggleLayoutMode: _toggleLayoutMode,
                onListenTap: _onListenNavTap,
                onAnnotationsTap: _openAnnotationsSheet,
                progressColor: accent,
              ),
            )
          : null,
    );
  }

  void _onOutlineNavTap() {
    final annotations = ref.read(annotationsProvider(widget.bookId));
    final allMarkers = _getMarkersList(annotations);
    final allNotes = _getNotesList(annotations);

    if (isDesktop) {
      toggleRightPanel();
    } else {
      AppSheet.show(
        context: context,
        id: 'pdf_reader_panel_sheet',
        initialHeight: 0.75,
        snapPoints: const [0.5, 0.75, 0.95],
        child: PdfReaderPanel(
          controller: _controller,
          document: _document,
          outline: _outline,
          textSearcher: _textSearcher,
          currentPage: _currentPage,
          markers: allMarkers,
          notes: allNotes,
          onOutlineSelected: (node) {
            _goToOutlineNode(node);
            Navigator.of(context).maybePop();
          },
          onPageSelected: (page) {
            _goToPage(page);
            Navigator.of(context).maybePop();
          },
          onMarkerSelected: (marker) {
            _goToMarker(marker);
            Navigator.of(context).maybePop();
          },
          onMarkerDeleted: _deleteMarker,
          onNoteSelected: (note) {
            _goToNote(note);
            Navigator.of(context).maybePop();
          },
          onNoteDeleted: _deleteNote,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      );
    }
  }

  Future<void> _onListenNavTap() async {
    await _syncSpeechSession(_currentPage);
    if (!mounted) return;
    if (isDesktop) {
      toggleNarrationPanel();
    } else {
      unawaited(
        NowPlayingSheet.show(
          context,
          chapterTitle: 'Page $_currentPage of $_totalPages',
          bookTitle: _bookTitle,
          coverPath: _bookCoverPath,
        ),
      );
    }
  }

  void _showSettingsSheet() {
    AppSheet.show(
      context: context,
      id: 'pdf_reader_settings',
      initialHeight: 0.6,
      child: const PdfSettingsSheet(),
    );
  }

  Widget _buildViewer(Color background, bool isNight) {
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
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: _onTextSelectionChange,
        ),
        buildContextMenu: _buildContextMenu,
        linkHandlerParams: PdfLinkHandlerParams(onLinkTap: _onLinkTap),
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final handled = handleLinkTap(details.localPosition);
              if (!handled) {
                if (_controller.isReady &&
                    _controller.textSelectionDelegate.hasSelectedText) {
                  _controller.textSelectionDelegate.clearTextSelection();
                  if (_selection.isNotEmpty) {
                    setState(() => _selection = const []);
                  }
                  ContextMenuController.removeAny();
                  return;
                }
                if (_selection.isNotEmpty) {
                  setState(() => _selection = const []);
                  ContextMenuController.removeAny();
                  _controller.invalidate();
                  return;
                }
                if (rightPanelVisible || narrationPanelVisible) {
                  hideRightPanel();
                } else {
                  toggleChrome(isDarkTheme: isNight);
                }
              }
            },
            onDoubleTap: () {
              if (_controller.isReady) _controller.zoomUp(loop: true);
            },
            child: SizedBox(width: size.width, height: size.height),
          ),
          PdfViewerScrollThumb(
            controller: _controller,
            orientation: horizontal
                ? ScrollbarOrientation.bottom
                : ScrollbarOrientation.right,
            thumbSize: const Size(40, 25),
            thumbBuilder: (context, thumbSize, pageNumber, controller) =>
                Container(
                  decoration: BoxDecoration(
                    color: isNight ? Colors.white : Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      pageNumber?.toString() ?? '',
                      style: TextStyle(
                        color: isNight ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
          ),
        ],
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => Center(
          child: CircularProgressIndicator(
            value: totalBytes != null && totalBytes > 0
                ? bytesDownloaded / totalBytes
                : null,
          ),
        ),
        errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Failed to open this PDF document.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
    final height =
        pages.fold(0.0, (prev, page) => math.max(prev, page.height)) +
        params.margin * 2;
    final pageLayouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(x, height),
    );
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
          isLeft
              ? width + params.margin - page.width
              : params.margin * 2 + width,
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
    final annotations = ref.read(annotationsProvider(widget.bookId));
    final chapterId = 'pdf_page_${page.pageNumber}';
    final highlights = annotations.highlights[chapterId];
    if (highlights == null || highlights.isEmpty) return;

    for (final h in highlights) {
      if (h.bounds == null || h.bounds!.length < 4) continue;
      final pdfRect = PdfRect(
        h.bounds![0],
        h.bounds![1],
        h.bounds![2],
        h.bounds![3],
      );
      final rect = pdfRect
          .toRect(page: page, scaledPageSize: pageRect.size)
          .translate(pageRect.left, pageRect.top);

      switch (h.styleType) {
        case HighlightStyleType.solid:
          final paint = Paint()
            ..color = h.color.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, paint);
        case HighlightStyleType.underline:
          final paint = Paint()
            ..color = h.color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(rect.left, rect.bottom - 1),
            Offset(rect.right, rect.bottom - 1),
            paint,
          );
        case HighlightStyleType.wavy:
          final paint = Paint()
            ..color = h.color
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          final path = Path();
          var x = rect.left;
          final y = rect.bottom - 2;
          path.moveTo(x, y);
          const waveLength = 6.0;
          const waveHeight = 2.0;
          var toggle = true;
          while (x < rect.right) {
            final nextX = math.min(x + waveLength, rect.right);
            final midX = (x + nextX) / 2;
            final controlY = toggle ? y - waveHeight : y + waveHeight;
            path.quadraticBezierTo(midX, controlY, nextX, y);
            x = nextX;
            toggle = !toggle;
          }
          canvas.drawPath(path, paint);
        case HighlightStyleType.strikethrough:
          final paint = Paint()
            ..color = h.color
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          final midY = (rect.top + rect.bottom) / 2;
          canvas.drawLine(
            Offset(rect.left, midY),
            Offset(rect.right, midY),
            paint,
          );
        case HighlightStyleType.bold:
          final paint = Paint()
            ..color = h.color.withValues(alpha: 0.38)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, paint);
          final barPaint = Paint()
            ..color = h.color
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(rect.left, rect.bottom - 1.5),
            Offset(rect.right, rect.bottom - 1.5),
            barPaint,
          );
        case HighlightStyleType.italic:
          final paint = Paint()
            ..color = h.color.withValues(alpha: 0.28)
            ..style = PaintingStyle.fill;
          final path = Path()
            ..moveTo(rect.left + 3, rect.top)
            ..lineTo(rect.right + 3, rect.top)
            ..lineTo(rect.right - 3, rect.bottom)
            ..lineTo(rect.left - 3, rect.bottom)
            ..close();
          canvas.drawPath(path, paint);
          final slantBorder = Paint()
            ..color = h.color.withValues(alpha: 0.6)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, slantBorder);
      }
    }
  }
}
