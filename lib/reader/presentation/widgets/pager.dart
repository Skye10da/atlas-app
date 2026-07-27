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

    int start = 0;
    while (start < words.length) {
      int low = start;
      int high = words.length;
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        painter.text = TextSpan(
          text: words.sublist(start, mid).join(' '),
          style: textStyle,
        );
        painter.layout(maxWidth: pageWidth);
        if (painter.height <= pageHeight) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      pages.add(words.sublist(start, low).join(' '));
      start = low;
    }

    return pages;
  }
}
