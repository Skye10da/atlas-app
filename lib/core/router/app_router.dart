import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:atlas_app/browser/presentation/screens/source_immersive_screen.dart';
import 'package:atlas_app/core/design_system/organisms/app_scaffold.dart';
import 'package:atlas_app/core/presentation/screens/splash_screen.dart';
import 'package:atlas_app/core/router/transitions.dart';
import 'package:atlas_app/dictionary/presentation/screens/dictionary_screen.dart';
import 'package:atlas_app/discover/presentation/screens/reading_analytics_screen.dart';
import 'package:atlas_app/discover/presentation/screens/trending_list_screen.dart';
import 'package:atlas_app/library/presentation/screens/book_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/library_screen.dart';
import 'package:atlas_app/library/presentation/screens/novel_details_screen.dart';
import 'package:atlas_app/library/presentation/screens/source_browser_screen.dart';
import 'package:atlas_app/library/presentation/screens/source_search_screen.dart';
import 'package:atlas_app/marketing/presentation/screens/download_redirect_screen.dart';
import 'package:atlas_app/marketing/presentation/screens/landing_screen.dart';
import 'package:atlas_app/intelligence/domain/entities/reader_position.dart';
import 'package:atlas_app/intelligence/presentation/chat/chat_screen.dart';
import 'package:atlas_app/intelligence/presentation/settings/ai_provider_settings_screen.dart';
import 'package:atlas_app/notifications/presentation/screens/notification_screen.dart';
import 'package:atlas_app/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:atlas_app/reader/presentation/screens/bookmarks_screen.dart';
import 'package:atlas_app/reader/presentation/screens/reader_screen.dart';
import 'package:atlas_app/search/presentation/screens/search_screen.dart';
import 'package:atlas_app/settings/presentation/screens/settings_screen.dart';
import 'package:atlas_app/updater/presentation/screens/whats_new_screen.dart';

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
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const ReadingAnalyticsScreen()));
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
        queryParameters: {'type': type, 'source': ?source},
      );
      context.push(uri.toString());
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              TrendingListScreen(initialType: type, initialSource: source),
        ),
      );
    }
  }

  /// Opens the Story Intelligence Chat screen for a novel.
  static void openStoryChat(
    BuildContext context,
    String bookId, {
    int chapter = 1,
  }) {
    try {
      context.push('/intelligence/chat/$bookId?chapter=$chapter');
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            bookId: bookId,
            readerPosition: ReaderPosition(
              bookId: bookId,
              currentChapter: chapter,
            ),
          ),
        ),
      );
    }
  }

  /// Opens the AI Provider / BYOK configuration screen.
  static void openAiSettings(BuildContext context) {
    try {
      context.push('/intelligence/settings');
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const AiProviderSettingsScreen()),
      );
    }
  }

  /// Opens the What's-new (release notes history) screen. Context-free so the
  /// post-update banner action can push it from the bootstrap path.
  static void openWhatsNew() {
    router.push('/whats-new');
  }

  /// The web app opens on the marketing landing page; native builds open at
  /// the splash gate (onboarding → library).
  static const String initialLocation = kIsWeb ? '/' : '/splash';

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      // Discover was folded into the Library home and the "Find new" tab.
      if (state.uri.path == '/discover') return '/library';
      // File-manager launches can surface the raw file path as a deep link
      // (e.g. /509/folder/file.atlas). Never treat a filesystem path as a
      // route — swallow it and land on the library; the file_open channel
      // handles the import with a preview sheet.
      final lower = state.uri.path.toLowerCase();
      if (lower.endsWith('.atlas') ||
          lower.endsWith('.epub') ||
          lower.endsWith('.pdf') ||
          lower.endsWith('.txt') ||
          lower.endsWith('.md')) {
        return '/library';
      }
      return null;
    },
    errorBuilder: (context, state) =>
        _NotFoundScreen(uri: state.uri.toString(), error: state.error),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const SplashScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: OnboardingScreen(
            replay: state.uri.queryParameters['replay'] == '1',
          ),
          key: state.pageKey,
        ),
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
        // The saved words surface now lives in the Saved bottom-nav branch.
        redirect: (context, state) => '/bookmarks',
        pageBuilder: (context, state) => buildPageTransition(
          child: const DictionaryScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/whats-new',
        name: 'whatsNew',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const WhatsNewScreen(),
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
            child: TrendingListScreen(initialType: type, initialSource: source),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/intelligence/chat/:bookId',
        name: 'intelligenceChat',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chStr = state.uri.queryParameters['chapter'];
          final chapter = int.tryParse(chStr ?? '') ?? 1;
          return buildPageTransition(
            child: ChatScreen(
              bookId: bookId,
              readerPosition: ReaderPosition(
                bookId: bookId,
                currentChapter: chapter,
              ),
            ),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/intelligence/settings',
        name: 'intelligenceSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const AiProviderSettingsScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/',
        name: 'landing',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const LandingScreen(),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/download',
        name: 'download',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildPageTransition(
          child: const DownloadRedirectScreen(),
          key: state.pageKey,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0. Library (default)
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

          // 1. Find new (discovery + search & lookup)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                // Former Saved tab deep links land on the bookmark screen.
                redirect: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  if (tab == 'saved' || tab == 'dictionary') {
                    return '/bookmarks';
                  }
                  return null;
                },
                pageBuilder: (context, state) {
                  final query = state.uri.queryParameters['q'];
                  final tabStr = state.uri.queryParameters['tab'];
                  final tabIndex = switch (tabStr) {
                    'library' => 1,
                    'lookup' => 2,
                    _ => 0,
                  };
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

          // 2. Saved Bookmarks
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

          // 3. Settings
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

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.uri, this.error});

  final String uri;
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: cs.outline),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'No route for "$uri"',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go to Home'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/library'),
                child: const Text('Back to Library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
