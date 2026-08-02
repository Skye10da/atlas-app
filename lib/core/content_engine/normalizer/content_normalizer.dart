import 'package:atlas_app/core/content_engine/models/atlas_document.dart';
import 'package:atlas_app/core/content_engine/parser/dom_parser.dart';
import 'package:html/dom.dart';

/// Normalization options for turning cleaned chapter HTML into a canonical
/// [AtlasDocument].
class NormalizerOptions {
  const NormalizerOptions({
    this.title,
    this.metadata = const DocumentMetadata(),
  });

  final String? title;
  final DocumentMetadata metadata;
}

/// Converts a cleaned content DOM into the canonical [AtlasDocument].
///
/// This is the stage boundary: everything downstream consumes the typed
/// document, never raw HTML. Block extraction follows document order so a
/// future reader can reconstruct the original sequence.
class ContentNormalizer {
  const ContentNormalizer({this.parser = const DomParser()});

  final DomParser parser;

  AtlasDocument normalizeFromHtml(
    String html, {
    NormalizerOptions options = const NormalizerOptions(),
  }) {
    final doc = parser.parse(html);
    final body = doc.body;
    if (body == null) {
      return AtlasDocument(
        title: options.title ?? '',
        metadata: options.metadata,
      );
    }
    return normalizeFromElement(
      body,
      options: options,
    );
  }

  AtlasDocument normalizeFromElement(
    Element root, {
    NormalizerOptions options = const NormalizerOptions(),
  }) {
    final blocks = <ContentBlock>[];
    final annotations = <Annotation>[];

    _walk(root, blocks, annotations);

    return AtlasDocument(
      title: options.title ?? '',
      blocks: blocks,
      annotations: annotations,
      metadata: options.metadata,
    );
  }

  void _walk(
    Node node,
    List<ContentBlock> blocks,
    List<Annotation> annotations, {
    bool skipBlocks = false,
  }) {
    for (final child in node.nodes) {
      if (child is Element) {
        _walkElement(child, blocks, annotations, skipBlocks: skipBlocks);
      }
    }
  }

  void _walkElement(
    Element el,
    List<ContentBlock> blocks,
    List<Annotation> annotations, {
    bool skipBlocks = false,
  }) {
    final tag = el.localName ?? '';

    if (tag == 'img') {
      final src = el.attributes['src'] ?? el.attributes['data-src'] ?? '';
      if (src.isNotEmpty) {
        blocks.add(ImageBlock(
          src: src,
          alt: el.attributes['alt'],
          caption: _captionFor(el),
        ));
      }
      return;
    }

    if (_isBlockTag(tag)) {
      // Outermost-block-owns-text semantics: a block element captures the
      // fully flattened text of its whole subtree and becomes a single block.
      // Nested block descendants do not emit their own block — their text is
      // already owned by the outer block — so nothing is double-counted and no
      // loose inline text is dropped. The recursion below still collects
      // images and footnotes within the subtree.
      if (!skipBlocks) {
        final text = _textOf(el).trim();
        if (text.isNotEmpty) {
          blocks.add(_blockFor(tag, text));
        }
      }
      _walk(el, blocks, annotations, skipBlocks: true);
      return;
    }

    if (tag == 'a') {
      final text = el.text.trim();
      final href = el.attributes['href'];
      if (href != null && _isFootnoteLink(href, el)) {
        blocks.add(FootnoteBlock(id: _normalizeHref(href), text: text));
        return;
      }
    }

    if (tag == 'hr') return;

    // Generic containers (div, span, section, article, ...): recurse.
    _walk(el, blocks, annotations, skipBlocks: skipBlocks);
  }

  bool _isBlockTag(String tag) => _blockTags.contains(tag);

  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'li',
    'pre',
  };

  ContentBlock _blockFor(String tag, String text) {
    switch (tag) {
      case 'p':
        return ParagraphBlock(text: text);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return HeadingBlock(text: text, level: int.parse(tag.substring(1)));
      case 'blockquote':
        return QuoteBlock(text: text);
      case 'li':
        return ListBlock(text: text);
      case 'pre':
        return PreBlock(text: text);
      default:
        return ParagraphBlock(text: text);
    }
  }

  String? _captionFor(Element imgEl) {
    final figure = imgEl.parent;
    if (figure != null && figure.localName == 'figure') {
      final caption = figure.querySelector('figcaption');
      if (caption != null) {
        final text = caption.text.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  bool _isFootnoteLink(String href, Element el) {
    if (href.startsWith('#')) return true;
    return el.attributes['rel'] == 'footnote' ||
        el.attributes['class']?.contains('footnote') == true;
  }

  String _normalizeHref(String href) =>
      href.startsWith('#') ? href.substring(1) : href;

  String _textOf(Element el) {
    final buffer = StringBuffer();
    void collect(Node n) {
      if (n is Text) {
        buffer.write(n.text);
      } else if (n is Element) {
        for (final child in n.nodes) {
          collect(child);
        }
      }
    }

    for (final n in el.nodes) {
      collect(n);
    }
    return buffer.toString().replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();
  }
}
