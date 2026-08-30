import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

/// Converts raw EPUB chapter XHTML/HTML into clean, semantic formatted text
/// while preserving paragraph breaks, headings, typography, blockquotes,
/// dividers, and embedded image references.
class EpubHtmlConverter {
  const EpubHtmlConverter();

  /// Converts [rawHtml] to semantic formatted text.
  ///
  /// [imageResolver] maps an HTML `src` / `href` attribute (e.g. `../images/fig1.png`)
  /// to its normalized local filename (e.g. `images/fig1.png`).
  String convert(
    String rawHtml, {
    String Function(String rawSrc)? imageResolver,
  }) {
    if (rawHtml.trim().isEmpty) return '';

    // Fast cleanup of non-content elements before full DOM walk
    final document = html_parser.parse(rawHtml);
    final body = document.body;
    if (body == null) return '';

    // Remove scripts, styles, noscript, etc.
    for (final el in body.querySelectorAll('script, style, noscript, iframe, template')) {
      el.remove();
    }

    final buffer = StringBuffer();
    _walkBlockNodes(body, buffer, imageResolver);

    final result = buffer.toString();
    return _normalizeWhitespace(result);
  }

  /// Extracts a chapter title from HTML if available (e.g. <h1>, <h2>, or <title>).
  String? extractTitle(String rawHtml) {
    if (rawHtml.trim().isEmpty) return null;
    final document = html_parser.parse(rawHtml);

    // Try first heading in body
    for (final selector in ['h1', 'h2', 'h3', 'title']) {
      final el = document.querySelector(selector);
      if (el != null) {
        final text = el.text.trim();
        if (text.isNotEmpty && text.length < 150) {
          return text;
        }
      }
    }
    return null;
  }

  void _walkBlockNodes(
    dom.Node node,
    StringBuffer buffer,
    String Function(String rawSrc)? imageResolver,
  ) {
    for (final child in node.nodes) {
      if (child is dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';

        if (tag == 'img') {
          _appendImage(child, buffer, imageResolver);
        } else if (tag == 'svg') {
          // Check for embedded <image> or <img> inside SVG
          final images = child.querySelectorAll('image, img');
          for (final img in images) {
            _appendImage(img, buffer, imageResolver);
          }
        } else if (tag == 'hr') {
          _appendBlock(buffer, '---');
        } else if (_isHeading(tag)) {
          final level = int.tryParse(tag.substring(1)) ?? 1;
          final prefix = '#' * level;
          final inlineText = _convertInline(child, imageResolver).trim();
          if (inlineText.isNotEmpty) {
            _appendBlock(buffer, '$prefix $inlineText');
          }
        } else if (tag == 'blockquote') {
          final quoteText = _convertInline(child, imageResolver).trim();
          if (quoteText.isNotEmpty) {
            final lines = quoteText.split('\n');
            final formatted = lines.map((l) => '> $l').join('\n');
            _appendBlock(buffer, formatted);
          }
        } else if (tag == 'ul' || tag == 'ol') {
          final isOrdered = tag == 'ol';
          var itemIndex = 1;
          final listBuffer = StringBuffer();
          for (final li in child.children.where((c) => c.localName == 'li')) {
            final itemText = _convertInline(li, imageResolver).trim();
            if (itemText.isNotEmpty) {
              final prefix = isOrdered ? '$itemIndex. ' : '• ';
              listBuffer.writeln('$prefix$itemText');
              itemIndex++;
            }
          }
          final listContent = listBuffer.toString().trim();
          if (listContent.isNotEmpty) {
            _appendBlock(buffer, listContent);
          }
        } else if (tag == 'pre') {
          final codeText = child.text.trim();
          if (codeText.isNotEmpty) {
            _appendBlock(buffer, '```\n$codeText\n```');
          }
        } else if (_isContainerBlock(tag)) {
          // Check if this container directly contains other block elements
          final hasBlockChildren = child.children.any(
            (c) => _isBlockTag(c.localName?.toLowerCase() ?? ''),
          );
          if (hasBlockChildren) {
            _walkBlockNodes(child, buffer, imageResolver);
          } else {
            final text = _convertInline(child, imageResolver).trim();
            if (text.isNotEmpty) {
              _appendBlock(buffer, text);
            }
          }
        } else {
          // Inline element at root level
          final text = _convertInline(child, imageResolver).trim();
          if (text.isNotEmpty) {
            _appendBlock(buffer, text);
          }
        }
      } else if (child is dom.Text) {
        final text = child.text.trim();
        if (text.isNotEmpty) {
          _appendBlock(buffer, text);
        }
      }
    }
  }

