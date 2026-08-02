import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/atoms/app_loading.dart';
import 'package:atlas_app/core/design_system/molecules/app_error_state.dart';
import 'package:atlas_app/core/design_system/organisms/draggable_bottom_sheet.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/core/services/platform_service_provider.dart';
import 'package:atlas_app/reader/domain/entities/bookmark_entity.dart';
import 'package:atlas_app/reader/domain/entities/chapter_entity.dart';
import 'package:atlas_app/reader/domain/repository_interfaces/reader_repository_interface.dart';
import 'package:atlas_app/reader/presentation/providers/reader_providers.dart';
import 'package:atlas_app/reader/presentation/widgets/chapter_view.dart';
import 'package:atlas_app/reader/presentation/widgets/continuous_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/paged_reader_layout.dart';
import 'package:atlas_app/reader/presentation/widgets/settings/reader_settings_sheet.dart';
import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

class ReaderContent extends ConsumerStatefulWidget {
  const ReaderContent({
    super.key,
    required this.repo,
    required this.bookId,
    required this.settings,
  });

  final ReaderRepositoryInterface repo;
  final String bookId;
  final ReadingSettingsEntity settings;

  @override
  ConsumerState<ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends ConsumerState<ReaderContent> {
  ChapterEntity? _currentChapter;
  List<ChapterEntity> _chapters = [];
  double _scrollProgress = 0.0;
  String? _initialChapterId;
  double? _initialScrollProgress;
  bool _readQueryParam = false;
  bool _loading = true;
  String? _errorMessage;
  Set<String> _bookmarkedChapterIds = {};
  Timer? _saveDebounceTimer;
  PlatformService? _platformService;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void didUpdateWidget(ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final os = oldWidget.settings;
    final ns = widget.settings;
    if (os.keepScreenAwake != ns.keepScreenAwake ||
        os.brightness != ns.brightness ||
        os.followSystemBrightness != ns.followSystemBrightness) {
      _applySystemSettings();
    }
  }

  void _applySystemSettings() {
    final svc = ref.read(platformServiceProvider);
    _platformService = svc;
    final s = widget.settings;
    svc.setKeepScreenOn(s.keepScreenAwake);
    if (s.followSystemBrightness) {
      svc.resetBrightness();
    } else {
      svc.setBrightness(s.brightness, smooth: true);
    }
    if (s.autoOptimizeBrightness) {
      svc.optimizeForLowBattery();
    }
  }

  Future<void> _loadChapters() async {
    final result = await widget.repo.getChapters(widget.bookId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result is Failure<List<ChapterEntity>>) {
        _errorMessage = (result).error.userMessage;
        return;
      }
      final loaded = (result as Success<List<ChapterEntity>>).value;
      if (loaded.isEmpty) {
        _errorMessage = 'No chapters found.';
        return;
      }
      _chapters = loaded;
      final byId = _initialChapterId != null
          ? loaded.where((c) => c.id == _initialChapterId).toList()
          : const <ChapterEntity>[];
      _currentChapter ??= byId.isNotEmpty ? byId.first : loaded.first;
      _initialChapterId = null;
    });
    await _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final result = await widget.repo.getBookmarks(widget.bookId);
    if (!mounted) return;
    if (result is Success<List<BookmarkEntity>>) {
      setState(() {
        _bookmarkedChapterIds =
            result.value.map((b) => b.chapterId).toSet();
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    if (_bookmarkedChapterIds.contains(chapter.id)) {
      final result = await widget.repo.getBookmarks(widget.bookId);
      if (result is Success<List<BookmarkEntity>>) {
        final existing =
            result.value.where((b) => b.chapterId == chapter.id).toList();
        for (final b in existing) {
          await widget.repo.removeBookmark(b.id);
        }
      }
    } else {
      final now = DateTime.now();
      await widget.repo.addBookmark(BookmarkEntity(
        id: '${widget.bookId}_${chapter.id}_${now.millisecondsSinceEpoch}',
        bookId: widget.bookId,
        chapterId: chapter.id,
        position: 0,
        createdAt: now,
        updatedAt: now,
      ));
    }
    ref.invalidate(bookmarksProvider(widget.bookId));
    setState(() {
      if (_bookmarkedChapterIds.contains(chapter.id)) {
        _bookmarkedChapterIds.remove(chapter.id);
      } else {
        _bookmarkedChapterIds.add(chapter.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readQueryParam) {
      final params = GoRouterState.of(context).uri.queryParameters;
      _initialChapterId = params['chapterId'];
      final progressParam = params['progress'];
      _initialScrollProgress =
          progressParam != null ? double.tryParse(progressParam) : null;
      _readQueryParam = true;
    }
    _applySystemSettings();
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    if (_currentChapter != null) {
      _saveProgress(_currentChapter!);
    }
    _platformService?.setKeepScreenOn(false);
    _platformService?.resetBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoading());
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: AppErrorState(
          message: _errorMessage!,
          technicalDetails: _errorMessage!,
        ),
      );
    }

    final chapters = _chapters;
    final settings = widget.settings;

    final isBookmarked = _currentChapter != null &&
        _bookmarkedChapterIds.contains(_currentChapter!.id);

    final savedProgress = _scrollProgress > 0
        ? _scrollProgress
        : _initialScrollProgress;
    if (settings.readingMode == ReadingMode.continuous) {
      return ContinuousReaderLayout(
        chapters: chapters,
        settings: settings,
        currentChapterIndex: _currentChapter != null
            ? chapters.indexOf(_currentChapter!)
            : 0,
        bookmarkedChapterIds: _bookmarkedChapterIds,
        initialScrollProgress: savedProgress,
        onScrollProgress: _onContinuousScrollProgress,
        onCurrentChapterChanged: _onContinuousChapterChanged,
        onScrollDirectionChanged: _onScrollDirectionChanged,
        onSettingsTap: _showSettingsDrawer,
        onChapterSelected: (idx) {
          setState(() => _currentChapter = _chapters[idx]);
        },
        isBookmarked: isBookmarked,
        onBookmarkToggle: _toggleBookmark,
      );
    }

    return PagedReaderLayout(
      chapters: chapters,
      settings: settings,
      currentChapterIndex: chapters.indexOf(_currentChapter!),
      bookmarkedChapterIds: _bookmarkedChapterIds,
      initialProgress: savedProgress,
      onPageChanged: _onPagedPageChanged,
      onProgressChanged: _onPagedProgressChanged,
      onChapterSelected: _goToPagedChapter,
      onSettingsTap: _showSettingsDrawer,
      isBookmarked: isBookmarked,
      onBookmarkToggle: _toggleBookmark,
    );
  }

  void _onContinuousScrollProgress(double progress) {
    _scrollProgress = progress;
  }

  void _onContinuousChapterChanged(int index) {
    if (_currentChapter?.id != _chapters[index].id) {
      setState(() => _currentChapter = _chapters[index]);
      _saveProgress(_chapters[index]);
    }
  }

  void _onScrollDirectionChanged(ScrollDirection direction) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentChapter != null) _saveProgress(_currentChapter!);
    });
  }

  void _saveProgress(ChapterEntity chapter) async {
    await widget.repo.saveProgress(
      userId: 'local',
      bookId: widget.bookId,
      chapterId: chapter.id,
      percentage: _scrollProgress * 100,
      position: 0,
      totalPositions: 0,
    );
  }

  void _onPagedPageChanged(int chapterIndex) {
    setState(() => _currentChapter = _chapters[chapterIndex]);
    _saveProgress(_chapters[chapterIndex]);
  }

  void _onPagedProgressChanged(double progress) {
    _scrollProgress = progress;
  }

  void _goToPagedChapter(int index) {
    if (_currentChapter?.id != _chapters[index].id) {
      setState(() => _currentChapter = _chapters[index]);
    }
  }

  void _showSettingsDrawer() {
    DraggableBottomSheet.show(
      context: context,
      id: 'reader_settings',
      initialHeight: 0.8,
      child: ReaderSettingsSheet(
        initialSettings: widget.settings,
      ),
    );
  }
}
