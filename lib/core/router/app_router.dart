import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/browser/presentation/screens/browser_screen.dart';
import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/presentation/screens/splash_screen.dart';
import 'package:atlas_app/core/router/transitions.dart';
import 'package:atlas_app/dictionary/presentation/screens/dictionary_screen.dart';
import 'package:atlas_app/discover/presentation/screens/discover_screen.dart';
import 'package:atlas_app/discover/presentation/screens/reading_analytics_screen.dart';
import 'package:atlas_app/discover/presentation/screens/trending_list_screen.dart';
import 'package:atlas_app/library/presentation/screens/book_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/library/presentation/screens/novel_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/source_browser_screen.dart';
import 'package:atlas_app/library/presentation/screens/source_search_screen.dart';
import 'package:atlas_app/notifications/presentation/screens/notification_screen.dart';
import 'package:atlas_app/reader/presentation/screens/bookmarks_screen.dart';
import 'package:atlas_app/reader/presentation/screens/reader_screen.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';
import 'package:atlas_app/settings/presentation/screens/settings_screen.dart';

abstract final class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// The root navigator — pushes here appear over the shell branches (reader,
  /// detail pages) and over root-level routes alike.
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

  /// Safely navigates to the Reading Analytics dashboard.
  /// Falls back to direct Navigator push if GoRouter has not hot-restarted yet.
  static void openAnalytics(BuildContext context) {
    try {
      context.push('/analytics');
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => const ReadingAnalyticsScreen(),
        ),
      );
    }
  }

  /// Safely navigates to the Trending list screen.
  /// Falls back to direct Navigator push if GoRouter has not hot-restarted yet.
  static void openTrending(
    BuildContext context, {
    String type = 'opds',
    String? source,
  }) {
    try {
      final uri = Uri(
        path: '/trending',
        queryParameters: {
          'type': type,
          'source': ?source,
        },
      );
      context.push(uri.toString());
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => TrendingListScreen(
            initialType: type,
            initialSource: source,
          ),
        ),
      );
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            buildPageTransition(child: const SplashScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: ReaderScreen(bookId: state.pathParameters['bookId']!),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/sources',
        name: 'sources',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const SourceBrowserScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/sources/:name',
        name: 'sourceSearch',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: SourceSearchScreen(sourceName: state.pathParameters['name']!),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/browser',
        name: 'browser',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final url = state.uri.queryParameters['url'];
          return buildPageTransition(
            child: BrowserScreen(initialUrl: url),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/web',
        name: 'web',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? 'https://google.com';
          return buildPageTransition(
            child: SourceImmersiveScreen(initialUrl: url),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const NotificationScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/dictionary',
        name: 'dictionary',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const DictionaryScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/analytics',
        name: 'analytics',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const ReadingAnalyticsScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/trending',
        name: 'trending',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'opds';
          final source = state.uri.queryParameters['source'];
          return buildPageTransition(
            child: TrendingListScreen(
              initialType: type,
              initialSource: source,
            ),
            key: state.pageKey,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0. Discover Home (Default)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: 'discover',
                pageBuilder: (context, state) => buildPageTransition(
                  child: const DiscoverScreen(),
                  key: state.pageKey,
                ),
              ),
            ],
          ),

          // 1. Library Shelf
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                pageBuilder: (context, state) {
                  final genre = state.uri.queryParameters['genre'];
                  final sort = state.uri.queryParameters['sort'];
                  return buildPageTransition(
                    child: LibraryScreen(
                      initialGenre: genre,
                      initialSort: sort,
                    ),
                    key: state.pageKey,
                  );
                },
              ),
              GoRoute(
                path: '/book/:bookId',
                name: 'bookDetails',
                pageBuilder: (context, state) => buildPageTransition(
                  child: BookDetailsScreen(
                    bookId: state.pathParameters['bookId']!,
                  ),
                  key: state.pageKey,
                ),
              ),
              GoRoute(
                path: '/novel/:bookId',
                name: 'novelDetails',
                pageBuilder: (context, state) => buildPageTransition(
                  child: NovelDetailsScreen(
                    bookId: state.pathParameters['bookId']!,
                  ),
                  key: state.pageKey,
                ),
              ),
            ],
          ),

          // 2. Search & Lookup (Middle Position)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                pageBuilder: (context, state) {
                  final query = state.uri.queryParameters['q'];
                  final tabStr = state.uri.queryParameters['tab'];
                  final tabIndex = tabStr == 'dictionary' ? 1 : 0;
                  return buildPageTransition(
                    child: SearchScreen(
                      initialQuery: query,
                      initialTabIndex: tabIndex,
                    ),
                    key: state.pageKey,
                  );
                },
              ),
            ],
          ),

          // 3. Saved Bookmarks
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookmarks',
                name: 'bookmarks',
                pageBuilder: (context, state) => buildPageTransition(
                  child: const BookmarksScreen(),
                  key: state.pageKey,
                ),
              ),
            ],
          ),

          // 4. Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => buildPageTransition(
                  child: const SettingsScreen(),
                  key: state.pageKey,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

