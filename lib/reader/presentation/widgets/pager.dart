import 'package:flutter/material.dart';

class Pager {
  static final RegExp _whitespace = RegExp(r'\s');

  static List<String> paginate({
    required String text,
    required TextStyle textStyle,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (text.isEmpty) return [''];
    final pages = <String>[];
    final painter = TextPainter(textDirection: TextDirection.ltr);

    bool fits(int start, int end) {
      painter.text = TextSpan(
        text: text.substring(start, end),
        style: textStyle,
      );
      painter.layout(maxWidth: pageWidth);
      return painter.height <= pageHeight;
    }

    int start = 0;
    while (start < text.length) {
      // Exponential ("galloping") search: grow the candidate end point by
      // doubling until it overflows the page (or we hit the end of the
      // chapter). This finds a bracket [lo, hi] close to the true boundary
      // in O(log pageSize) steps, instead of starting from the whole
      // remaining chapter every time.
      int lo = start;
      int hi = start + 1;
      if (hi > text.length) hi = text.length;

      while (hi < text.length && fits(start, hi)) {
        lo = hi;
        final span = (hi - start) * 2;
        hi = (start + span).clamp(start + 1, text.length);
      }

      if (hi == text.length && fits(start, hi)) {
        pages.add(text.substring(start, hi));
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

      var end = lo > start ? lo : start + 1;
      // Back off to the last whitespace at or before `end` so a page never
      // splits a word — and since the original text (paragraph breaks and
      // indentation included) is kept verbatim, page strings stay
      // paragraph-accurate instead of being collapsed into single spaces.
      final ws = text.lastIndexOf(_whitespace, end - 1);
      if (ws > start) end = ws + 1;
      pages.add(text.substring(start, end));
      start = end;
    }

    return pages;
  }
}
