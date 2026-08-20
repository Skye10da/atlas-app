import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/settings/infrastructure/repositories/font_download_repository.dart';

/// State of the font-download manager.
class FontDownloadState {
  const FontDownloadState({
    this.downloaded = const {},
    this.downloading = const {},
    this.errors = const {},
  });

  final Set<String> downloaded;
  final Set<String> downloading;
  final Set<String> errors;

  FontDownloadState copyWith({
    Set<String>? downloaded,
    Set<String>? downloading,
    Set<String>? errors,
  }) {
    return FontDownloadState(
      downloaded: downloaded ?? this.downloaded,
      downloading: downloading ?? this.downloading,
      errors: errors ?? this.errors,
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

class FontDownloadNotifier extends StateNotifier<FontDownloadState> {
  FontDownloadNotifier(this._repo) : super(const FontDownloadState()) {
    _init();
  }

  final FontDownloadRepository _repo;

  Future<void> _init() async {
    final downloaded = await _repo.downloadedFamilies();
    state = state.copyWith(downloaded: downloaded);
  }

  void markDownloading(String family) {
    state = state.copyWith(
      downloading: {...state.downloading, family},
      errors: {...state.errors}..remove(family),
    );
  }

  void markDownloaded(String family) {
    final downloading = {...state.downloading}..remove(family);
    state = state.copyWith(
      downloaded: {...state.downloaded, family},
      downloading: downloading,
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
    state = state.copyWith(
      downloaded: {...state.downloaded}..remove(family),
      errors: {...state.errors}..remove(family),
    );
  }
}
