import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/router/transitions.dart';
import 'package:atlas_app/library/presentation/screens/book_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/reader/presentation/screens/bookmarks_screen.dart';
import 'package:atlas_app/reader/presentation/screens/reader_screen.dart';
import 'package:atlas_app/dictionary/presentation/screens/dictionary_screen.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';
import 'package:atlas_app/settings/presentation/screens/settings_screen.dart';

abstract final class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: ReaderScreen(bookId: state.pathParameters['bookId']!),
          key: state.pathParameters['bookId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'library',
                pageBuilder: (context, state) => buildPageTransition(
                  child: const LibraryScreen(),
                  key: 'library',
                ),
              ),
              GoRoute(
                path: '/book/:bookId',
                name: 'bookDetails',
                pageBuilder: (context, state) => buildPageTransition(
                  child: BookDetailsScreen(bookId: state.pathParameters['bookId']!),
                  key: 'book_${state.pathParameters['bookId']!}',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookmarks',
                name: 'bookmarks',
                pageBuilder: (context, state) =>
                    buildPageTransition(child: const BookmarksScreen(), key: 'bookmarks'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dictionary',
                name: 'dictionary',
                pageBuilder: (context, state) =>
                    buildPageTransition(child: const DictionaryScreen(), key: 'dictionary'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                pageBuilder: (context, state) =>
                    buildPageTransition(child: const SearchScreen(), key: 'search'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) =>
                    buildPageTransition(child: const SettingsScreen(), key: 'settings'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
