import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        ),
        routes: [
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (context, state) => const _PlaceholderScreen(
              label: 'Library',
            ),
          ),
          GoRoute(
            path: '/reader/:bookId',
            name: 'reader',
            builder: (context, state) => const _PlaceholderScreen(
              label: 'Reader',
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const _PlaceholderScreen(
              label: 'Search',
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const _PlaceholderScreen(
              label: 'Settings',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const _PlaceholderScreen(
          label: 'Auth',
        ),
      ),
    ],
  );
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label),
    );
  }
}
