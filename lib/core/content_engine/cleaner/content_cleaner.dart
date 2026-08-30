import 'package:html/dom.dart';

/// Default structural elements that are never part of reading content.
const defaultStripSelectors = <String>[
  'script',
  'style',
  'noscript',
  'template',
  'iframe',
  'object',
  'embed',
  'svg',
  'form',
  'header',
  'footer',
  'nav',
  'aside',
  'dialog',
];

/// Selectors for content that is not part of a chapter's reading text but is
/// frequently injected by web novel sites.
const defaultAdSelectors = <String>[
  'ins.adsbygoogle',
  'div.ad',
  'div.ads',
  'div.advertisement',
  '.adsbygoogle',
  '[class*="ad-container"]',
  '[class*="advert"]',
  '[id*="advert"]',
  '.sponsored',
  '.promo',
  '.popup',
  '.modal',
  '.cookie-banner',
  '.social-share',
  '.share-buttons',
  '.comment-section',
  '#comments',
  '.related-posts',
  '.similar-novels',
  '.prev-next',
  '.pagination',
  '.chapter-nav',
  '.breadcrumbs',
  '[class*="author-box"]',
];

/// Strips ads, scripts, navigation and other non-content elements from a DOM
/// tree. Always operates on the DOM, never on raw text.
class ContentCleaner {
  const ContentCleaner({
    this.extraStripSelectors = const [],
    this.disableDefaultStrips = false,
  });

  /// Additional selectors from the plugin's `filters.json` /
  /// `extraStripSelectors`. Applied on top of the defaults.
  final List<String> extraStripSelectors;

  /// When true, only [extraStripSelectors] are applied and the built-in
  /// default lists are skipped.
  final bool disableDefaultStrips;

  List<String> get _selectors => [
    if (!disableDefaultStrips) ...defaultStripSelectors,
    if (!disableDefaultStrips) ...defaultAdSelectors,
    ...extraStripSelectors,
  ];

  Element? clean(Element? root) {
    if (root == null) return null;
    for (final selector in _selectors) {
      for (final el in root.querySelectorAll(selector)) {
        el.remove();
      }
    }
    _removeCommentNodes(root);
    _removeEmptyNoise(root);
    return root;
  }

  void _removeCommentNodes(Node node) {
    node.nodes.removeWhere((n) => n is Comment);
    for (final child in node.nodes) {
      if (child is Element) _removeCommentNodes(child);
    }
  }

  static const _targetNoiseTags = {
    'p',
    'div',
    'span',
    'section',
    'article',
    'em',
    'strong',
    'b',
    'i',
    'u',
    'blockquote',
    'li',
  };

  /// Removes empty elements that add no reading value but inflate the DOM
  /// (e.g. `<p>`, `<div>`, `<span>` wrappers that became empty — or
  /// whitespace-only — after the strip pass).
  ///
  /// Uses a single post-order bottom-up pass so nested empty elements
  /// (e.g. `<div><p><span></span></p></div>`) are pruned in one pass without
  /// looping or repeated CSS queries.
  void _removeEmptyNoise(Element root) {
    _cleanPostOrder(root);
  }

  void _cleanPostOrder(Element el) {
    for (final child in List<Node>.from(el.nodes)) {
      if (child is Element) {
        _cleanPostOrder(child);
      }
    }

    if (_targetNoiseTags.contains(el.localName)) {
      if (!_isEffectivelyEmpty(el)) return;

      if (el.attributes.isNotEmpty) {
        final meaningful = el.attributes.keys.any((k) => k != 'style');
        if (meaningful) return;
      }

      el.remove();
    }
  }

  /// An element is "empty" for cleanup purposes if it has no nodes at all,
  /// or every child node is whitespace-only text (e.g. `<p>&nbsp;</p>` or
  /// `<p>\n  </p>`). Real content nodes — elements like `<img>`/`<br>`, or
  /// non-blank text — count as non-empty.
  bool _isEffectivelyEmpty(Element el) {
    if (el.nodes.isEmpty) return true;
    return el.nodes.every((n) => n is Text && n.text.trim().isEmpty);
  }
}
