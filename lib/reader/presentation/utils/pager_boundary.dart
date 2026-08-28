/// Pure decision logic for the chapter-scoped paged reader.
///
/// Everything here is deliberately free of Flutter widget dependencies so it
/// can be unit-tested without pumping widgets. The widget layer
/// (`ChapterPager`, `PagedReaderLayout`) wires scroll notifications into
/// [EdgeDragAccumulator] and feeds [chapterFraction] to the progress bar.
library;

/// Which side of a chapter's local pager the reader wants to leave across.
enum BoundaryTurnIntent { none, forward, backward }

/// Accumulates horizontal drag distance that spills past an inner pager's
/// leading/trailing edge and resolves it into a chapter-turn intent.
///
/// A nested PageView never contains foreign pages, so crossing a chapter
/// boundary is a matter of *intent at the edge*: while the inner pager sits
/// at its first/last page, continued dragging produces either an
/// `OverscrollNotification` (clamping physics) or scroll updates whose pixel
/// position travels past the extent (bouncing physics). Both shapes carry a
/// signed delta — positive toward the next page — and are fed here verbatim.
///
/// Deltas only accumulate while they share one direction; flipping direction
/// resets the pending distance, so a hesitant swipe never fires a turn. Once
/// the pending magnitude crosses [threshold], the intent is returned once and
/// the accumulator resets — the caller is expected to lock further intents
/// until the chapter transition animation finishes.
class EdgeDragAccumulator {
  EdgeDragAccumulator({this.threshold = 64.0});

  /// Drag distance (logical pixels) that must spill past the edge before a
  /// chapter turn fires.
  final double threshold;

  double _pending = 0;

  /// Folds one scroll event into the pending accumulation and returns the
  /// resolved intent, if any. [pixels]/[minExtent]/[maxExtent] come straight
  /// from the notification's [ScrollMetrics]-like values; [delta] is the
  /// signed scroll (or overscroll) amount, positive toward later pages.
  ///
  /// [fromDrag] must be true only for gesture-driven deltas (non-null
  /// dragDetails on the notification). Programmatic scrolls — clamp jumps,
  /// resume restores, keyboard paging — also produce edge-landing deltas;
  /// feeding them here would misread them as swipes past the seam.
  BoundaryTurnIntent add({
    required double pixels,
    required double minExtent,
    required double maxExtent,
    required double delta,
    required bool fromDrag,
  }) {
    if (!fromDrag || delta == 0) return BoundaryTurnIntent.none;
    final atTrailingEdge =
        delta > 0 && pixels >= maxExtent - precisionTolerance;
    final atLeadingEdge = delta < 0 && pixels <= minExtent + precisionTolerance;
    if (!atTrailingEdge && !atLeadingEdge) {
      _pending = 0;
      return BoundaryTurnIntent.none;
    }
    // A single-page pager sits at both edges at once; direction alone
    // disambiguates, which the sign of [_pending] already tracks below.
    if (_pending != 0 && (_pending.sign != delta.sign)) _pending = 0;
    _pending += delta;
    if (_pending.abs() >= threshold) {
      _pending = 0;
      return delta > 0
          ? BoundaryTurnIntent.forward
          : BoundaryTurnIntent.backward;
    }
    return BoundaryTurnIntent.none;
  }

  /// Discards pending accumulation — call when scrolling ends or the pager
  /// loses the gesture, so stale distance never fires a later turn.
  void reset() => _pending = 0;

  static const double precisionTolerance = 0.5;
}

/// How many two-page spreads a chapter with [pageCount] pages occupies on a
/// wide desktop layout. An odd page count leaves the final spread's right
/// half blank — the standard e-reader convention.
int spreadCount(int pageCount) => pageCount <= 0 ? 0 : (pageCount + 1) ~/ 2;

/// Whole-book progress fraction for the chrome bar, expressed as a
/// chapter-based fraction: how far into chapter [chapterIndexLocal] of
/// [chapterCount] the reader is, weighted by [localIndex] within that
/// chapter's [localCount] pages (or spreads).
///
/// Deliberately independent of any cross-chapter page-count sums — the flat
/// arithmetic this replaces was the root of the desync bugs the nested pager
/// exists to eliminate. This is a display/persistence heuristic only; exact
/// resume always goes through the sentence-position resolver instead.
double chapterFraction({
  required int chapterIndex,
  required int chapterCount,
  required int localIndex,
  required int localCount,
}) {
  if (chapterCount <= 0) return 0;
  if (localCount <= 0) return chapterIndex / chapterCount;
  final within = ((localIndex + 1) / localCount).clamp(0.0, 1.0);
  return ((chapterIndex + within) / chapterCount).clamp(0.0, 1.0);
}
