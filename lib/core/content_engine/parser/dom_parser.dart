import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Builds a DOM tree from HTML text.
///
/// HTML parsing is an internal implementation detail of the DOM Engine;
/// downstream stages consume the parsed [Document], never raw text and never
/// regex.
class DomParser {
  const DomParser();

  Document parse(String html) => html_parser.parse(html);

  DocumentFragment parseFragment(String html) =>
      html_parser.parseFragment(html);
}
