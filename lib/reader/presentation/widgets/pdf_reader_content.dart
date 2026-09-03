import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide WordBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:real_page_flip/real_page_flip.dart';
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
import 'package:atlas_app/reader/presentation/providers/annotations_provider.dart';
import 'package:atlas_app/reader/presentation/providers/reader_chrome_provider.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/narration_mini_player.dart';
import 'package:atlas_app/reader/presentation/widgets/note_editor_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_panel.dart';
import 'package:atlas_app/reader/presentation/widgets/now_playing_sheet.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_bottom_nav.dart';
import 'package:atlas_app/reader/presentation/widgets/pdf/pdf_flipbook_view.dart';
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
class PdfReaderContent extends HookConsumerWidget {
  const PdfReaderContent({
    super.key,
    required this.bookId,
    required this.pdfPath,
    this.initialPageNumber,
  });

  final String bookId;
  final String pdfPath;
  final int? initialPageNumber;

  static const _invertFilter = ColorFilter.matrix([
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

  static const _identityFilter = ColorFilter.mode(Colors.white, BlendMode.dst);

  static const _selectionSpeaker = SelectionSpeaker();
  static const _sessionBuilder = SpeechSessionBuilder();

  static const _highlightPalette = [
    AppContextMenuHighlightOption(
      color: Color(0xFFFFD54F),
      label: 'Sunset Gold',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFF81C784),
      label: 'Emerald Mint',
    ),
    AppContextMenuHighlightOption(color: Color(0xFF64B5F6), label: 'Sky Blue'),
    AppContextMenuHighlightOption(
      color: Color(0xFFFF8A65),
      label: 'Coral Orange',
    ),
    AppContextMenuHighlightOption(color: Color(0xFFF06292), label: 'Rose Pink'),
    AppContextMenuHighlightOption(
      color: Color(0xFFBA68C8),
      label: 'Electric Violet',
    ),
    AppContextMenuHighlightOption(color: Color(0xFFAEEA00), label: 'Neon Lime'),
    AppContextMenuHighlightOption(
      color: Color(0xFFFFB74D),
      label: 'Warm Amber',
    ),
    AppContextMenuHighlightOption(
      color: Color(0xFF90A4AE),
      label: 'Slate Graphite',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chromeState = ref.watch(readerChromeProvider);
    final chromeNotifier = ref.read(readerChromeProvider.notifier);

    final controller = useMemoized(() => PdfViewerController());
    final flipController = useMemoized(() => PageFlipController());
    final saveDebounce = useRef<Timer?>(null);

    final documentState = useState<PdfDocument?>(null);
    final textSearcherState = useState<PdfTextSearcher?>(null);
    final outlineState = useState<List<PdfOutlineNode>?>(null);

    final progressLoaded = useState(false);
    final startPage = useState(1);
    final currentPage = useState(0);
    final totalPages = useState(0);

    final layoutMode = useState(PdfReaderLayoutMode.flipbook);
    final bookmarkedPages = useState<Set<int>>({});
    final selection = useState<List<PdfPageTextRange>>(const []);

    final bookLanguage = useState<String?>(null);
    final bookTitle = useState<String?>(null);
    final bookCoverPath = useState<String?>(null);

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    Future<String> loadPageText(int pageNumber) async {
      final doc = documentState.value;
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

    Future<void> syncSpeechSession(
      int pageNumber, {
      bool autoPlay = false,
    }) async {
      if (documentState.value == null ||
          pageNumber < 1 ||
          pageNumber > totalPages.value) {
        return;
      }
      final chapterId = 'pdf_page_$pageNumber';
      final engine = ref.read(speechEngineProvider);
      if (engine.session?.bookId == bookId &&
          engine.session?.chapterId == chapterId) {
        if (autoPlay) unawaited(engine.start());
        return;
      }

      final content = await loadPageText(pageNumber);
      if (content.trim().isEmpty) return;

      final settings =
          ref.read(narrationSettingsProvider).value ??
          const NarrationSettings();
      final chapter = ChapterEntity(
        id: chapterId,
        bookId: bookId,
        title: 'Page $pageNumber of ${totalPages.value}',
        index: pageNumber - 1,
        contentPath: '',
      );

      final session = _sessionBuilder.build(
        bookId: bookId,
        chapter: chapter,
        content: content,
        language: bookLanguage.value ?? 'en',
        settings: settings,
        sentenceIndex: 0,
        coverPath: bookCoverPath.value,
        bookTitle: bookTitle.value,
        author: null,
      );

      await engine.loadSession(session);
      if (autoPlay) {
        unawaited(engine.start());
      }
    }

    Future<void> saveProgress() async {
      if (totalPages.value <= 0) return;
      final repo = DriftReaderRepository(ref.read(databaseProvider));
      await repo.saveProgress(
        userId: 'local',
        bookId: bookId,
        chapterId: 'pdf',
        percentage: currentPage.value / totalPages.value * 100,
        position: currentPage.value,
        totalPositions: totalPages.value,
      );
    }

    void onPageChanged(int? page) {
      if (!context.mounted || totalPages.value == 0) return;
      final target = ((page ?? currentPage.value).clamp(
        1,
        totalPages.value,
      )).toInt();
      if (target == currentPage.value) return;
      currentPage.value = target;
      saveDebounce.value?.cancel();
      saveDebounce.value = Timer(
        const Duration(milliseconds: 400),
        saveProgress,
      );
      unawaited(syncSpeechSession(target));
    }

    Future<void> goToPage(int pageNumber) async {
      if (totalPages.value == 0) return;
      final target = pageNumber.clamp(1, totalPages.value);
      if (layoutMode.value == PdfReaderLayoutMode.flipbook) {
        final settings =
            ref.read(readingSettingsProvider).valueOrNull ??
            const ReadingSettingsEntity();
        final isDesktop = MediaQuery.sizeOf(context).width >= 1200;
        final useDoubleSpread = isDesktop && settings.useBookSpread;
        final targetIndex = useDoubleSpread
            ? ((target - 1) ~/ 2)
            : (target - 1);
        if (flipController.isAttached) {
          await flipController.goToPage(targetIndex);
        }
      } else {
        if (controller.isReady) {
          await controller.goToPage(pageNumber: target);
        }
      }
      onPageChanged(target);
    }

    void advanceFromNarration(String finishedChapterId) {
      if (!context.mounted) return;
      final autoAdvance =
          ref.read(narrationSettingsProvider).value?.autoAdvanceChapter ?? true;
      if (!autoAdvance) return;
      if (currentPage.value < totalPages.value) {
        final next = currentPage.value + 1;
        goToPage(next);
        syncSpeechSession(next, autoPlay: true);
      }
    }

    void onSpeechEvent(SpeechEvent event) {
      switch (event) {
        case ChapterFinished(:final chapterId):
          advanceFromNarration(chapterId);
        case SentenceStarted(:final item):
          ref.read(activeWordBoundaryProvider.notifier).state = null;
          if (item.bookId == bookId) {
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

    Future<void> loadBookMeta() async {
      final repo = DriftReaderRepository(ref.read(databaseProvider));
      final bookResult = await repo.getBookById(bookId);
      if (bookResult is Success<BookEntity> && context.mounted) {
        bookLanguage.value = bookResult.value.language;
        bookTitle.value = bookResult.value.title;
        bookCoverPath.value = bookResult.value.coverPath;
      }
    }

    Future<void> loadStartPage() async {
      if (initialPageNumber != null && initialPageNumber! > 0) {
        if (context.mounted) {
          startPage.value = initialPageNumber!;
          progressLoaded.value = true;
        }
        return;
      }
      final repo = DriftReaderRepository(ref.read(databaseProvider));
      final result = await repo.getReadingProgress(bookId);
      if (result is Success<ReadingProgressSnapshot?> && result.value != null) {
        final savedPos = result.value!.position;
        if (savedPos > 0 && context.mounted) {
          startPage.value = savedPos;
          progressLoaded.value = true;
          return;
        }
      }
      if (context.mounted) {
        progressLoaded.value = true;
      }
    }

    void onControllerChanged() {
      final page = controller.pageNumber;
      if (page != null && page > 0) {
        onPageChanged(page);
      }
    }

    useEffect(() {
      chromeNotifier.initReaderChrome(isDarkTheme: isDark);
      final speechSub = ref
          .read(speechEngineProvider)
          .events
          .listen(onSpeechEvent);
      loadBookMeta();
      loadStartPage();
      controller.addListener(onControllerChanged);

      return () {
        speechSub.cancel();
        saveDebounce.value?.cancel();
        textSearcherState.value?.dispose();
        controller.removeListener(onControllerChanged);
      };
    }, const []);

    void onSearchChanged() {
      // triggers rebuild through local state or parent
    }

    Future<void> onViewerReady(
      PdfDocument document,
      PdfViewerController ctrl,
    ) async {
      textSearcherState.value?.dispose();
      final searcher = PdfTextSearcher(ctrl);
      searcher.addListener(onSearchChanged);

      final outline = await document.loadOutline();

      if (!context.mounted) return;
      documentState.value = document;
      textSearcherState.value = searcher;
      outlineState.value = outline;
      totalPages.value = document.pages.length;
      if (startPage.value > totalPages.value && totalPages.value > 0) {
        startPage.value = totalPages.value;
      }
      currentPage.value = totalPages.value > 0 ? startPage.value : 0;

      if (currentPage.value > 0) {
        unawaited(syncSpeechSession(currentPage.value));
      }
    }

    void onDocumentChanged(PdfDocument? document) {
      if (document == null) {
        textSearcherState.value?.dispose();
        textSearcherState.value = null;
        outlineState.value = null;
        documentState.value = null;
        bookmarkedPages.value = {};
        selection.value = const [];
      }
    }

    void zoomIn() {
      if (controller.isReady) controller.zoomUp();
    }

    void zoomOut() {
      if (controller.isReady) controller.zoomDown();
    }

    void toggleLayoutMode() {
      layoutMode.value = switch (layoutMode.value) {
        PdfReaderLayoutMode.flipbook => PdfReaderLayoutMode.single,
        PdfReaderLayoutMode.single => PdfReaderLayoutMode.continuous,
        PdfReaderLayoutMode.continuous => PdfReaderLayoutMode.facing,
        PdfReaderLayoutMode.facing => PdfReaderLayoutMode.flipbook,
      };
      controller.invalidate();
    }

    void toggleBookmarkForCurrentPage() {
      if (currentPage.value <= 0) return;
      final set = Set<int>.from(bookmarkedPages.value);
      if (set.contains(currentPage.value)) {
        set.remove(currentPage.value);
      } else {
        set.add(currentPage.value);
      }
      bookmarkedPages.value = set;
    }

    void deleteMarker(PdfMarker marker) {
      final chapterId = 'pdf_page_${marker.pageNumber}';
      ref
          .read(annotationsProvider(bookId).notifier)
          .eraseOverlapping(chapterId, marker.start, marker.end);
      controller.invalidate();
    }

    void goToMarker(PdfMarker marker) {
      if (!controller.isReady) return;
      final rect = controller.calcRectForRectInsidePage(
        pageNumber: marker.pageNumber,
        rect: marker.bounds,
      );
      controller.ensureVisible(rect);
    }

    void goToNote(PdfNoteEntry note) {
      goToPage(note.pageNumber);
    }

    void deleteNote(PdfNoteEntry note) {
      final chapterId = 'pdf_page_${note.pageNumber}';
      ref
          .read(annotationsProvider(bookId).notifier)
          .deleteNote(chapterId, note.id);
    }

    void goToOutlineNode(PdfOutlineNode node) {
      final dest = node.dest;
      if (dest != null) controller.goToDest(dest);
    }

    Future<void> onTextSelectionChange(PdfTextSelection sel) async {
      final ranges = await sel.getSelectedTextRanges();
      if (!context.mounted) return;
      selection.value = ranges;
    }

    HighlightEntry? findOverlappingHighlight(List<PdfPageTextRange> ranges) {
      if (ranges.isEmpty) return null;
      final annotations = ref.read(annotationsProvider(bookId));
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

    bool hasOverlappingMarker(PdfPageTextRange range) {
      final chapterId = 'pdf_page_${range.pageNumber}';
      final highlights = ref
          .read(annotationsProvider(bookId))
          .highlights[chapterId];
      if (highlights == null) return false;
      return highlights.any((h) => h.overlaps(range.start, range.end));
    }

    Future<List<PdfPageTextRange>> resolveSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      if (selection.value.isNotEmpty) return selection.value;
      try {
        final ranges = await params.textSelectionDelegate
            .getSelectedTextRanges();
        if (ranges.isNotEmpty) {
          if (context.mounted) selection.value = ranges;
          return ranges;
        }
      } catch (_) {}
      return const [];
    }

    Future<String> selectedText(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      try {
        final text = await params.textSelectionDelegate.getSelectedText();
        if (text.isNotEmpty) return text;
      } catch (_) {}
      if (selection.value.isNotEmpty) {
        return selection.value.map((r) => r.text).join();
      }
      final ranges = await resolveSelection(params);
      return ranges.map((r) => r.text).join();
    }

    Future<void> applyHighlightForSelectionWithStyle(
      PdfViewerContextMenuBuilderParams params,
      Color color, [
      HighlightStyleType styleType = HighlightStyleType.solid,
    ]) async {
      final ranges = await resolveSelection(params);
      if (ranges.isEmpty || !context.mounted) return;
      final notifier = ref.read(annotationsProvider(bookId).notifier);
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
      controller.invalidate();
    }

    Future<void> eraseSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      final ranges = await resolveSelection(params);
      if (ranges.isEmpty || !context.mounted) return;
      final notifier = ref.read(annotationsProvider(bookId).notifier);
      for (final range in ranges) {
        notifier.eraseOverlapping(
          'pdf_page_${range.pageNumber}',
          range.start,
          range.end,
        );
      }
      params.dismissContextMenu();
      controller.invalidate();
    }

    Future<void> addNoteForSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      final ranges = await resolveSelection(params);
      if (ranges.isEmpty || !context.mounted) return;
      final first = ranges.first;
      final snippet = ranges.map((r) => r.text).join().trim();
      params.dismissContextMenu();
      await NoteEditorSheet.show(
        context,
        bookId: bookId,
        chapterId: 'pdf_page_${first.pageNumber}',
        selectedText: snippet,
        sentence: snippet,
        chapterTitle: 'Page ${first.pageNumber}',
        highlightStart: first.start,
        highlightEnd: first.end,
      );
    }

    Future<void> shareSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      final ranges = await resolveSelection(params);
      if (ranges.isEmpty || !context.mounted) return;
      final first = ranges.first;
      final snippet = ranges.map((r) => r.text).join().trim();
      params.dismissContextMenu();
      await QuoteShareCardSheet.show(
        context,
        quoteText: snippet,
        bookTitle: bookTitle.value,
        coverPath: bookCoverPath.value,
        chapterTitle: 'Page ${first.pageNumber}',
      );
    }

    Future<void> listenToSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      final text = (await selectedText(params)).trim();
      if (text.isEmpty || !context.mounted) return;
      params.dismissContextMenu();
      await _selectionSpeaker.speak(
        ref: ref,
        bookId: bookId,
        chapterId: 'pdf',
        text: text,
        language: bookLanguage.value ?? 'en',
      );
    }

    Future<void> lookupSelection(
      PdfViewerContextMenuBuilderParams params,
    ) async {
      final raw = await selectedText(params);
      if (!context.mounted) return;
      final word = raw.split(RegExp(r'\s+')).join(' ').trim();
      if (word.isEmpty) return;
      params.dismissContextMenu();
      await AppSheet.show(
        context: context,
        id: 'word_lookup',
        initialHeight: 0.7,
        child: WordLookupSheet(
          word: word,
          initialLanguage: bookLanguage.value ?? 'en',
          sourceSentence: null,
          sourceTitle:
              bookTitle.value ??
              'Page ${currentPage.value} of ${totalPages.value}',
        ),
      );
    }

    Future<void> openUrl(Uri url) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open link'),
          content: Text(
            'Open this link in your browser?\n\n$url',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await launchUrl(url);
      }
    }

    void onLinkTap(PdfLink link) {
      final url = link.url;
      if (url != null) {
        openUrl(url);
      } else if (link.dest != null) {
        controller.goToDest(link.dest);
      }
    }

    Widget? buildContextMenu(
      BuildContext ctx,
      PdfViewerContextMenuBuilderParams params,
    ) {
      if (!params.isTextSelectionEnabled) return null;
      final delegate = params.textSelectionDelegate;
      if (!delegate.hasSelectedText) return null;

      final overlappingHighlight = findOverlappingHighlight(selection.value);
      final hasOverlapping =
          overlappingHighlight != null ||
          selection.value.any(hasOverlappingMarker);

      return AppContextMenu(
        externallyPositioned: true,
        anchor: Offset.zero,
        highlightColors: _highlightPalette,
        initialStyle:
            overlappingHighlight?.styleType ?? HighlightStyleType.solid,
        onHighlightWithStyle: (color, style) =>
            applyHighlightForSelectionWithStyle(params, color, style),
        quickActions: [
          AppContextMenuAction(
            label: 'Copy',
            icon: Icons.content_copy_rounded,
            onPressed: delegate.copyTextSelection,
          ),
          AppContextMenuAction(
            label: 'Note',
            icon: Icons.edit_note_rounded,
            onPressed: () => addNoteForSelection(params),
          ),
          AppContextMenuAction(
            label: 'Share',
            icon: Icons.share_rounded,
            onPressed: () => shareSelection(params),
          ),
          AppContextMenuAction(
            label: 'Listen',
            icon: Icons.play_circle_outline_rounded,
            onPressed: () => listenToSelection(params),
          ),
        ],
        listActions: [
          AppContextMenuAction(
            label: 'Look up',
            icon: Icons.translate_rounded,
            onPressed: () => lookupSelection(params),
          ),
          if (hasOverlapping)
            AppContextMenuAction(
              label: 'Erase highlight',
              icon: Icons.format_color_reset_rounded,
              destructive: true,
              onPressed: () => eraseSelection(params),
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

    List<ChapterEntity> buildPdfPseudoChapters() {
      if (totalPages.value <= 0) return const [];
      return List.generate(
        totalPages.value,
        (i) => ChapterEntity(
          id: 'pdf_page_${i + 1}',
          bookId: bookId,
          title: 'Page ${i + 1}',
          index: i,
          contentPath: '',
        ),
      );
    }

    void openAnnotationsSheet() {
      ReaderAnnotationsSheet.show(
        context,
        bookId: bookId,
        chapters: buildPdfPseudoChapters(),
        currentChapterId: 'pdf_page_${currentPage.value}',
        bookTitle: bookTitle.value,
        coverPath: bookCoverPath.value,
        onJumpToChapter: (chapterId, offset) {
          final pageStr = chapterId.replaceFirst('pdf_page_', '');
          final pageNum = int.tryParse(pageStr);
          if (pageNum != null) {
            goToPage(pageNum);
          }
        },
      );
    }

    List<PdfMarker> getMarkersList(ReaderAnnotationsState ann) {
      final result = <PdfMarker>[];
      for (final entry in ann.highlights.entries) {
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

    List<PdfNoteEntry> getNotesList(ReaderAnnotationsState ann) {
      final result = <PdfNoteEntry>[];
      for (final entry in ann.notes.entries) {
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

    void showSettingsSheet() {
      AppSheet.show(
        context: context,
        id: 'pdf_reader_settings',
        initialHeight: 0.6,
        child: const PdfSettingsSheet(),
      );
    }

    void onOutlineNavTap() {
      final annotations = ref.read(annotationsProvider(bookId));
      final allMarkers = getMarkersList(annotations);
      final allNotes = getNotesList(annotations);

      if (isDesktop) {
        chromeNotifier.toggleRightPanel();
      } else {
        AppSheet.show(
          context: context,
          id: 'pdf_reader_panel_sheet',
          initialHeight: 0.75,
          snapPoints: const [0.5, 0.75, 0.95],
          child: PdfReaderPanel(
            controller: controller,
            document: documentState.value,
            outline: outlineState.value,
            textSearcher: textSearcherState.value,
            currentPage: currentPage.value,
            markers: allMarkers,
            notes: allNotes,
            onOutlineSelected: (node) {
              goToOutlineNode(node);
              Navigator.of(context).maybePop();
            },
            onPageSelected: (page) {
              goToPage(page);
              Navigator.of(context).maybePop();
            },
            onMarkerSelected: (marker) {
              goToMarker(marker);
              Navigator.of(context).maybePop();
            },
            onMarkerDeleted: deleteMarker,
            onNoteSelected: (note) {
              goToNote(note);
              Navigator.of(context).maybePop();
            },
            onNoteDeleted: deleteNote,
            onClose: () => Navigator.of(context).maybePop(),
          ),
        );
      }
    }

    Future<void> onListenNavTap() async {
      await syncSpeechSession(currentPage.value);
      if (!context.mounted) return;
      if (isDesktop) {
        chromeNotifier.toggleNarrationPanel();
      } else {
        unawaited(
          NowPlayingSheet.show(
            context,
            chapterTitle: 'Page ${currentPage.value} of ${totalPages.value}',
            bookTitle: bookTitle.value,
            coverPath: bookCoverPath.value,
          ),
        );
      }
    }

    void paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
      final annotations = ref.read(annotationsProvider(bookId));
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

    PdfPageLayout horizontalLayout(
      List<PdfPage> pages,
      PdfViewerParams params,
    ) {
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

    PdfPageLayout facingLayout(List<PdfPage> pages, PdfViewerParams params) {
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

    PdfPageLayoutFunction? layoutFor(PdfReaderLayoutMode mode) {
      return switch (mode) {
        PdfReaderLayoutMode.flipbook => null,
        PdfReaderLayoutMode.single => null,
        PdfReaderLayoutMode.continuous => horizontalLayout,
        PdfReaderLayoutMode.facing => facingLayout,
      };
    }

    Widget buildViewer(Color bg, bool isNightMode) {
      final horizontal = layoutMode.value == PdfReaderLayoutMode.continuous;
      return PdfViewer.file(
        pdfPath,
        controller: controller,
        initialPageNumber: startPage.value,
        passwordProvider: () => promptPdfPassword(context),
        params: PdfViewerParams(
          layoutPages: layoutFor(layoutMode.value),
          backgroundColor: bg,
          scrollHorizontallyByMouseWheel: horizontal,
          pageAnchor: horizontal ? PdfPageAnchor.left : PdfPageAnchor.top,
          pageAnchorEnd: horizontal
              ? PdfPageAnchor.right
              : PdfPageAnchor.bottom,
          textSelectionParams: PdfTextSelectionParams(
            onTextSelectionChange: onTextSelectionChange,
          ),
          buildContextMenu: buildContextMenu,
          linkHandlerParams: PdfLinkHandlerParams(onLinkTap: onLinkTap),
          viewerOverlayBuilder: (context, size, handleLinkTap) => [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final handled = handleLinkTap(details.localPosition);
                if (!handled) {
                  if (controller.isReady &&
                      controller.textSelectionDelegate.hasSelectedText) {
                    controller.textSelectionDelegate.clearTextSelection();
                    if (selection.value.isNotEmpty) {
                      selection.value = const [];
                    }
                    ContextMenuController.removeAny();
                    return;
                  }
                  if (selection.value.isNotEmpty) {
                    selection.value = const [];
                    ContextMenuController.removeAny();
                    controller.invalidate();
                    return;
                  }
                  if (chromeState.rightPanelVisible ||
                      chromeState.narrationPanelVisible) {
                    chromeNotifier.hideRightPanel();
                  } else {
                    chromeNotifier.toggleChrome(isDarkTheme: isNightMode);
                  }
                }
              },
              onDoubleTap: () {
                if (controller.isReady) controller.zoomUp(loop: true);
              },
              child: SizedBox(width: size.width, height: size.height),
            ),
            PdfViewerScrollThumb(
              controller: controller,
              orientation: horizontal
                  ? ScrollbarOrientation.bottom
                  : ScrollbarOrientation.right,
              thumbSize: const Size(40, 25),
              thumbBuilder: (context, thumbSize, pageNumber, ctrl) => Container(
                decoration: BoxDecoration(
                  color: isNightMode ? Colors.white : Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    pageNumber?.toString() ?? '',
                    style: TextStyle(
                      color: isNightMode ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
              Center(
                child: CircularProgressIndicator(
                  value: totalBytes != null && totalBytes > 0
                      ? bytesDownloaded / totalBytes
                      : null,
                ),
              ),
          errorBannerBuilder: (context, error, stackTrace, documentRef) =>
              Center(
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          pagePaintCallbacks: [
            paintMarkers,
            if (textSearcherState.value != null)
              textSearcherState.value!.pageTextMatchPaintCallback,
          ],
          onDocumentChanged: onDocumentChanged,
          onViewerReady: onViewerReady,
          onPageChanged: onPageChanged,
        ),
      );
    }

    final settings =
        ref.watch(readingSettingsProvider).valueOrNull ??
        const ReadingSettingsEntity();
    final annotations = ref.watch(annotationsProvider(bookId));
    final allMarkers = getMarkersList(annotations);
    final allNotes = getNotesList(annotations);

    final colorScheme = Theme.of(context).colorScheme;
    final isNight =
        colorScheme.brightness == Brightness.dark ||
        settings.theme == ReadingViewTheme.midnight ||
        settings.theme == ReadingViewTheme.charcoal;
    final background = settings.theme.resolve(colorScheme).background;
    final accent = settings.theme.resolve(colorScheme).accent;

    if (!progressLoaded.value) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final titleText = bookTitle.value != null && bookTitle.value!.isNotEmpty
        ? '${bookTitle.value} (${currentPage.value}/${totalPages.value})'
        : (totalPages.value == 0
              ? 'Loading PDF…'
              : 'Page ${currentPage.value} of ${totalPages.value}');

    return Scaffold(
      backgroundColor: background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (chromeState.rightPanelVisible ||
                chromeState.narrationPanelVisible) {
              chromeNotifier.hideRightPanel();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: layoutMode.value == PdfReaderLayoutMode.flipbook
                        ? PdfFlipbookView(
                            key: ValueKey(
                              'flipbook_viewer_${settings.theme.name}',
                            ),
                            bookId: bookId,
                            pdfPath: pdfPath,
                            initialPage: startPage.value,
                            isNightMode: isNight,
                            settings: settings,
                            bookTitle: bookTitle.value,
                            bookCoverPath: bookCoverPath.value,
                            controller: flipController,
                            onDocumentReady: (doc) {
                              if (!context.mounted) return;
                              documentState.value = doc;
                              totalPages.value = doc.pages.length;
                            },
                            onPageChanged: onPageChanged,
                            onTap: () => chromeNotifier.toggleChrome(
                              isDarkTheme: isNight,
                            ),
                            onHighlight:
                                (
                                  pageNum,
                                  text,
                                  color,
                                  start,
                                  end, {
                                  styleType = HighlightStyleType.solid,
                                }) {
                                  final notifier = ref.read(
                                    annotationsProvider(bookId).notifier,
                                  );
                                  notifier.addHighlight(
                                    chapterId: 'pdf_page_$pageNum',
                                    start: start,
                                    end: end,
                                    text: text,
                                    colorValue: color.toARGB32(),
                                    styleType: styleType,
                                  );
                                },
                            onAddNote: (pageNum, text, sentence) async {
                              await NoteEditorSheet.show(
                                context,
                                bookId: bookId,
                                chapterId: 'pdf_page_$pageNum',
                                selectedText: text,
                                sentence: sentence ?? text,
                                chapterTitle: 'Page $pageNum',
                              );
                            },
                            onShare: (pageNum, text) async {
                              await QuoteShareCardSheet.show(
                                context,
                                quoteText: text,
                                bookTitle: bookTitle.value,
                                coverPath: bookCoverPath.value,
                                chapterTitle: 'Page $pageNum',
                              );
                            },
                            onListen: (pageNum, text, start, end) async {
                              await _selectionSpeaker.speak(
                                ref: ref,
                                bookId: bookId,
                                chapterId: 'pdf',
                                text: text,
                                language: bookLanguage.value ?? 'en',
                              );
                            },
                          )
                        : ColorFiltered(
                            colorFilter: isNight
                                ? _invertFilter
                                : _identityFilter,
                            child: buildViewer(background, isNight),
                          ),
                  ),
                  if (isDesktop &&
                      (chromeState.rightPanelVisible ||
                          chromeState.narrationPanelVisible))
                    SizedBox(
                      width: 280.0,
                      child: chromeState.narrationPanelVisible
                          ? NowPlayingPanel(
                              bookTitle: bookTitle.value,
                              coverPath: bookCoverPath.value,
                              chapterTitle:
                                  'Page ${currentPage.value} of ${totalPages.value}',
                              accent: accent,
                              onClose: chromeNotifier.closeNarrationPanel,
                            )
                          : PdfReaderPanel(
                              controller: controller,
                              document: documentState.value,
                              outline: outlineState.value,
                              textSearcher: textSearcherState.value,
                              currentPage: currentPage.value,
                              markers: allMarkers,
                              notes: allNotes,
                              onOutlineSelected: goToOutlineNode,
                              onPageSelected: goToPage,
                              onMarkerSelected: goToMarker,
                              onMarkerDeleted: deleteMarker,
                              onNoteSelected: goToNote,
                              onNoteDeleted: deleteNote,
                              onClose: chromeNotifier.hideRightPanel,
                            ),
                    ),
                ],
              ),
            ),
            if (!chromeState.narrationPanelVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NarrationMiniPlayer(
                  bookTitle: bookTitle.value,
                  coverPath: bookCoverPath.value,
                  chapterTitle:
                      'Page ${currentPage.value} of ${totalPages.value}',
                  accent: accent,
                  onExpand: isDesktop
                      ? chromeNotifier.toggleNarrationPanel
                      : null,
                ),
              ),
            if (chromeState.chromeVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ReaderBarSurface(
                  style: settings.chromeStyle,
                  color: colorScheme.surfaceContainerHigh,
                  child: ReaderChromeBar(
                    title: titleText,
                    textColor: colorScheme.onSurface,
                    onSettingsTap: showSettingsSheet,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip: 'Back to Library',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    actions: [
                      if (totalPages.value > 0) ...[
                        IconButton(
                          icon: const Icon(Icons.zoom_out_rounded, size: 18),
                          tooltip: 'Zoom out',
                          onPressed: zoomOut,
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in_rounded, size: 18),
                          tooltip: 'Zoom in',
                          onPressed: zoomIn,
                        ),
                        if (isDesktop) ...[
                          IconButton(
                            icon: Icon(
                              chromeState.rightPanelVisible
                                  ? Icons.view_sidebar_rounded
                                  : Icons.view_sidebar_outlined,
                              size: 18,
                              color: colorScheme.onSurface,
                            ),
                            tooltip: 'Toggle outline & panels',
                            onPressed: chromeNotifier.toggleRightPanel,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        tooltip: 'Reading settings',
                        onPressed: showSettingsSheet,
                      ),
                    ],
                  ),
                ),
              ),
            if (chromeState.chromeVisible && totalPages.value > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ReaderBarSurface(
                  style: settings.chromeStyle,
                  color: colorScheme.surfaceContainerHigh,
                  child: PdfBottomNav(
                    textColor: colorScheme.onSurface,
                    currentPage: currentPage.value,
                    totalPages: totalPages.value,
                    onPageSelected: goToPage,
                    onSettingsTap: showSettingsSheet,
                    onOutlineTap: onOutlineNavTap,
                    onBookmarkTap: toggleBookmarkForCurrentPage,
                    isBookmarked: bookmarkedPages.value.contains(
                      currentPage.value,
                    ),
                    layoutMode: layoutMode.value,
                    onToggleLayoutMode: toggleLayoutMode,
                    onListenTap: onListenNavTap,
                    onAnnotationsTap: openAnnotationsSheet,
                    progressColor: accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
