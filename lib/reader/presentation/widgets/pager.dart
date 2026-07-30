import 'package:flutter/material.dart';

class Pager {
  static List<String> paginate({
    required String text,
    required TextStyle textStyle,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (text.isEmpty) return [''];
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final words = normalized.split(' ');
    final pages = <String>[];
    final painter = TextPainter(textDirection: TextDirection.ltr);

    bool fits(int start, int end) {
      painter.text = TextSpan(
        text: words.sublist(start, end).join(' '),
        style: textStyle,
      );
      painter.layout(maxWidth: pageWidth);
      return painter.height <= pageHeight;
    }

    int start = 0;
    while (start < words.length) {
      // Exponential ("galloping") search: grow the candidate end point by
      // doubling until it overflows the page (or we hit the end of the
      // chapter). This finds a bracket [lo, hi] close to the true boundary
      // in O(log pageSize) steps, instead of starting from the whole
      // remaining chapter every time.
      int lo = start;
      int hi = start + 1;
      if (hi > words.length) hi = words.length;

      while (hi < words.length && fits(start, hi)) {
        lo = hi;
        final span = (hi - start) * 2;
        hi = (start + span).clamp(start + 1, words.length);
      }

      if (hi == words.length && fits(start, hi)) {
        pages.add(words.sublist(start, hi).join(' '));
        start = hi;
        continue;
      }

      // Binary search the much smaller [lo, hi] bracket for the exact
      // boundary — every probe here measures roughly one page's worth of
      // text, not the whole remaining chapter.
      while (lo + 1 < hi) {
        final mid = (lo + hi) ~/ 2;
        if (fits(start, mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }

      // Guarantee forward progress even if a single word can't fit in the
      // page (e.g. an unusually long token) — avoids an infinite loop.
      final end = lo > start ? lo : start + 1;
      pages.add(words.sublist(start, end).join(' '));
      start = end;
    }

    return pages;
  }
}
