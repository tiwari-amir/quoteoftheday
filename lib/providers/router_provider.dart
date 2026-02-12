import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/category/category_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/mood/mood_screen.dart';
import '../screens/saved/saved_quotes_screen.dart';
import '../screens/viewer/quote_viewer_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const CategoryScreen(),
        ),
      ),
      GoRoute(
        path: '/moods',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const MoodScreen(),
        ),
      ),
      GoRoute(
        path: '/viewer/:type/:tag',
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            child: QuoteViewerScreen(
              type: state.pathParameters['type'] ?? 'category',
              tag: Uri.decodeComponent(state.pathParameters['tag'] ?? ''),
            ),
          );
        },
      ),
      GoRoute(
        path: '/saved',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const SavedQuotesScreen(),
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
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}
