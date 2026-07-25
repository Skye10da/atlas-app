import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/design_system/organisms/placeholder_screens.dart';
import 'package:atlas_app/core/router/transitions.dart';

abstract final class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/library',
    routes: [
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
            path: '/reader/:bookId',
            name: 'reader',
            pageBuilder: (context, state) => buildPageTransition(
              child: const ReaderScreen(),
              key: 'reader',
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => buildPageTransition(
              child: const SearchScreen(),
              key: 'search',
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => buildPageTransition(
              child: const SettingsScreen(),
              key: 'settings',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) => buildPageTransition(
          child: const AuthScreen(),
          key: 'auth',
        ),
      ),
    ],
  );
}
