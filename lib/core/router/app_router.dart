import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/router/transitions.dart';
import 'package:atlas_app/library/presentation/screens/book_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/reader/presentation/screens/reader_screen.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';

abstract final class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

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
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => Scaffold(
          body: child,
          bottomNavigationBar: const AppBottomNav(),
        ),
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
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) =>
                buildPageTransition(child: const SearchScreen(), key: 'search'),
          ),
        ],
      ),
    ],
  );
}
