import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/reader/presentation/utils/pager_boundary.dart';
import 'package:atlas_app/settings/domain/value_objects/reading_preferences.dart';

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
class ChapterPager extends HookWidget {
  const ChapterPager({
    super.key,
    required this.itemCount,
    required this.controller,
    required this.itemBuilder,
    required this.onPageChanged,
    required this.onBoundaryTurn,
    this.animation = PageTurnAnimation.realFlip,
    this.enablePageFlipSound = false,
    this.enablePageFlipHaptics = true,
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

  /// Page turn animation type.
  final PageTurnAnimation animation;

  /// Whether paper curl sound is enabled for real flip.
  final bool enablePageFlipSound;

  /// Whether paper curl haptics are enabled for real flip.
  final bool enablePageFlipHaptics;

  /// While the shell animates a chapter transition, further intents are
  /// swallowed so one swipe can't fire twice.
  final bool turnLocked;

  /// Drag distance past an edge required before [onBoundaryTurn] fires.
  final double turnThreshold;

  @override
  Widget build(BuildContext context) {
    final edgeDrag = useMemoized(
      () => EdgeDragAccumulator(threshold: turnThreshold),
      [turnThreshold],
    );

    final prevItemCount = useRef(itemCount);
    useEffect(() {
      if (itemCount < prevItemCount.value && controller.hasClients) {
        final target = itemCount - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (!controller.hasClients) return;
          final page = controller.page ?? 0;
          if (page > target) controller.jumpToPage(target);
        });
      }
      prevItemCount.value = itemCount;
      return null;
    }, [itemCount]);

    bool onScrollNotification(ScrollNotification notification) {
      if (notification is ScrollEndNotification) {
        edgeDrag.reset();
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
      final intent = edgeDrag.add(
        pixels: metrics.pixels,
        minExtent: metrics.minScrollExtent,
        maxExtent: metrics.maxScrollExtent,
        delta: delta,
        fromDrag: fromDrag,
      );
      if (intent == BoundaryTurnIntent.none || turnLocked) return false;
      onBoundaryTurn(intent == BoundaryTurnIntent.forward);
      return false;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification,
      child: PageView.builder(
        controller: controller,
        itemCount: itemCount,
        onPageChanged: (page) {
          if (animation == PageTurnAnimation.realFlip) {
            if (enablePageFlipHaptics) {
              HapticFeedback.lightImpact();
            }
            if (enablePageFlipSound) {
              SystemSound.play(SystemSoundType.click);
            }
          }
          onPageChanged(page);
        },
        itemBuilder: itemBuilder,
      ),
    );
  }
}
