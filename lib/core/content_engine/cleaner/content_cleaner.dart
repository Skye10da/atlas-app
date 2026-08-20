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

  /// Removes empty elements that add no reading value but inflate the DOM
  /// (e.g. `<p>`, `<div>`, `<span>` wrappers that became empty — or
  /// whitespace-only — after the strip pass).
  void _removeEmptyNoise(Element root) {
    bool removed = true;
    while (removed) {
      removed = false;
      for (final el in root.querySelectorAll(
        'p,div,span,section,article,em,strong,b,i,u,blockquote,li',
      )) {
        if (!_isEffectivelyEmpty(el)) continue;

        if (el.attributes.isNotEmpty) {
          // Keep elements with meaningful attributes (ids, classes, data
          // attrs) so selector-based extraction still has anchors. Only
          // pure presentation attrs (style) don't count.
          final meaningful = el.attributes.keys
              .where((k) => k != 'style')
              .isNotEmpty;
          if (meaningful) continue;
        }

        el.remove();
        removed = true;
      }
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
