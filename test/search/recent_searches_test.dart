import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/search/presentation/providers/recent_searches_provider.dart';

void main() {
  group('RecentSearchesNotifier', () {
    test('records a query as most recent, deduped, capped at 5', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(recentSearchesProvider, (_, _) {});

      await container.read(recentSearchesProvider.notifier).add('alpha');
      await container.read(recentSearchesProvider.notifier).add('beta');
      await container.read(recentSearchesProvider.notifier).add('alpha');

      expect(container.read(recentSearchesProvider), ['alpha', 'beta']);
    });

    test('keeps at most the last 5', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(recentSearchesProvider, (_, _) {});

      for (var i = 0; i < 7; i++) {
        await container.read(recentSearchesProvider.notifier).add('t$i');
      }

      final recents = container.read(recentSearchesProvider);
      expect(recents, hasLength(recentSearchesLimit));
      expect(recents.first, 't6');
      expect(recents.last, 't2');
    });

    test('queries shorter than 2 characters are not recorded', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(recentSearchesProvider, (_, _) {});

      await container.read(recentSearchesProvider.notifier).add('a');
      expect(container.read(recentSearchesProvider), isEmpty);
    });

    test('restores previous recents — lazily, on first watch', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'find_new.recent_searches': ['old one', 'older two'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Nothing was read before the first watch: the mock store is only
      // consulted inside build().
      container.listen(recentSearchesProvider, (_, _) {});
      // Let the async restore land.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(recentSearchesProvider),
        ['old one', 'older two'],
      );
    });
  });
}
