import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/core/theme/font_catalog_service.dart';

void main() {
  group('FontCatalogService.filter', () {
    const entryA = FontCatalogEntry(
      family: 'Cinzel',
      category: FontCatalogCategory.serif,
      weights: [400, 700],
      popularity: 3,
      trending: 1,
    );
    const entryB = FontCatalogEntry(
      family: 'Inter',
      category: FontCatalogCategory.sansSerif,
      weights: [400],
      popularity: 1,
      trending: 3,
    );
    const entryC = FontCatalogEntry(
      family: 'Fira Code',
      category: FontCatalogCategory.monospace,
      weights: [400, 500],
      popularity: 2,
      trending: 2,
    );

    final service = FontCatalogService();

    test('does not mutate unmodifiable input list when sorting', () {
      final unmodifiable = List<FontCatalogEntry>.unmodifiable([
        entryA,
        entryB,
        entryC,
      ]);

      // Should not throw UnsupportedError: Cannot modify an unmodifiable list
      final sorted = service.filter(
        unmodifiable,
        sort: FontSort.popularity,
      );

      expect(sorted, hasLength(3));
      expect(sorted.first.family, 'Inter'); // popularity 1
      expect(sorted.last.family, 'Cinzel'); // popularity 3

      // Original unmodifiable list must remain in its original order
      expect(unmodifiable.first.family, 'Cinzel');
    });

    test('filters by category and search query', () {
      final entries = <FontCatalogEntry>[entryA, entryB, entryC];

      final filtered = service.filter(
        entries,
        query: 'in',
        category: FontCatalogCategory.serif,
        sort: FontSort.alphabetical,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.family, 'Cinzel');
    });
  });
}

