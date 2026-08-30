import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:atlas_app/reader/domain/entities/reader_annotation_entity.dart';

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
  const PdfMarker({
    required this.pageNumber,
    required this.start,
    required this.end,
    required this.text,
    required this.bounds,
    required this.color,
    this.styleType = HighlightStyleType.solid,
  });

  final int pageNumber;
  final int start;
  final int end;
  final String text;
  final PdfRect bounds;
  final Color color;
  final HighlightStyleType styleType;

  PdfMarkerRange get range => PdfMarkerRange(
        pageNumber: pageNumber,
        start: start,
        end: end,
        text: text,
        bounds: bounds,
      );
}

class PdfMarkerRange {
  const PdfMarkerRange({
    required this.pageNumber,
    required this.start,
    required this.end,
    required this.text,
    required this.bounds,
  });

  final int pageNumber;
  final int start;
  final int end;
  final String text;
  final PdfRect bounds;
}

/// A user note anchored to a page or passage in a PDF.
class PdfNoteEntry {
  const PdfNoteEntry({
    this.id = '',
    required this.pageNumber,
    required this.snippet,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.colorValue,
    this.tags = const [],
    this.styleType = HighlightStyleType.solid,
    this.highlightStart,
    this.highlightEnd,
  });

  final String id;
  final int pageNumber;
  final String snippet;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? colorValue;
  final List<String> tags;
  final HighlightStyleType styleType;
  final int? highlightStart;
  final int? highlightEnd;
}
