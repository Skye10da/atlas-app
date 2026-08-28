import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/utils/pager_boundary.dart';

/// The pager scoped to ONE chapter's own panels — pages on handset, two-page
/// spreads on wide desktop. It knows nothing about chapters, books, or any
/// cross-chapter arithmetic: the shell hands it a count, a controller, and an
/// item builder, and receives back page-change events plus edge-turn intents.
///
/// Chapter boundaries are crossed by *intent*: while this pager rests on its
/// first/last panel, continued dragging spills past the extent and is folded
/// into an [EdgeDragAccumulator]; once the spill crosses [turnThreshold] the
/// shell is asked to turn the chapter instead. The shell owns the transition
/// (animating the OUTER chapter pager), so no cross-chapter page math ever
/// happens here.
class ChapterPager extends StatefulWidget {
  const ChapterPager({
    super.key,
    required this.itemCount,
    required this.controller,
    required this.itemBuilder,
    required this.onPageChanged,
    required this.onBoundaryTurn,
    this.turnLocked = false,
    this.turnThreshold = 64.0,
  });

  /// Number of locally addressable panels (pages, or spreads in wide-desktop
  /// mode), derived from one chapter's real page cache. Must be > 0; the
  /// shell renders the shimmer state itself while pages are missing.
  final int itemCount;

  /// Controller for this chapter's panels. Owned by the shell so keyboard,
  /// tap-zone, seam and resume logic can all address the same position.
  final PageController controller;

  /// Builds the visual for panel [int]. Receives the raw logical index —
  /// clamping, spread pairing, and page-turn animation wrapping are all the
  /// builder's concern.
  final IndexedWidgetBuilder itemBuilder;

  /// Reports the panel the reader settled on.
  final ValueChanged<int> onPageChanged;

  /// The reader dragged past the leading ([forward] = false) or trailing
  /// ([forward] = true) edge far enough to want the neighboring chapter.
  final void Function(bool forward) onBoundaryTurn;

  /// While the shell animates a chapter transition, further intents are
  /// swallowed so one swipe can't fire twice.
  final bool turnLocked;

  /// Drag distance past an edge required before [onBoundaryTurn] fires.
  final double turnThreshold;

  @override
  State<ChapterPager> createState() => _ChapterPagerState();
}

class _ChapterPagerState extends State<ChapterPager> {
  late final EdgeDragAccumulator _edgeDrag = EdgeDragAccumulator(
    threshold: widget.turnThreshold,
  );

  @override
  void didUpdateWidget(ChapterPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Repagination can shrink a chapter (smaller font, wider viewport).
    // Keep the reader anchored to the chapter's last existing panel instead
    // of letting the controller hold a now-impossible index.
    if (widget.itemCount < oldWidget.itemCount &&
        widget.controller.hasClients) {
      final target = widget.itemCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!widget.controller.hasClients) return;
        final page = widget.controller.page ?? 0;
        if (page > target) widget.controller.jumpToPage(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: PageView.builder(
        controller: widget.controller,
        itemCount: widget.itemCount,
        onPageChanged: widget.onPageChanged,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _edgeDrag.reset();
      return false;
    }
    double? delta;
    var fromDrag = false;
    final metrics = notification.metrics;
    if (notification is OverscrollNotification) {
      delta = notification.overscroll;
      fromDrag = notification.dragDetails != null;
    } else if (notification is ScrollUpdateNotification) {
      delta = notification.scrollDelta;
      fromDrag = notification.dragDetails != null;
    }
    if (delta == null || delta == 0) return false;
    final intent = _edgeDrag.add(
      pixels: metrics.pixels,
      minExtent: metrics.minScrollExtent,
      maxExtent: metrics.maxScrollExtent,
      delta: delta,
      fromDrag: fromDrag,
    );
    if (intent == BoundaryTurnIntent.none || widget.turnLocked) return false;
    widget.onBoundaryTurn(intent == BoundaryTurnIntent.forward);
    return false;
  }
}
