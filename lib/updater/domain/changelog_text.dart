/// Renders GitHub release-note markdown as the lightweight plain text the
/// What's-new UI shows. Deliberately dependency-free (no markdown package):
/// the release bodies produced by our release workflow only use headings,
/// bullets, bold and links, so a small deterministic formatter plus tests
/// beats pulling in a renderer.
abstract final class ChangelogText {
  /// Turns release-body markdown into display text:
  ///
  /// * `#`/`##` headings keep their text, minus the `#` markers,
  /// * bullets `- foo` / `* foo` become `  •  foo`,
  /// * `[label](url)` links collapse to `label (url)`,
  /// * `![alt](img)` images collapse to `(image: alt)`,
  /// * `**bold**` markers are dropped,
  /// * runs of blank lines collapse to one.
  static String render(String raw) {
    var text = raw.replaceAll('\r\n', '\n');
    text = _linkPattern.allMatches(text).fold(text, _replaceLink);
    text = _imagePattern.allMatches(text).fold(text, _replaceImage);
    text = _boldPattern.allMatches(text).fold(text, _replaceBold);

    final lines = <String>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue; // blank separators are dropped
      var trimmed = line.trimLeft();
      final heading = _headingPattern.firstMatch(trimmed);
      if (heading != null) {
        trimmed = heading.group(1)!;
      } else {
        final bullet = _bulletPattern.firstMatch(trimmed);
        if (bullet != null) {
          trimmed = '  •  ${bullet.group(1)!}';
        }
      }
      lines.add(trimmed);
    }
    return lines.join('\n');
  }

  static final RegExp _headingPattern = RegExp(r'^#{1,6}\s+(.*)$');
  static final RegExp _bulletPattern = RegExp(r'^[-*]\s+(.*)$');
  static final RegExp _boldPattern = RegExp(r'\*\*(.+?)\*\*');
  static final RegExp _linkPattern = RegExp(
    r'\[([^\]]+)\]\(([^)]+)\)',
  );
  static final RegExp _imagePattern = RegExp(
    r'!\[([^\]]*)\]\(([^)]+)\)',
  );

  static String _replaceLink(String text, RegExpMatch match) =>
      text.replaceRange(
        match.start,
        match.end,
        '${match.group(1)} (${match.group(2)})',
      );

  static String _replaceImage(String text, RegExpMatch match) => text
      .replaceRange(match.start, match.end, '(image: ${match.group(1)})');

  static String _replaceBold(String text, RegExpMatch match) =>
      text.replaceRange(match.start, match.end, match.group(1)!);
}
