import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which Google Font families have been downloaded and cached
/// on the device for offline use.
///
/// Actual font fetching is handled by `google_fonts` at render time;
/// this class persists the "downloaded" state so the UI can show status.
final class FontDownloadRepository {
  const FontDownloadRepository();

  static const _keyPrefix = 'font_downloaded_';
  static const _keyAll = 'font_downloaded_families';

  /// The Google Font families available for download.
  /// These are the 6 non-bundled reader-font families.
  static const downloadableFamilies = <String>{
    'Merriweather',
    'Lora',
    'Noto Serif',
    'Roboto Slab',
    'EB Garamond',
    'JetBrains Mono',
  };

  /// The chrome families that are always bundled — never need downloading.
  static const bundledFamilies = <String>{
    'Inter',
    'Open Sans',
    'Playfair Display',
  };

  /// Returns the set of families that have been successfully downloaded.
  Future<Set<String>> downloadedFamilies() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_keyAll);
    if (names == null) return {};
    return names.where(downloadableFamilies.contains).toSet();
  }

  /// Returns true if [family] has been downloaded and cached.
  Future<bool> isDownloaded(String family) async {
    final downloaded = await downloadedFamilies();
    return downloaded.contains(family);
  }

  Future<void> markDownloaded(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$family', true);
    final current = await downloadedFamilies();
    current.add(family);
    await prefs.setStringList(_keyAll, current.toList());
  }

  Future<void> removeFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$family');
    final current = await downloadedFamilies();
    current.remove(family);
    await prefs.setStringList(_keyAll, current.toList());
  }
}
