/// Minimal robots.txt parser for crawl-delay and disallow directives.
class RobotsTxt {
  RobotsTxt._(this._rules, this._crawlDelay);

  final Map<String, _UserAgentRules> _rules;
  final Duration? _crawlDelay;

  /// True if [url] is allowed for the default user agent.
  bool allows(Uri url) {
    final path = url.path;
    if (path.isEmpty) return true;

    // Check global rules first
    final global = _rules['*'];
    if (global != null && global.disallows(path)) return false;

    // Then specific user agent rules (we use '*' as default)
    return true;
  }

  Duration? get crawlDelay => _crawlDelay;

  static RobotsTxt parse(String body, Uri origin) {
    final rules = <String, _UserAgentRules>{};
    String currentUserAgent = '*';
    Duration? crawlDelay;

    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final directive = trimmed.substring(0, colonIndex).trim().toLowerCase();
      final value = trimmed.substring(colonIndex + 1).trim();

      switch (directive) {
        case 'user-agent':
          currentUserAgent = value.toLowerCase();
          rules.putIfAbsent(currentUserAgent, () => _UserAgentRules());
          break;
        case 'disallow':
          if (value.isNotEmpty) {
            rules[currentUserAgent]?.disallow.add(value);
          }
          break;
        case 'crawl-delay':
          final seconds = int.tryParse(value);
          if (seconds != null && seconds > 0) {
            crawlDelay = Duration(seconds: seconds);
          }
          break;
        case 'allow':
          if (value.isNotEmpty) {
            rules[currentUserAgent]?.allow.add(value);
          }
          break;
      }
    }

    return RobotsTxt._(rules, crawlDelay);
  }

  static RobotsTxt allowAll() => RobotsTxt._({}, null);
}

class _UserAgentRules {
  final List<String> disallow = [];
  final List<String> allow = [];

  bool disallows(String path) {
    // Allow directives take precedence
    for (final a in allow) {
      if (_matches(path, a)) return false;
    }
    for (final d in disallow) {
      if (_matches(path, d)) return true;
    }
    return false;
  }

  bool _matches(String path, String pattern) {
    // Simple prefix matching for robots.txt patterns
    if (pattern == '/') return true;
    if (pattern.endsWith('*')) {
      return path.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return path.startsWith(pattern);
  }
}