import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/domain/repository_interfaces/local_account_repository_interface.dart';
import 'package:atlas_app/core/account/infrastructure/repositories/shared_prefs_local_account_repository.dart';

final localAccountRepositoryProvider = Provider<LocalAccountRepositoryInterface>(
  (ref) => const SharedPrefsLocalAccountRepository(),
);

/// The single on-device account, used for personalisation (greeting, avatar).
/// Falls back to a default "Reader" until the persisted value loads.
final localAccountProvider =
    StateNotifierProvider<LocalAccountNotifier, AsyncValue<LocalAccountEntity>>(
      (ref) {
        final repo = ref.watch(localAccountRepositoryProvider);
        return LocalAccountNotifier(repo);
      },
    );

/// Cheap synchronous read for widgets that just need a value to render now.
final localAccountSummaryProvider = Provider<LocalAccountEntity>((ref) {
  return ref.watch(localAccountProvider).valueOrNull ??
      const LocalAccountEntity();
});

class LocalAccountNotifier extends StateNotifier<AsyncValue<LocalAccountEntity>> {
  LocalAccountNotifier(this._repository) : super(const AsyncLoading()) {
    _load();
  }

  final LocalAccountRepositoryInterface _repository;

  Future<void> _load() async {
    try {
      state = AsyncData(await _repository.load());
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    final current = state.valueOrNull ?? const LocalAccountEntity();
    final updated = current.copyWith(
      displayName: trimmed.isEmpty ? 'Reader' : trimmed,
    );
    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> saveProfile({
    required String displayName,
    required int avatarColorIndex,
  }) async {
    final trimmed = displayName.trim();
    final current = state.valueOrNull ?? const LocalAccountEntity();
    final normalized = kAvatarColors.isEmpty
        ? 0
        : avatarColorIndex.clamp(0, kAvatarColors.length - 1);
    final updated = current.copyWith(
      displayName: trimmed.isEmpty ? 'Reader' : trimmed,
      avatarColorIndex: normalized,
      createdAt: current.createdAt ?? DateTime.now(),
    );
    state = AsyncData(updated);
    await _repository.save(updated);
  }

  Future<void> setAvatarColorIndex(int index) async {
    final current = state.valueOrNull ?? const LocalAccountEntity();
    final normalized = kAvatarColors.isEmpty
        ? 0
        : index.clamp(0, kAvatarColors.length - 1);
    final updated = current.copyWith(avatarColorIndex: normalized);
    state = AsyncData(updated);
    await _repository.save(updated);
  }
}
