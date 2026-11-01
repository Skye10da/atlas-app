import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/domain/repository_interfaces/local_account_repository_interface.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';
import 'package:atlas_app/onboarding/application/onboarding_gate.dart';
import 'package:atlas_app/onboarding/domain/entities/onboarding_draft.dart';
import 'package:atlas_app/onboarding/domain/repository_interfaces/onboarding_repository_interface.dart';
import 'package:atlas_app/onboarding/infrastructure/repositories/shared_prefs_onboarding_repository.dart';

class _FakeOnboardingRepository implements OnboardingRepositoryInterface {
  _FakeOnboardingRepository({this.completed = false});

  bool completed;
  int markCalls = 0;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    markCalls++;
    completed = true;
  }

  @override
  Future<void> reset() async => completed = false;
}

class _FakeAccountRepository implements LocalAccountRepositoryInterface {
  LocalAccountEntity? saved;

  @override
  Future<LocalAccountEntity> load() async =>
      LocalAccountEntity(createdAt: DateTime(2026, 1, 1));

  @override
  Future<void> save(LocalAccountEntity account) async => saved = account;
}

void main() {
  group('OnboardingGate', () {
    test('shows the flow on a fresh install', () async {
      final repo = _FakeOnboardingRepository();
      final gate = OnboardingGate(
        repository: repo,
        hasLibraryContent: () async => false,
      );

      expect(await gate.shouldShow(), isTrue);
      expect(repo.markCalls, 0);
    });

    test('silently completes for existing installs with books', () async {
      final repo = _FakeOnboardingRepository();
      final gate = OnboardingGate(
        repository: repo,
        hasLibraryContent: () async => true,
      );

      expect(await gate.shouldShow(), isFalse);
      expect(repo.completed, isTrue);
    });

    test('does not touch the database once completed', () async {
      var checked = false;
      final gate = OnboardingGate(
        repository: _FakeOnboardingRepository(completed: true),
        hasLibraryContent: () async {
          checked = true;
          return false;
        },
      );

      expect(await gate.shouldShow(), isFalse);
      expect(checked, isFalse);
    });
  });

  group('SharedPrefsOnboardingRepository', () {
    const repo = SharedPrefsOnboardingRepository();

    test('round-trips completion and reset', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await repo.isCompleted(), isFalse);

      await repo.markCompleted();
      expect(await repo.isCompleted(), isTrue);

      await repo.reset();
      expect(await repo.isCompleted(), isFalse);
    });

    test('an older onboarding version counts as not completed', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed_version': kOnboardingVersion - 1,
      });
      expect(await repo.isCompleted(), isFalse);
    });
  });

  group('LocalAccountNotifier.saveProfile', () {
    Future<(LocalAccountNotifier, _FakeAccountRepository)> create() async {
      final repo = _FakeAccountRepository();
      final notifier = LocalAccountNotifier(repo);
      await Future<void>.delayed(Duration.zero); // let _load() finish
      return (notifier, repo);
    }

    test('trims the name and persists it in one write', () async {
      final (notifier, repo) = await create();
      await notifier.saveProfile(displayName: '  Ada  ', avatarColorIndex: 2);

      expect(repo.saved?.displayName, 'Ada');
      expect(repo.saved?.avatarColorIndex, 2);
      expect(repo.saved?.createdAt, DateTime(2026, 1, 1));
    });

    test('falls back to Reader and clamps the colour index', () async {
      final (notifier, repo) = await create();
      await notifier.saveProfile(displayName: '   ', avatarColorIndex: 999);

      expect(repo.saved?.displayName, 'Reader');
      expect(repo.saved?.avatarColorIndex, kAvatarColors.length - 1);
    });
  });

  group('OnboardingDraft', () {
    test('greeting and initial fall back for an empty name', () {
      const draft = OnboardingDraft();
      expect(draft.greetingName, 'Reader');
      expect(draft.avatarInitial, 'R');
    });

    test('uses the first name and an upper-case initial', () {
      const draft = OnboardingDraft(displayName: 'ada lovelace');
      expect(draft.greetingName, 'ada');
      expect(draft.avatarInitial, 'A');
    });
  });
}
