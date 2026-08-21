import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which font families the user has downloaded to the device
/// and which weights are installed per family.
///
/// Actual font fetching + registration is handled by [FontDownloader]; this
/// class persists the "downloaded" state so the UI can show status.
final class FontDownloadRepository {
  const FontDownloadRepository();

  static const _keyAll = 'font_downloaded_families';
  static const _keyWeightsPrefix = 'font_weights_';

  /// Curated popular font families pinned at the top of the browser.
  static const popularFamilies = <String>{
    'Merriweather',
    'Lora',
    'Roboto Slab',
    'Noto Serif',
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
    return names?.toSet() ?? {};
  }

  /// Returns true if [family] has been downloaded and cached.
  Future<bool> isDownloaded(String family) async {
    final downloaded = await downloadedFamilies();
    return downloaded.contains(family);
  }

  /// Returns the installed weights for each downloaded family.
  Future<Map<String, Set<int>>> installedWeights() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, Set<int>>{};
    for (final family in await downloadedFamilies()) {
      final raw = prefs.getString('$_keyWeightsPrefix$family');
      if (raw != null) {
        try {
          final list = jsonDecode(raw) as List;
          result[family] = {
            for (final w in list)
              if (w is int) w,
          };
        } catch (_) {
          result[family] = {400};
        }
      } else {
        result[family] = {400};
      }
    }
    return result;
  }

  /// Persists that a family was downloaded with the given weights.
  Future<void> markDownloaded(String family, {Set<int> weights = const {}}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (await downloadedFamilies())..add(family);
    await prefs.setStringList(_keyAll, current.toList());
    if (weights.isNotEmpty) {
      await prefs.setString(
        '$_keyWeightsPrefix$family',
        jsonEncode(weights.toList()),
      );
    }
  }

  Future<void> removeFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (await downloadedFamilies())..remove(family);
    await prefs.setStringList(_keyAll, current.toList());
    await prefs.remove('$_keyWeightsPrefix$family');
  }
}
