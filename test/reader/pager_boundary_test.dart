import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/reader/presentation/utils/pager_boundary.dart';

void main() {
  group('EdgeDragAccumulator', () {
    test('fires forward after trailing-edge drag crosses the threshold', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      // Sitting at the last page: pixels == maxScrollExtent.
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 40,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      expect(
        acc.add(
          pixels: 140,
          minExtent: 0,
          maxExtent: 100,
          delta: 30,
          fromDrag: true,
        ),
        BoundaryTurnIntent.forward,
      );
    });

    test('fires backward after leading-edge drag crosses the threshold', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      expect(
        acc.add(
          pixels: 0,
          minExtent: 0,
          maxExtent: 100,
          delta: -30,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      expect(
        acc.add(
          pixels: -30,
          minExtent: 0,
          maxExtent: 100,
          delta: -40,
          fromDrag: true,
        ),
        BoundaryTurnIntent.backward,
      );
    });

    test('ignores drag while away from the edge it points at', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      expect(
        acc.add(
          pixels: 50,
          minExtent: 0,
          maxExtent: 100,
          delta: 500,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      expect(
        acc.add(
          pixels: 50,
          minExtent: 0,
          maxExtent: 100,
          delta: -500,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
    });

    test('direction flip resets pending distance', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 60,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      // Reader changes their mind mid-swipe; the earlier 60px must not
      // combine with this opposite delta.
      expect(
        acc.add(
          pixels: 90,
          minExtent: 0,
          maxExtent: 100,
          delta: -30,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 63,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
    });

    test('resets after firing so a single swipe fires once', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 70,
          fromDrag: true,
        ),
        BoundaryTurnIntent.forward,
      );
      expect(
        acc.add(
          pixels: 170,
          minExtent: 0,
          maxExtent: 100,
          delta: 10,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
    });

    test('reset() discards pending distance between gestures', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      acc.add(
        pixels: 100,
        minExtent: 0,
        maxExtent: 100,
        delta: 60,
        fromDrag: true,
      );
      acc.reset();
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 60,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
    });

    test('handles clamping physics shape (overscroll past a held extent)', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      // Android: metrics stay pinned at max; excess arrives as the delta.
      var fired = BoundaryTurnIntent.none;
      for (var i = 0; i < 5; i++) {
        final result = acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 16,
          fromDrag: true,
        );
        if (result != BoundaryTurnIntent.none) fired = result;
      }
      expect(fired, BoundaryTurnIntent.forward);
    });

    test('single-page pager turns in either direction from offset zero', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      expect(
        acc.add(
          pixels: 0,
          minExtent: 0,
          maxExtent: 0,
          delta: 70,
          fromDrag: true,
        ),
        BoundaryTurnIntent.forward,
      );
      expect(
        acc.add(
          pixels: 0,
          minExtent: 0,
          maxExtent: 0,
          delta: -70,
          fromDrag: true,
        ),
        BoundaryTurnIntent.backward,
      );
    });
  });

  group('programmatic scroll gating', () {
    test('non-drag deltas never resolve to an intent', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      // A jumpToPage landing on the last page produces a huge edge-landing
      // delta indistinguishable from an overscroll swipe by size alone —
      // only its missing dragDetails marks it as not-a-gesture.
      expect(
        acc.add(
          pixels: 100,
          minExtent: 0,
          maxExtent: 100,
          delta: 5000,
          fromDrag: false,
        ),
        BoundaryTurnIntent.none,
      );
    });

    test('ignored non-drag deltas leave pending accumulation untouched', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      acc.add(
        pixels: 100,
        minExtent: 0,
        maxExtent: 100,
        delta: 60,
        fromDrag: true,
      );
      acc.add(
        pixels: 100,
        minExtent: 0,
        maxExtent: 100,
        delta: 4000,
        fromDrag: false,
      );
      expect(
        acc.add(
          pixels: 160,
          minExtent: 0,
          maxExtent: 100,
          delta: 5,
          fromDrag: true,
        ),
        BoundaryTurnIntent.forward,
      );
    });

    test('a real edge drag still turns after a programmatic clamp jump', () {
      final acc = EdgeDragAccumulator(threshold: 64);
      acc.add(
        pixels: 100,
        minExtent: 0,
        maxExtent: 100,
        delta: 300,
        fromDrag: false,
      );
      expect(
        acc.add(
          pixels: 140,
          minExtent: 0,
          maxExtent: 100,
          delta: 40,
          fromDrag: true,
        ),
        BoundaryTurnIntent.none,
      );
      expect(
        acc.add(
          pixels: 180,
          minExtent: 0,
          maxExtent: 100,
          delta: 30,
          fromDrag: true,
        ),
        BoundaryTurnIntent.forward,
      );
    });
  });

  group('spreadCount', () {
    test('pairs pages and leaves an odd tail single', () {
      expect(spreadCount(0), 0);
      expect(spreadCount(1), 1);
      expect(spreadCount(2), 1);
      expect(spreadCount(3), 2);
      expect(spreadCount(10), 5);
      expect(spreadCount(11), 6);
    });
  });

  group('chapterFraction', () {
    test('is monotonic within and across chapters', () {
      double at(int ch, int local) => chapterFraction(
        chapterIndex: ch,
        chapterCount: 10,
        localIndex: local,
        localCount: 20,
      );
      expect(at(3, 4), lessThan(at(3, 5)));
      expect(at(3, 19), lessThan(at(4, 0)));
      expect(at(8, 19), lessThan(at(9, 19)));
    });

    test('reaches ~1.0 only on the last page of the last chapter', () {
      final last = chapterFraction(
        chapterIndex: 9,
        chapterCount: 10,
        localIndex: 19,
        localCount: 20,
      );
      expect(last, closeTo(1.0, 0.001));
    });

    test('handles empty inputs defensively', () {
      expect(
        chapterFraction(
          chapterIndex: 0,
          chapterCount: 0,
          localIndex: 0,
          localCount: 0,
        ),
        0,
      );
      expect(
        chapterFraction(
          chapterIndex: 2,
          chapterCount: 5,
          localIndex: 0,
          localCount: 0,
        ),
        closeTo(0.4, 0.001),
      );
    });

    test('first page of first chapter is just past zero', () {
      final f = chapterFraction(
        chapterIndex: 0,
        chapterCount: 10,
        localIndex: 0,
        localCount: 20,
      );
      expect(f, greaterThan(0));
      expect(f, lessThan(0.01));
    });
  });
}
