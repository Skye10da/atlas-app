import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// How PDF pages are laid out in the reader.
enum PdfReaderLayoutMode {
  /// One page (or page spread) at a time, scrolled vertically.
  single,

  /// All pages flowing continuously in a horizontal strip.
  continuous,

  /// Book-style two-up facing pages, with an optional cover page.
  facing,
}

extension PdfReaderLayoutModeX on PdfReaderLayoutMode {
  String get label => switch (this) {
    PdfReaderLayoutMode.single => 'Single',
    PdfReaderLayoutMode.continuous => 'Continuous',
    PdfReaderLayoutMode.facing => 'Facing',
  };
}

/// A highlighted text selection kept on a page.
class PdfMarker {
  const PdfMarker(this.range, this.color);

  final PdfPageTextRange range;
  final Color color;
}

/// An in-memory note anchored to a page.
class PdfNoteEntry {
  const PdfNoteEntry({
    required this.pageNumber,
    required this.snippet,
    required this.text,
    required this.createdAt,
  });

  final int pageNumber;
  final String snippet;
  final String text;
  final DateTime createdAt;
}
