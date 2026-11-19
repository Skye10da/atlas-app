// Scroll-driven auto-hide for navigation chrome (bottom pill / rail).
//
// The shell owns the nav chrome, but scrolling happens in per-branch content
// nested under the shell's Navigator. Scroll notifications bubble up through
// that tree, so a single NotificationListener at the shell can observe every
// tab's scrolling without any per-screen scroll controllers.
//
// Convention notes:
// * Only VERTICAL scrolling reacts — horizontal carousels inside a tab must
//   never hide the nav.
// * Hiding is direction-based: scroll down (reverse) hides, scroll up
//   (forward) shows, settling at the top shows.
// * `forceHidden` (e.g. narration active on the phone shell) keeps the chrome
//   hidden regardless of scrolling; when the force clears, the state resets
//   so the chrome returns.

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart'
    show
        Axis,
        ScrollNotification,
        ScrollUpdateNotification,
        UserScrollNotification,
        VoidCallback;
import 'package:flutter_hooks/flutter_hooks.dart';

/// Handle returned by [useNavAutoHide].
class NavAutoHideState {
  const NavAutoHideState({
    required this.hidden,
    required this.onScroll,
    required this.reveal,
  });

  /// True when the chrome should be out of the way.
  final bool hidden;

  /// Wire into a `NotificationListener<ScrollNotification>` around the shell
  /// content. Always returns false (never swallows notifications).
  ///
  /// Takes the general [ScrollNotification] (not just `UserScrollNotification`)
  /// because the user-direction notification fires once at drag *start* —
  /// when `pixels` is still 0 — while the actual movement arrives as
  /// [ScrollUpdateNotification]s carrying deltas.
  final bool Function(ScrollNotification notification) onScroll;

  /// Force the chrome visible again (the reveal button).
  final VoidCallback reveal;
}

/// Scroll-driven auto-hide state for floating navigation chrome.
///
/// [forceHidden] pins the hidden state (narration docking) and auto-resets
/// the scroll state whenever it toggles, so the chrome reappears cleanly
/// once the force clears.
NavAutoHideState useNavAutoHide({bool forceHidden = false}) {
  final scrollHidden = useState(false);
  final hidden = forceHidden || scrollHidden.value;

  // When the force clears (narration stopped), drop any scroll-hide left
  // over from before so the chrome returns instead of staying collapsed.
  useEffect(() {
    if (forceHidden) scrollHidden.value = false;
    return null;
  }, [forceHidden]);

  void reveal() => scrollHidden.value = false;

  bool onScroll(ScrollNotification notification) {
    // Horizontal carousels inside a tab must not hide vertical nav chrome.
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 0) {
        // Only hide once actually scrolled into content — the rubber-band
        // overscroll at the very top is not an intent to hide.
        if (notification.metrics.pixels > 0) scrollHidden.value = true;
      } else if (delta < 0) {
        scrollHidden.value = false;
      }
    } else if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.forward:
          scrollHidden.value = false;
        case ScrollDirection.idle:
          // Settling back at the top always shows the chrome.
          if (notification.metrics.pixels <= 0) scrollHidden.value = false;
        case ScrollDirection.reverse:
          break; // Hide is driven by the update deltas above.
      }
    }
    return false;
  }

  return NavAutoHideState(hidden: hidden, onScroll: onScroll, reveal: reveal);
}
