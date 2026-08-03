import 'package:atlas_app/core/content_engine/templates/html_template.dart';
import 'package:atlas_app/core/content_engine/templates/mvlempyr_template.dart';
import 'package:atlas_app/core/content_engine/templates/novelfull_template.dart';
import 'package:atlas_app/core/content_engine/templates/royalroad_template.dart';
import 'package:atlas_app/core/content_engine/templates/template.dart';
import 'package:atlas_app/core/content_engine/templates/wordpress_api_template.dart';

class UnknownTemplateException implements Exception {
  const UnknownTemplateException(this.templateId);

  final String templateId;

  @override
  String toString() =>
      'UnknownTemplateException: template "$templateId" is not registered';
}

/// Lookup of templateId -> Template, built once at startup. `PluginRepository`
/// resolves `manifest.templateId` against this and throws
/// [UnknownTemplateException] rather than failing with a null-check if a
/// manifest references an unregistered template (a real failure mode once
/// plugins ship independently of app releases).
class TemplateRegistry {
  TemplateRegistry(Iterable<Template> templates) : _templates = {
        for (final template in templates) template.templateId: template,
      };

  /// The built-in set shipped with the app.
  static final defaults = TemplateRegistry(const [
    HtmlTemplate(),
    WordPressApiTemplate(),
    MvlempyrTemplate(),
    NovelfullTemplate(),
    RoyalRoadTemplate(),
  ]);

  final Map<String, Template> _templates;

  Template resolve(String templateId) {
    final template = _templates[templateId];
    if (template == null) throw UnknownTemplateException(templateId);
    return template;
  }

  bool contains(String templateId) => _templates.containsKey(templateId);

  Iterable<String> get ids => _templates.keys;
}
