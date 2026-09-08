import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:atlas_app/core/logging/logger.dart';
import 'package:atlas_app/discover/domain/entities/discover_dashboard_data.dart';

class OpdsTrendingService {
  const OpdsTrendingService();

  static const _gutenbergDefaults = [
    TrendingBook(
      title: 'Pride and Prejudice',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Jane Austen',
      coverUrl: 'https://www.gutenberg.org/cache/epub/1342/pg1342.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/1342',
      rating: '4.8',
      popularity: '👁 2.4K this week',
      genre: 'Classic',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Odyssey',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Homer',
      coverUrl: 'https://www.gutenberg.org/cache/epub/1727/pg1727.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/1727',
      rating: '4.7',
      popularity: '👁 1.2K this week',
      genre: 'Adventure',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Frankenstein',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Mary Shelley',
      coverUrl: 'https://www.gutenberg.org/cache/epub/84/pg84.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/84',
      rating: '4.6',
      popularity: '👁 1.9K this week',
      genre: 'Horror',
      isOpds: true,
    ),
    TrendingBook(
      title: 'A Tale of Two Cities',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Charles Dickens',
      coverUrl: 'https://www.gutenberg.org/cache/epub/98/pg98.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/98',
      rating: '4.7',
      popularity: '👁 1.4K this week',
      genre: 'Historical',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Alice in Wonderland',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Lewis Carroll',
      coverUrl: 'https://www.gutenberg.org/cache/epub/11/pg11.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/11',
      rating: '4.8',
      popularity: '👁 1.7K this week',
      genre: 'Fantasy',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Moby Dick',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'Herman Melville',
      coverUrl: 'https://www.gutenberg.org/cache/epub/2701/pg2701.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/2701',
      rating: '4.5',
      popularity: '👁 1.1K this week',
      genre: 'Adventure',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Great Gatsby',
      sourceId: 'gutenberg',
      sourceName: 'Gutenberg',
      author: 'F. Scott Fitzgerald',
      coverUrl: 'https://www.gutenberg.org/cache/epub/64317/pg64317.cover.medium.jpg',
      detailUrl: 'https://www.gutenberg.org/ebooks/64317',
      rating: '4.8',
      popularity: '👁 2.8K this week',
      genre: 'Classic',
      isOpds: true,
    ),
  ];

  static const _standardEbooksDefaults = [
    TrendingBook(
      title: 'The Time Machine',
      sourceId: 'standard',
      sourceName: 'Std Ebooks',
      author: 'H.G. Wells',
      coverUrl: 'https://standardebooks.org/ebooks/h-g-wells/the-time-machine/downloads/cover-thumbnail.jpg',
      detailUrl: 'https://standardebooks.org/ebooks/h-g-wells/the-time-machine',
      rating: '4.7',
      popularity: '👁 1.8K this week',
      genre: 'Sci-fi',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Great Expectations',
      sourceId: 'standard',
      sourceName: 'Std Ebooks',
      author: 'Charles Dickens',
      coverUrl: 'https://standardebooks.org/ebooks/charles-dickens/great-expectations/downloads/cover-thumbnail.jpg',
      detailUrl: 'https://standardebooks.org/ebooks/charles-dickens/great-expectations',
      rating: '4.6',
      popularity: '👁 1.1K this week',
      genre: 'Classic',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Picture of Dorian Gray',
      sourceId: 'standard',
      sourceName: 'Std Ebooks',
      author: 'Oscar Wilde',
      coverUrl: 'https://standardebooks.org/ebooks/oscar-wilde/the-picture-of-dorian-gray/downloads/cover-thumbnail.jpg',
      detailUrl: 'https://standardebooks.org/ebooks/oscar-wilde/the-picture-of-dorian-gray',
      rating: '4.8',
      popularity: '👁 1.9K this week',
      genre: 'Drama',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Count of Monte Cristo',
      sourceId: 'standard',
      sourceName: 'Std Ebooks',
      author: 'Alexandre Dumas',
      coverUrl: 'https://standardebooks.org/ebooks/alexandre-dumas/the-count-of-monte-cristo/downloads/cover-thumbnail.jpg',
      detailUrl: 'https://standardebooks.org/ebooks/alexandre-dumas/the-count-of-monte-cristo',
      rating: '4.9',
      popularity: '👁 2.2K this week',
      genre: 'Adventure',
      isOpds: true,
    ),
  ];

