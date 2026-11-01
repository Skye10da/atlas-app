import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/core/database/providers.dart';
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/onboarding/application/onboarding_finisher.dart';
import 'package:atlas_app/onboarding/application/onboarding_gate.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_draft.dart';
import 'package:atlas_app/onboarding/domain/repository_interfaces/onboarding_repository_interface.dart';
import 'package:atlas_app/onboarding/infrastructure/repositories/shared_prefs_onboarding_repository.dart';

abstract final class OnboardingRoutes {
  static const onboarding = '/onboarding';
  static const library = '/library';
}

final onboardingRepositoryProvider = Provider<OnboardingRepositoryInterface>(
  (ref) => const SharedPrefsOnboardingRepository(),
);

final onboardingGateProvider = Provider<OnboardingGate>((ref) {
  final db = ref.watch(databaseProvider);
  return OnboardingGate(
    repository: ref.watch(onboardingRepositoryProvider),
    hasLibraryContent: () async {
      final rows = await db.customSelect('SELECT 1 FROM books LIMIT 1').get();
      return rows.isNotEmpty;
    },
  );
});

/// Where the splash screen should go next: the welcome flow on a fresh
/// install, the library otherwise. Never throws — a failing check must not
/// block the app from opening.
final startLocationProvider = FutureProvider<String>((ref) async {
  try {
    final show = await ref.read(onboardingGateProvider).shouldShow();
    return show ? OnboardingRoutes.onboarding : OnboardingRoutes.library;
  } catch (e, st) {
    AppLogger.error('Onboarding gate failed; opening the library', e, st);
    return OnboardingRoutes.library;
  }
});

final onboardingFinisherProvider = Provider<OnboardingFinisher>(
  (ref) => OnboardingFinisher(ref, ref.watch(onboardingRepositoryProvider)),
);

final onboardingDraftProvider =
    StateNotifierProvider.autoDispose<OnboardingDraftNotifier, OnboardingDraft>(
      (ref) => OnboardingDraftNotifier(),
    );

class OnboardingDraftNotifier extends StateNotifier<OnboardingDraft> {
  OnboardingDraftNotifier([super.initial = const OnboardingDraft()]);

  void setDisplayName(String value) =>
      state = state.copyWith(displayName: value);

  void setAvatarColorIndex(int value) =>
      state = state.copyWith(avatarColorIndex: value);

  void setWeeklyChapterTarget(int value) =>
      state = state.copyWith(weeklyChapterTarget: value);

  void setDailyMinuteTarget(int value) =>
      state = state.copyWith(dailyMinuteTarget: value);

  void setUpdateNotifications(bool value) =>
      state = state.copyWith(enableUpdateNotifications: value);

  /// Pre-fills the draft when the tour is replayed from Settings.
  void seed({
    String? displayName,
    int? avatarColorIndex,
    int? weeklyChapterTarget,
    int? dailyMinuteTarget,
  }) {
    state = state.copyWith(
      displayName: displayName,
      avatarColorIndex: avatarColorIndex,
      weeklyChapterTarget: weeklyChapterTarget,
      dailyMinuteTarget: dailyMinuteTarget,
    );
  }
}
