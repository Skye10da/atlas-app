/// Thrown when a critical selector fails to match and no healing path succeeds.
/// Contains enough context for debugging, telemetry, and the healing review queue.
class SelectorMissException implements Exception {
  const SelectorMissException({
    required this.pluginId,
    required this.role,
    required this.selector,
    this.url,
    this.cause,
  });

  /// Plugin identifier (e.g., 'noveldrama', 'royalroad')
  final String pluginId;

  /// Selector role: 'chapterContent.container', 'chapterList.item', 'chapterList.container', 'metadata.title', etc.
  final String role;

  /// The selector string that was attempted
  final String selector;

  /// URL being processed when the miss occurred (optional but helpful)
  final String? url;

  /// Underlying cause if the miss was triggered by an exception
  final Object? cause;

  @override
  String toString() =>
      'SelectorMissException(pluginId: $pluginId, role: $role, selector: "$selector"${url != null ? ', url: $url' : ''})';
}