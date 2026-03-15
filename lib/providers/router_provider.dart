import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/v3_settings/settings_screen.dart';
import '../features/v3_notifications/in_app_notifications_screen.dart';
import '../screens/author/authors_index_screen.dart';
import '../screens/author/author_quotes_screen.dart';
import '../screens/category/category_screen.dart';
import '../screens/mood/mood_screen.dart';
import '../screens/saved/saved_quotes_screen.dart';
import '../screens/search/search_quotes_results_screen.dart';
import '../screens/tabs/app_shell_scaffold.dart';
import '../screens/tabs/explore_tab_screen.dart';
import '../screens/tabs/library_tab_screen.dart';
import '../screens/tabs/today_tab_screen.dart';
import '../screens/viewer/quote_viewer_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    redirect: (context, state) {
      if (state.uri.path == '/') return '/today';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TodayTabScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExploreTabScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LibraryTabScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/viewer',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: QuoteViewerScreen(
            type: state.uri.queryParameters['type'] ?? 'explore',
            tag: state.uri.queryParameters['tag'] ?? '',
            quoteId: state.uri.queryParameters['quoteId'],
          ),
        ),
      ),
      GoRoute(
        path: '/viewer/:type/:tag',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: QuoteViewerScreen(
            type: state.pathParameters['type'] ?? 'category',
            tag: Uri.decodeComponent(state.pathParameters['tag'] ?? ''),
            quoteId: state.uri.queryParameters['quoteId'],
          ),
        ),
      ),
      GoRoute(
        path: '/authors',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: AuthorsIndexScreen(
            initialQuery: state.uri.queryParameters['q'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/authors/:authorKey',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: AuthorQuotesScreen(
            authorKey: Uri.decodeComponent(
              state.pathParameters['authorKey'] ?? '',
            ),
            authorName:
                state.uri.queryParameters['label'] ??
                Uri.decodeComponent(state.pathParameters['authorKey'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/updates',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const InAppNotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/saved',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const SavedQuotesScreen(),
        ),
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const CategoryScreen(),
        ),
      ),
      GoRoute(
        path: '/categories/:tag',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: CategoryScreen(
            selectedTag: Uri.decodeComponent(state.pathParameters['tag'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/moods',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildTransitionPage(key: state.pageKey, child: const MoodScreen()),
      ),
      GoRoute(
        path: '/moods/:tag',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: MoodScreen(
            selectedMood: Uri.decodeComponent(
              state.pathParameters['tag'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/search/quotes',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: SearchQuotesResultsScreen(
            query: state.uri.queryParameters['q'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
