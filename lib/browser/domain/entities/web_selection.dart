import 'dart:ui';

/// A text selection inside a loaded web page, reported by the page's JS
/// bridge. Coordinates are viewport-relative (i.e. relative to the top-left
/// of the web view widget).
class WebSelection {
  const WebSelection({
    required this.text,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.language,
  });

  final String text;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// Best-effort BCP-47 language tag from the page (e.g. `en`).
  final String? language;

  Offset get center => Offset((x1 + x2) / 2, (y1 + y2) / 2);
  Rect get rect => Rect.fromLTRB(x1, y1, x2, y2);
  bool get isEmpty => text.trim().isEmpty;
}