  String _convertInline(
    dom.Node node,
    String Function(String rawSrc)? imageResolver,
  ) {
    final buffer = StringBuffer();
    for (final child in node.nodes) {
      if (child is dom.Text) {
        buffer.write(child.text);
      } else if (child is dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';
        final innerText = _convertInline(child, imageResolver);

        switch (tag) {
          case 'b' || 'strong':
            if (innerText.trim().isNotEmpty) {
              buffer.write('**${innerText.trim()}**');
            }
          case 'i' || 'em':
            if (innerText.trim().isNotEmpty) {
              buffer.write('*${innerText.trim()}*');
            }
          case 'u':
            buffer.write(innerText);
          case 's' || 'del' || 'strike':
            if (innerText.trim().isNotEmpty) {
              buffer.write('~~${innerText.trim()}~~');
            }
          case 'code':
            if (innerText.trim().isNotEmpty) {
              buffer.write('`$innerText`');
            }
          case 'br':
            buffer.write('\n');
          case 'img':
            final rawSrc = child.attributes['src'] ??
                child.attributes['data-src'] ??
                child.attributes['xlink:href'] ??
                '';
            if (rawSrc.isNotEmpty) {
              final resolved = imageResolver?.call(rawSrc) ?? rawSrc;
              final alt = child.attributes['alt'] ?? '';
              buffer.write('\n\n![$alt]($resolved)\n\n');
            }
          case 'a':
            // Check for footnote reference
            final epubType = child.attributes['epub:type'] ?? '';
            final href = child.attributes['href'] ?? '';
            if (epubType == 'noteref' || href.startsWith('#fn') || href.startsWith('#note')) {
              buffer.write('[^$innerText]');
            } else {
              buffer.write(innerText);
            }
          default:
            buffer.write(innerText);
        }
      }
    }
    return buffer.toString();
  }

  String _resolveSrc(dom.Element el) {
    for (final entry in el.attributes.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key == 'src' || key == 'data-src' || key.endsWith('href')) {
        final val = entry.value.trim();
        if (val.isNotEmpty) return val;
      }
    }
    return '';
  }

  void _appendImage(
    dom.Element imgEl,
    StringBuffer buffer,
    String Function(String rawSrc)? imageResolver,
  ) {
    final rawSrc = _resolveSrc(imgEl);
    if (rawSrc.isNotEmpty) {
      final resolved = imageResolver?.call(rawSrc) ?? rawSrc;
      final alt = imgEl.attributes['alt'] ?? '';
      _appendBlock(buffer, '![$alt]($resolved)');
    }
  }

  void _appendBlock(StringBuffer buffer, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (buffer.isNotEmpty) {
      buffer.write('\n\n');
    }
    buffer.write(trimmed);
  }

  bool _isHeading(String tag) {
    return tag == 'h1' ||
        tag == 'h2' ||
        tag == 'h3' ||
        tag == 'h4' ||
        tag == 'h5' ||
        tag == 'h6';
  }

  bool _isContainerBlock(String tag) {
    return tag == 'p' ||
        tag == 'div' ||
        tag == 'section' ||
        tag == 'article' ||
        tag == 'main' ||
        tag == 'header' ||
        tag == 'footer' ||
        tag == 'aside';
  }

  bool _isBlockTag(String tag) {
    return _isHeading(tag) ||
        _isContainerBlock(tag) ||
        tag == 'blockquote' ||
        tag == 'ul' ||
        tag == 'ol' ||
        tag == 'li' ||
        tag == 'pre' ||
        tag == 'table' ||
        tag == 'hr' ||
        tag == 'figure' ||
        tag == 'figcaption' ||
        tag == 'img';
  }

  String _normalizeWhitespace(String text) {
    // Normalizes multiple consecutive blank lines to exactly double newlines (\n\n)
    // while preserving single newlines inside lists/blockquotes.
    return text
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Helper to normalize relative EPUB image paths against chapter href.
  static String normalizeImagePath(String chapterHref, String imageSrc) {
    if (imageSrc.startsWith('http://') || imageSrc.startsWith('https://')) {
      return imageSrc;
    }
    final cleanSrc = imageSrc.split('?').first.split('#').first;
    final chapterDir = p.dirname(chapterHref);
    if (chapterDir == '.' || chapterDir.isEmpty) {
      return p.normalize(cleanSrc).replaceAll(r'\', '/');
    }
    return p.normalize(p.join(chapterDir, cleanSrc)).replaceAll(r'\', '/');
  }
}
