import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/error_handling/result.dart';
import 'package:atlas_app/reader/domain/entities/reading_progress_snapshot.dart';
import 'package:atlas_app/reader/infrastructure/repositories/drift_reader_repository.dart';

/// Renders an imported PDF (format == 'pdf'). Unlike the chapter-based reader,
/// this embeds a native PDF renderer (pdfx) that draws the original pages, so
/// the file is kept verbatim rather than split into text chapters.
///
/// [PdfViewPinch] (continuous scroll + pinch zoom) is used on touch platforms
/// while [PdfView] (single-page) is used on desktop, where PdfViewPinch is
/// unsupported. Reading progress is stored as page / total pages so the
/// library's progress bar and "Continue Reading" keep working.
class PdfReaderContent extends ConsumerStatefulWidget {
  const PdfReaderContent({
    super.key,
    required this.bookId,
    required this.pdfPath,
  });

  final String bookId;
  final String pdfPath;

  @override
  ConsumerState<PdfReaderContent> createState() => _PdfReaderContentState();
}

class _PdfReaderContentState extends ConsumerState<PdfReaderContent> {
  static const _pdfBuilders =
      PdfViewBuilders<DefaultBuilderOptions>(options: DefaultBuilderOptions());
  static const _pinchBuilders =
      PdfViewPinchBuilders<DefaultBuilderOptions>(options: DefaultBuilderOptions());

  PdfController? _controller;
  PdfControllerPinch? _pinchController;
  ValueListenable<int>? _pageListenable;

  bool _loading = true;
  bool _initialized = false;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  Timer? _saveDebounce;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = DriftReaderRepository(ref.read(databaseProvider));
    try {
      var startPage = 1;
      final progressResult =
          await repo.getReadingProgress(widget.bookId);
      if (progressResult is Success<ReadingProgressSnapshot?> &&
          progressResult.value != null &&
          progressResult.value!.position > 0) {
        startPage = progressResult.value!.position;
      }

      final document = await PdfDocument.openFile(widget.pdfPath);
      final page = startPage.clamp(1, document.pagesCount);

      if (_isDesktop) {
        _controller = PdfController(
          document: Future.value(document),
          initialPage: page,
        );
        _pageListenable = _controller!.pageListenable;
      } else {
        _pinchController = PdfControllerPinch(
          document: Future.value(document),
          initialPage: page,
        );
        _pageListenable = _pinchController!.pageListenable;
      }

      if (!mounted) return;
      setState(() {
        _totalPages = document.pagesCount;
        _currentPage = page;
        _loading = false;
        _initialized = true;
      });
      _pageListenable!.addListener(_onPageChanged);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to open PDF: $e';
      });
    }
  }

  void _onPageChanged() {
    final page = _controller?.page ?? _pinchController?.page;
    if (page == null || page == _currentPage) return;
    setState(() => _currentPage = page);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _saveProgress);
  }

  Future<void> _saveProgress() async {
    if (_totalPages == 0) return;
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

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pageListenable?.removeListener(_onPageChanged);
    _controller?.dispose();
    _pinchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A3A3A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white, onPressed: () => Navigator.of(context).maybePop()),
        actions: [
          if (_initialized)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _initialized
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_totalPages == 0) {
      return const Center(
        child: Text('No pages found', style: TextStyle(color: Colors.white)),
      );
    }
    final controller = _controller;
    if (controller != null) {
      return PdfView(
        controller: controller,
        builders: _pdfBuilders,
        onPageChanged: (page) {
          if (page != _currentPage) {
            setState(() => _currentPage = page.clamp(1, _totalPages));
            _saveDebounce?.cancel();
            _saveDebounce = Timer(const Duration(milliseconds: 400), _saveProgress);
          }
        },
      );
    }
    final pinch = _pinchController!;
    return PdfViewPinch(
      controller: pinch,
      builders: _pinchBuilders,
      onPageChanged: (page) {
        if (page != _currentPage) {
          setState(() => _currentPage = page.clamp(1, _totalPages));
          _saveDebounce?.cancel();
          _saveDebounce = Timer(const Duration(milliseconds: 400), _saveProgress);
        }
      },
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: const Color(0xFF2E2E2E),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _currentPage > 1 ? _previousPage : null,
          ),
          Expanded(
            child: Slider(
              value: _currentPage.toDouble(),
              min: 1,
              max: _totalPages.toDouble(),
              activeColor: Colors.white,
              inactiveColor: Colors.white38,
              onChanged: _totalPages > 1
                  ? (value) {
                      setState(() => _currentPage = value.round());
                      _jumpTo(_currentPage);
                    }
                  : null,
              onChangeEnd: (_) => _saveProgress(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _currentPage < _totalPages ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Future<void> _previousPage() async {
    final controller = _controller;
    if (controller != null) {
      await controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      await _pinchController?.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _nextPage() async {
    final controller = _controller;
    if (controller != null) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      await _pinchController?.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpTo(int page) {
    _controller?.jumpToPage(page);
    _pinchController?.jumpToPage(page);
  }
}