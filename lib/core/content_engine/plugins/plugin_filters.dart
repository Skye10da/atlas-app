/// `filters.json` — the plugin-authored half of the ContentCleaner strip
/// list. Maps directly onto `ContentCleaner`'s constructor parameters.
class PluginFilters {
  const PluginFilters({
    this.extraStripSelectors = const [],
    this.disableDefaultStrips = false,
  });

  factory PluginFilters.fromJson(Map<String, Object?> json) {
    final extra = json['extraStripSelectors'];
    final disable = json['disableDefaultStrips'];
    return PluginFilters(
      extraStripSelectors: extra is List
          ? extra.whereType<String>().toList()
          : const [],
      disableDefaultStrips: disable is bool ? disable : false,
    );
  }

  final List<String> extraStripSelectors;
  final bool disableDefaultStrips;

  Map<String, Object?> toJson() => {
        'extraStripSelectors': extraStripSelectors,
        'disableDefaultStrips': disableDefaultStrips,
      };
}
