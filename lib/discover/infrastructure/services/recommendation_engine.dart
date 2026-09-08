import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';
import 'package:atlas_app/library/domain/entities/book_entity.dart';

class RecommendationEngine {
  const RecommendationEngine();

  static const _defaultCuratedRecommendations = [
    TrendingBook(
      title: 'Martial God Asura',
      sourceId: 'readnovelfull',
      sourceName: 'ReadNovelFull',
      author: 'Kindhearted Bee',
      coverUrl: 'https://covers.openlibrary.org/b/id/10523365-M.jpg',
      detailUrl: 'https://readnovelfull.com/martial-god-asura.html',
      genre: 'Wuxia',
      matchPercentage: 98,
    ),
    TrendingBook(
      title: 'Rebirth of the Thief',
      sourceId: 'royalroad',
      sourceName: 'Royal Road',
      author: 'Mad Snail',
      coverUrl: 'https://covers.openlibrary.org/b/id/8226191-M.jpg',
      detailUrl: 'https://www.royalroad.com/fiction/1234',
      genre: 'Romance',
      matchPercentage: 94,
    ),
    TrendingBook(
      title: "The Novel's Extra",
      sourceId: 'noveldrama',
      sourceName: 'NovelDrama',
      author: 'Jee Gab Song',
      coverUrl: 'https://covers.openlibrary.org/b/id/9255566-M.jpg',
      detailUrl: 'https://noveldrama.com/the-novels-extra',
      genre: 'Sci-fi',
      matchPercentage: 91,
    ),
    TrendingBook(
      title: 'Omniscient Reader',
      sourceId: 'readnovelfull',
      sourceName: 'ReadNovelFull',
      author: 'Sing Shong',
      coverUrl: 'https://covers.openlibrary.org/b/id/12547191-M.jpg',
      detailUrl: 'https://readnovelfull.com/omniscient-reader.html',
      genre: 'Fantasy',
      matchPercentage: 87,
    ),
    TrendingBook(
      title: 'Lord of the Mysteries',
      sourceId: 'royalroad',
      sourceName: 'Royal Road',
      author: 'Cuttlefish That Loves Diving',
      coverUrl: 'https://covers.openlibrary.org/b/id/10389234-M.jpg',
      detailUrl: 'https://www.royalroad.com/fiction/2345',
      genre: 'Mystery',
      matchPercentage: 95,
    ),
  ];

  List<TrendingBook> computeRecommendations({
    required List<BookEntity> libraryBooks,
    required Map<String, List<TrendingBook>> allTrending,
  }) {
    if (libraryBooks.isEmpty) {
      return List.of(_defaultCuratedRecommendations);
    }

    // 1. Extract reader's favorite genres / tags with frequency weighting
    final tagWeights = <String, int>{};
    for (final b in libraryBooks) {
      for (final t in b.tags) {
        final norm = t.trim().toLowerCase();
        if (norm.isNotEmpty) {
          tagWeights[norm] = (tagWeights[norm] ?? 0) + 1;
        }
      }
    }

    // 2. Score candidates from trending sources
    final candidates = <TrendingBook>[];
    for (final list in allTrending.values) {
      candidates.addAll(list);
    }
    candidates.addAll(_defaultCuratedRecommendations);

    final scored = <(TrendingBook, int)>[];
    final seenTitles = <String>{};

    for (final b in candidates) {
      final normTitle = b.title.trim().toLowerCase();
      if (seenTitles.contains(normTitle)) continue;
      seenTitles.add(normTitle);

      // Don't recommend books already in library
      final alreadyInLibrary = libraryBooks.any(
        (lb) => lb.title.trim().toLowerCase() == normTitle,
      );
      if (alreadyInLibrary) continue;

      int score = 75; // baseline match

      final bookGenre = b.genre?.trim().toLowerCase();
      if (bookGenre != null && tagWeights.containsKey(bookGenre)) {
        score += (tagWeights[bookGenre]! * 8).clamp(10, 20);
      }

      // Popularity boost
      if (b.popularity != null && b.popularity!.contains('K')) {
        score += 4;
      }

      final matchPct = score.clamp(80, 99);
      final withMatch = TrendingBook(
        title: b.title,
        sourceId: b.sourceId,
        sourceName: b.sourceName,
        author: b.author,
        coverUrl: b.coverUrl,
        detailUrl: b.detailUrl,
        rating: b.rating,
        popularity: b.popularity,
        genre: b.genre,
        description: b.description,
        fetchedAt: b.fetchedAt,
        matchPercentage: matchPct,
        isOpds: b.isOpds,
      );

      scored.add((withMatch, matchPct));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final result = scored.map((item) => item.$1).take(6).toList();

    return result.isNotEmpty
        ? result
        : List.of(_defaultCuratedRecommendations);
  }
}

