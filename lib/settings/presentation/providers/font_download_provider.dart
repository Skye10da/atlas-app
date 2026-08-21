import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/theme/font_downloader.dart';
import 'package:atlas_app/settings/infrastructure/repositories/font_download_repository.dart';

/// State of the font-download manager.
class FontDownloadState {
  FontDownloadState({
    this.downloaded = const {},
    this.downloading = const {},
    this.errors = const {},
    Map<String, Set<int>>? installedWeights,
  }) : installedWeights = installedWeights ?? const <String, Set<int>>{};

  final Set<String> downloaded;
  final Set<String> downloading;
  final Set<String> errors;

  /// Maps family → set of installed numeric weights (e.g. 400, 700).
  final Map<String, Set<int>> installedWeights;

  FontDownloadState copyWith({
    Set<String>? downloaded,
    Set<String>? downloading,
    Set<String>? errors,
    Map<String, Set<int>>? installedWeights,
  }) {
    return FontDownloadState(
      downloaded: downloaded ?? this.downloaded,
      downloading: downloading ?? this.downloading,
      errors: errors ?? this.errors,
      installedWeights: installedWeights ?? this.installedWeights,
    );
  }
}

final fontDownloadRepositoryProvider = Provider((ref) {
  return const FontDownloadRepository();
});

final fontDownloadProvider =
    StateNotifierProvider<FontDownloadNotifier, FontDownloadState>((ref) {
      return FontDownloadNotifier(ref.watch(fontDownloadRepositoryProvider));
    });

/// All font families available for reading: bundled + downloaded.
final availableFontFamiliesProvider = FutureProvider<List<String>>((ref) async {
  final state = ref.watch(fontDownloadProvider);
  final downloaded = state.downloaded;
  const bundled = FontDownloadRepository.bundledFamilies;
  return [
    ...bundled,
    ...downloaded.difference(bundled),
  ]..sort();
});

class FontDownloadNotifier extends StateNotifier<FontDownloadState> {
  FontDownloadNotifier(this._repo) : super(FontDownloadState()) {
    _init();
  }

  final FontDownloadRepository _repo;

  Future<void> _init() async {
    final downloaded = await _repo.downloadedFamilies();
    final weights = await _repo.installedWeights();
    state = state.copyWith(downloaded: downloaded, installedWeights: weights);
  }

  void markDownloading(String family) {
    state = state.copyWith(
      downloading: {...state.downloading, family},
      errors: {...state.errors}..remove(family),
    );
  }

  void markDownloaded(String family, {Set<int> weights = const {}}) {
    final downloading = {...state.downloading}..remove(family);
    final newWeights = {
      ...state.installedWeights,
      family: weights,
    };
    state = state.copyWith(
      downloaded: {...state.downloaded, family},
      downloading: downloading,
      installedWeights: newWeights,
    );
  }

  void markError(String family) {
    final downloading = {...state.downloading}..remove(family);
    state = state.copyWith(
      downloading: downloading,
      errors: {...state.errors, family},
    );
  }

  Future<void> remove(String family) async {
    await _repo.removeFamily(family);
    final newWeights = Map<String, Set<int>>.of(state.installedWeights)
      ..remove(family);
    state = state.copyWith(
      downloaded: {...state.downloaded}..remove(family),
      errors: {...state.errors}..remove(family),
      installedWeights: newWeights,
    );
  }
}

/// Total bytes of cached font files on disk.
final cachedFontSizeBytesProvider = FutureProvider<int>((ref) {
  return FontDownloader.cachedFontSizeBytes();
});
