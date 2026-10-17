import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/domain/repository_interfaces/local_account_repository_interface.dart';
import 'package:atlas_app/core/account/presentation/providers/local_account_providers.dart';

class _FakeAccountRepository implements LocalAccountRepositoryInterface {
  _FakeAccountRepository([this.stored = const LocalAccountEntity()]);

  LocalAccountEntity stored;
  int saveCount = 0;

  @override
  Future<LocalAccountEntity> load() async => stored;

  @override
  Future<void> save(LocalAccountEntity account) async {
    stored = account;
    saveCount++;
  }
}

void main() {
  group('LocalAccountEntity', () {
    test('defaults to a "Reader" account with the first avatar colour', () {
      const account = LocalAccountEntity();
      expect(account.displayName, 'Reader');
      expect(account.avatarColorIndex, 0);
      expect(account.createdAt, isNull);
    });

    test('avatarInitial uses the first uppercase letter', () {
      expect(const LocalAccountEntity(displayName: 'aria').avatarInitial, 'A');
      expect(const LocalAccountEntity(displayName: '   ').avatarInitial, 'R');
    });

    test('greetingName returns only the first name', () {
      expect(
        const LocalAccountEntity(
          displayName: 'Aria Nightingale',
        ).greetingName,
        'Aria',
      );
      expect(const LocalAccountEntity(displayName: '').greetingName, 'Reader');
    });

    test('JSON round-trips name, colour and createdAt', () {
      final created = DateTime(2026, 4, 1, 9, 30);
      final account = LocalAccountEntity(
        displayName: 'Aria',
        avatarColorIndex: 3,
        createdAt: created,
      );

      final restored = LocalAccountEntity.fromJson(account.toJson());
      expect(restored.displayName, 'Aria');
      expect(restored.avatarColorIndex, 3);
      expect(restored.createdAt, created);
    });

    test('fromJson falls back to "Reader" for an empty name', () {
      final restored = LocalAccountEntity.fromJson({
        'displayName': '   ',
        'avatarColorIndex': 5,
      });
      expect(restored.displayName, 'Reader');
      expect(restored.avatarColorIndex, 5);
    });

    test('decode tolerates corrupt payloads', () {
      final restored = LocalAccountEntity.decode('not-json');
      expect(restored.displayName, 'Reader');
    });

    test('kAvatarColors has no duplicate entries', () {
      expect(kAvatarColors.toSet().length, kAvatarColors.length);
    });
  });

  group('LocalAccountNotifier', () {
    test('loads the persisted account', () async {
      final repository = _FakeAccountRepository(
        const LocalAccountEntity(displayName: 'Aria', avatarColorIndex: 3),
      );
      final notifier = LocalAccountNotifier(repository);
      addTearDown(notifier.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.valueOrNull?.displayName, 'Aria');
      expect(notifier.state.valueOrNull?.avatarColorIndex, 3);
    });

    test('setDisplayName trims and persists the name', () async {
      final repository = _FakeAccountRepository();
      final notifier = LocalAccountNotifier(repository);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);

      await notifier.setDisplayName('  Aria  ');

      expect(notifier.state.valueOrNull?.displayName, 'Aria');
      expect(repository.stored.displayName, 'Aria');
      expect(repository.saveCount, 1);
    });

    test('setDisplayName refuses an empty name', () async {
      final repository = _FakeAccountRepository(
        const LocalAccountEntity(displayName: 'Aria'),
      );
      final notifier = LocalAccountNotifier(repository);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);

      await notifier.setDisplayName('   ');

      expect(notifier.state.valueOrNull?.displayName, 'Reader');
    });

    test('setAvatarColorIndex clamps out-of-range indices', () async {
      final repository = _FakeAccountRepository();
      final notifier = LocalAccountNotifier(repository);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);

      await notifier.setAvatarColorIndex(99);
      expect(
        notifier.state.valueOrNull?.avatarColorIndex,
        kAvatarColors.length - 1,
      );

      await notifier.setAvatarColorIndex(-4);
      expect(notifier.state.valueOrNull?.avatarColorIndex, 0);
      expect(repository.saveCount, 2);
    });
  });

  group('localAccountSummaryProvider', () {
    test('falls back to a default account before the async load resolves', () {
      final container = ProviderContainer(
        overrides: [
          localAccountRepositoryProvider.overrideWithValue(
            _FakeAccountRepository(
              const LocalAccountEntity(displayName: 'Aria'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The synchronous summary must never be null / empty for the greeting.
      expect(container.read(localAccountSummaryProvider).displayName, 'Reader');
    });
  });
}
