import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/updater/domain/entities/changelog_entry.dart';
import 'package:atlas_app/updater/domain/version_policy.dart';
import 'package:atlas_app/updater/infrastructure/changelog_store.dart';
import 'package:atlas_app/updater/presentation/providers/updater_providers.dart';

/// Feeds the What's-new screen (Settings + `/whats-new` route): release notes
/// per version, newest first. Served from [ChangelogStore] instantly, then
/// merged with the live GitHub Releases listing on [refresh].
class ChangelogController extends AsyncNotifier<List<ChangelogEntry>> {
  ChangelogStore? _store;

  Future<ChangelogStore> get _storeOrBuild async => _store ??=
      ChangelogStore(await ref.read(updatePrefsStoreProvider.future));

  @override
  Future<List<ChangelogEntry>> build() async {
    final store = await _storeOrBuild;
    return store.load();
  }

  /// Merges the live GitHub Releases listing into the cache. Network failures
  /// rethrow so call-sites decide whether the user sees an error; the cached
  /// list and state remain untouched.
  Future<List<ChangelogEntry>> refresh() async {
    final store = await _storeOrBuild;
    final fetched = await ref
        .read(appUpdateRepositoryProvider)
        .fetchReleaseHistory(limit: _historyLimit);
    final merged = <String, ChangelogEntry>{
      for (final entry in state.valueOrNull ?? const <ChangelogEntry>[])
        entry.tag: entry,
    };
    for (final release in fetched) {
      merged[release.tag] = ChangelogEntry(
        tag: release.tag,
        version: release.version,
        versionCode: release.versionCode,
        publishedAt: release.publishedAt,
        notes: release.notes ?? '',
      );
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.versionCode.compareTo(a.versionCode));
    await store.save(list);
    state = AsyncData(list);
    return list;
  }

  /// Bootstrap hook for the post-update surface. Returns the entry written
  /// for the freshly-installed version when the app first runs on a build
  /// newer than the one last acknowledged — otherwise null (up to date, or a
  /// first install where there is nothing to celebrate).
  Future<ChangelogEntry?> detectInstalledVersionChange({
    required int currentBuild,
    required String currentVersion,
  }) async {
    final store = await _storeOrBuild;
    final lastSeen = store.lastSeenVersionCode;
    if (lastSeen == null) {
      // First run on this device: record silently — fresh installs get the
      // full changelog, not a "what's new" banner for their first launch.
      store.lastSeenVersionCode = currentBuild;
      return null;
    }
    if (currentBuild <= lastSeen) return null;

    final entry = await _entryForBuild(
      build: currentBuild,
      version: currentVersion,
    );
    final cached = <String, ChangelogEntry>{
      for (final existing in state.valueOrNull ?? const <ChangelogEntry>[])
        existing.tag: existing,
    };
    cached[entry.tag] = entry;
    final list = cached.values.toList()
      ..sort((a, b) => b.versionCode.compareTo(a.versionCode));
    await store.save(list);
    state = AsyncData(list);
    store.lastSeenVersionCode = currentBuild;
    return entry;
  }

  /// Notes for the running build: fetched when the network cooperates, a
  /// minimal placeholder otherwise (the history refresh repairs it later).
  Future<ChangelogEntry> _entryForBuild({
    required int build,
    required String version,
  }) async {
    try {
      final existing = await refresh();
      final match = existing.where((entry) => entry.versionCode == build);
      if (match.isNotEmpty) return match.first;
    } catch (_) {
      // Offline boot: fall through to the placeholder below.
    }
    final tag = 'v$version+$build';
    final parsed = VersionPolicy.parseTag(tag);
    return ChangelogEntry(
      tag: tag,
      version: parsed.version,
      versionCode: build,
      publishedAt: DateTime.now(),
      notes: 'Atlas $version is installed.',
    );
  }

  static const _historyLimit = 15;
}