  static const _feedbooksDefaults = [
    TrendingBook(
      title: 'Dracula',
      sourceId: 'feedbooks',
      sourceName: 'Feedbooks',
      author: 'Bram Stoker',
      coverUrl: 'https://covers.openlibrary.org/b/id/8231856-M.jpg',
      detailUrl: 'https://www.feedbooks.com/book/52/dracula',
      rating: '4.8',
      popularity: '👁 1.5K this week',
      genre: 'Horror',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Adventures of Sherlock Holmes',
      sourceId: 'feedbooks',
      sourceName: 'Feedbooks',
      author: 'Arthur Conan Doyle',
      coverUrl: 'https://covers.openlibrary.org/b/id/7984916-M.jpg',
      detailUrl: 'https://www.feedbooks.com/book/64/the-adventures-of-sherlock-holmes',
      rating: '4.9',
      popularity: '👁 2.1K this week',
      genre: 'Mystery',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Metamorphosis',
      sourceId: 'feedbooks',
      sourceName: 'Feedbooks',
      author: 'Franz Kafka',
      coverUrl: 'https://covers.openlibrary.org/b/id/10524458-M.jpg',
      detailUrl: 'https://www.feedbooks.com/book/189/the-metamorphosis',
      rating: '4.7',
      popularity: '👁 1.3K this week',
      genre: 'Fiction',
      isOpds: true,
    ),
    TrendingBook(
      title: 'War and Peace',
      sourceId: 'feedbooks',
      sourceName: 'Feedbooks',
      author: 'Leo Tolstoy',
      coverUrl: 'https://covers.openlibrary.org/b/id/8235111-M.jpg',
      detailUrl: 'https://www.feedbooks.com/book/48/war-and-peace',
      rating: '4.8',
      popularity: '👁 1.6K this week',
      genre: 'Epic',
      isOpds: true,
    ),
  ];

  static const _openLibDefaults = [
    TrendingBook(
      title: 'The Lord of the Rings',
      sourceId: 'openlib',
      sourceName: 'Open Library',
      author: 'J.R.R. Tolkien',
      coverUrl: 'https://covers.openlibrary.org/b/id/12003884-M.jpg',
      detailUrl: 'https://openlibrary.org/works/OL27448W',
      rating: '4.9',
      popularity: '👁 980 this week',
      genre: 'Fantasy',
      isOpds: true,
    ),
    TrendingBook(
      title: '1984',
      sourceId: 'openlib',
      sourceName: 'Open Library',
      author: 'George Orwell',
      coverUrl: 'https://covers.openlibrary.org/b/id/8575740-M.jpg',
      detailUrl: 'https://openlibrary.org/works/OL1168083W',
      rating: '4.8',
      popularity: '👁 1.6K this week',
      genre: 'Dystopian',
      isOpds: true,
    ),
    TrendingBook(
      title: 'The Hobbit',
      sourceId: 'openlib',
      sourceName: 'Open Library',
      author: 'J.R.R. Tolkien',
      coverUrl: 'https://covers.openlibrary.org/b/id/8406786-M.jpg',
      detailUrl: 'https://openlibrary.org/works/OL262758W',
      rating: '4.9',
      popularity: '👁 1.4K this week',
      genre: 'Fantasy',
      isOpds: true,
    ),
    TrendingBook(
      title: 'To Kill a Mockingbird',
      sourceId: 'openlib',
      sourceName: 'Open Library',
      author: 'Harper Lee',
      coverUrl: 'https://covers.openlibrary.org/b/id/8225261-M.jpg',
      detailUrl: 'https://openlibrary.org/works/OL262447W',
      rating: '4.9',
      popularity: '👁 2.0K this week',
      genre: 'Classic',
      isOpds: true,
    ),
    TrendingBook(
      title: 'Brave New World',
      sourceId: 'openlib',
      sourceName: 'Open Library',
      author: 'Aldous Huxley',
      coverUrl: 'https://covers.openlibrary.org/b/id/8758486-M.jpg',
      detailUrl: 'https://openlibrary.org/works/OL52932W',
      rating: '4.7',
      popularity: '👁 1.3K this week',
      genre: 'Sci-fi',
      isOpds: true,
    ),
  ];

  Future<Map<String, List<TrendingBook>>> fetchOpdsTrending() async {
    final results = <String, List<TrendingBook>>{
      'gutenberg': List.of(_gutenbergDefaults),
      'standard': List.of(_standardEbooksDefaults),
      'feedbooks': List.of(_feedbooksDefaults),
      'openlib': List.of(_openLibDefaults),
    };

    try {
      // Opportunistically fetch live Open Library trending API
      final resp = await http.get(
        Uri.parse('https://openlibrary.org/trending/daily.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['works'] is List) {
          final liveList = <TrendingBook>[];
          for (final rawWork in (data['works'] as List).take(30)) {
            if (rawWork is! Map<String, dynamic> && rawWork is! Map) continue;
            final work = rawWork as Map;
            final title = work['title'] as String? ?? 'Untitled';
            final authors = work['author_name'];
            final author = (authors is List && authors.isNotEmpty)
                ? authors.first?.toString() ?? 'Unknown'
                : 'Unknown';
            final coverId = work['cover_i'];
            final coverUrl = coverId != null
                ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
                : null;
            final key = work['key'] as String? ?? '';
            liveList.add(
              TrendingBook(
                title: title,
                sourceId: 'openlib',
                sourceName: 'Open Library',
                author: author,
                coverUrl: coverUrl,
                detailUrl: 'https://openlibrary.org$key',
                rating: '4.8',
                popularity: '👁 Popular',
                genre: 'Classic',
                isOpds: true,
              ),
            );
          }
          if (liveList.isNotEmpty) {
            results['openlib'] = liveList;
          }
        }
      }
    } catch (e) {
      AppLogger.info('OPDS live fetch timed out or offline, using curated catalog: $e');
    }

    return results;
  }
}

