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
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryScreen(),
      ),
      GoRoute(path: '/moods', builder: (context, state) => const MoodScreen()),
      GoRoute(
        path: '/viewer/:type/:tag',
        builder: (context, state) {
          return QuoteViewerScreen(
            type: state.pathParameters['type'] ?? 'category',
            tag: Uri.decodeComponent(state.pathParameters['tag'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedQuotesScreen(),
      ),
    ],
  );
});
