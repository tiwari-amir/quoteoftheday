import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quoteoftheday/features/v3_background/background_theme_provider.dart';
import 'package:quoteoftheday/features/v3_collections/collections_providers.dart';
import 'package:quoteoftheday/features/v3_notifications/in_app_notification_model.dart';
import 'package:quoteoftheday/features/v3_notifications/in_app_notifications_providers.dart';
import 'package:quoteoftheday/models/quote_model.dart';
import 'package:quoteoftheday/providers/quote_providers.dart';
import 'package:quoteoftheday/providers/storage_provider.dart';
import 'package:quoteoftheday/providers/supabase_provider.dart';
import 'package:quoteoftheday/screens/author/author_quotes_screen.dart';
import 'package:quoteoftheday/screens/tabs/app_shell_scaffold.dart';
import 'package:quoteoftheday/screens/tabs/explore_tab_screen.dart';
import 'package:quoteoftheday/screens/tabs/library_tab_screen.dart';
import 'package:quoteoftheday/screens/tabs/today_tab_screen.dart';
import 'package:quoteoftheday/features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import 'package:quoteoftheday/services/author_wiki_service.dart';
import 'package:quoteoftheday/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SilentAuthorWikiService extends AuthorWikiService {
  @override
  Future<AuthorWikiProfile?> fetchAuthor(String author) async => null;
}

final _sampleQuotes = <QuoteModel>[
  const QuoteModel(
    id: 'q1',
    quote:
        'Build slowly enough to preserve taste and fast enough to keep heat.',
    author: 'Dieter Rams',
    revisedTags: <String>['design', 'wisdom', 'calm'],
    categories: <String>['design', 'wisdom'],
    moods: <String>['calm'],
  ),
  const QuoteModel(
    id: 'q2',
    quote: 'The future is not found. It is prototyped.',
    author: 'Grace Hopper',
    revisedTags: <String>['innovation', 'success', 'motivated'],
    categories: <String>['innovation', 'success'],
    moods: <String>['motivated'],
  ),
  const QuoteModel(
    id: 'q3',
    quote: 'Luxury is clarity under pressure.',
    author: 'Jony Ive',
    revisedTags: <String>['beauty', 'leadership', 'confident'],
    categories: <String>['beauty', 'leadership'],
    moods: <String>['confident'],
  ),
];

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/today',
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
    ],
  );
}

Future<Widget> _buildTestApp({
  QuoteModel? dailyQuote,
  AppBackgroundTheme backgroundTheme = AppBackgroundTheme.spaceGalaxies,
  Map<String, Object>? preloadedPreferences,
  List<QuoteModel>? quotes,
}) async {
  final testQuotes = quotes ?? _sampleQuotes;
  SharedPreferences.setMockInitialValues(<String, Object>{
    'v1.saved_quote_ids': '["q1","q2"]',
    'v1.liked_quote_ids': '["q2"]',
    'v3.app_background_theme': backgroundTheme.id,
    if (preloadedPreferences != null) ...preloadedPreferences,
  });
  final prefs = await SharedPreferences.getInstance();
  final router = _buildRouter();
  final supabaseClient = SupabaseClient(
    'https://example.com',
    'anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(supabaseClient),
      authorWikiServiceProvider.overrideWithValue(_SilentAuthorWikiService()),
      allQuotesProvider.overrideWith((ref) async => testQuotes),
      dailyQuoteProvider.overrideWith(
        (ref) async => dailyQuote ?? testQuotes.first,
      ),
      topLikedQuotesProvider.overrideWith((ref) async => testQuotes),
      categoryCountsProvider.overrideWith(
        (ref) async => const <String, int>{
          'design': 8,
          'innovation': 6,
          'beauty': 4,
          'leadership': 5,
          'wisdom': 7,
          'success': 9,
        },
      ),
      moodCountsProvider.overrideWith(
        (ref) async => const <String, int>{
          'calm': 4,
          'motivated': 5,
          'confident': 3,
        },
      ),
      topAuthorsOfMonthProvider.overrideWith(
        (ref) async => const <MonthlyAuthorSpotlight>[
          MonthlyAuthorSpotlight(
            authorKey: 'dieter-rams',
            authorName: 'Dieter Rams',
            rankScore: 10,
            totalQuotes: 12,
            topQuotes: <QuoteModel>[],
          ),
          MonthlyAuthorSpotlight(
            authorKey: 'grace-hopper',
            authorName: 'Grace Hopper',
            rankScore: 9,
            totalQuotes: 11,
            topQuotes: <QuoteModel>[],
          ),
        ],
      ),
      latestInAppNotificationProvider.overrideWithValue(
        InAppNotificationModel(
          id: 1,
          type: 'system',
          title: 'Fresh quotes',
          body: 'New quotes landed',
          actionRoute: '/updates',
          createdAt: DateTime(2026, 3, 9),
          metadata: const <String, dynamic>{},
          quotesAdded: 0,
          totalQuotes: 0,
          prunedQuotes: 0,
        ),
      ),
      hasUnreadInAppNotificationsProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(
      theme: AppTheme.darkThemeFor(backgroundTheme),
      routerConfig: router,
    ),
  );
}

Future<Widget> _buildAuthorTestApp({
  required String authorKey,
  required String authorName,
  required QuoteModel quote,
  AppBackgroundTheme backgroundTheme = AppBackgroundTheme.spaceGalaxies,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'v1.saved_quote_ids': '["q1"]',
    'v1.liked_quote_ids': '["q1"]',
    'v3.app_background_theme': backgroundTheme.id,
  });
  final prefs = await SharedPreferences.getInstance();
  final supabaseClient = SupabaseClient(
    'https://example.com',
    'anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(supabaseClient),
      authorWikiServiceProvider.overrideWithValue(_SilentAuthorWikiService()),
      allQuotesProvider.overrideWith((ref) async => <QuoteModel>[quote]),
      dailyQuoteProvider.overrideWith((ref) async => quote),
    ],
    child: MaterialApp(
      theme: AppTheme.darkThemeFor(backgroundTheme),
      home: AuthorQuotesScreen(authorKey: authorKey, authorName: authorName),
    ),
  );
}

Future<Widget> _buildSaveSheetTestApp({
  AppBackgroundTheme backgroundTheme = AppBackgroundTheme.spaceGalaxies,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'v1.saved_quote_ids': '[]',
    'v1.liked_quote_ids': '[]',
    'v3.app_background_theme': backgroundTheme.id,
  });
  final prefs = await SharedPreferences.getInstance();
  final supabaseClient = SupabaseClient(
    'https://example.com',
    'anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(supabaseClient),
      authorWikiServiceProvider.overrideWithValue(_SilentAuthorWikiService()),
      allQuotesProvider.overrideWith((ref) async => _sampleQuotes),
      dailyQuoteProvider.overrideWith((ref) async => _sampleQuotes.first),
    ],
    child: MaterialApp(
      theme: AppTheme.darkThemeFor(backgroundTheme),
      home: Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, _) {
              final collectionsCount = ref.watch(
                collectionsProvider.select((state) => state.collections.length),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Collections: $collectionsCount'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => showSaveQuoteSheet(context, ref, 'q1'),
                    child: const Text('Open save sheet'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<Widget> _buildCreateCollectionTestApp({
  AppBackgroundTheme backgroundTheme = AppBackgroundTheme.spaceGalaxies,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'v1.saved_quote_ids': '[]',
    'v1.liked_quote_ids': '[]',
    'v3.app_background_theme': backgroundTheme.id,
  });
  final prefs = await SharedPreferences.getInstance();
  final supabaseClient = SupabaseClient(
    'https://example.com',
    'anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(supabaseClient),
      authorWikiServiceProvider.overrideWithValue(_SilentAuthorWikiService()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkThemeFor(backgroundTheme),
      home: Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, _) {
              final collectionsCount = ref.watch(
                collectionsProvider.select((state) => state.collections.length),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Collections: $collectionsCount'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => showCreateCollectionSheet(context, ref),
                    child: const Text('Open collection creator'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 30,
  Duration step = const Duration(milliseconds: 120),
}) async {
  for (var tick = 0; tick < maxTicks; tick++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }

  fail('Timed out waiting for $finder.');
}

void main() {
  testWidgets('home explore and library render through the shell', (
    tester,
  ) async {
    final app = await _buildTestApp();
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TodayTabScreen), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-explore')));
    await _pumpUntilVisible(tester, find.text('Moods'));

    expect(find.byType(ExploreTabScreen), findsOneWidget);
    expect(find.text('Moods'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dock-library')));
    await _pumpUntilVisible(tester, find.byType(LibraryTabScreen));

    expect(find.byType(LibraryTabScreen), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
  });

  testWidgets('today screen does not overflow on shorter phone heights', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 780);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final longQuote = _sampleQuotes.first.copyWith(
      quote:
          'Design should feel inevitable when it reaches the user, but that inevitability comes from restraint, revision, patience, and a willingness to remove anything that does not serve the emotional center of the experience.',
    );

    for (final theme in AppBackgroundTheme.values) {
      final app = await _buildTestApp(
        dailyQuote: longQuote,
        backgroundTheme: theme,
      );
      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.byType(TodayTabScreen),
        findsOneWidget,
        reason: 'Today screen missing for ${theme.label}',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception for ${theme.label}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 120));
    }
  });

  testWidgets('author header does not overflow with long author names', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 780);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longAuthor = 'Alexandria Catherine Montgomery Van Der Meer the Third';
    const quote = QuoteModel(
      id: 'long-author-q1',
      quote:
          'A long header still needs to feel composed, balanced, and fully contained.',
      author: longAuthor,
      canonicalAuthor: longAuthor,
      revisedTags: <String>['design', 'calm'],
      categories: <String>['design'],
      moods: <String>['calm'],
    );

    final app = await _buildAuthorTestApp(
      authorKey: 'alexandria-catherine-montgomery-van-der-meer-the-third',
      authorName: longAuthor,
      quote: quote,
    );

    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(AuthorQuotesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library stays stable with long shelf names on smaller phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 780);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final app = await _buildTestApp(
      preloadedPreferences: <String, Object>{
        'v3.collections': jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': 'shelf-1',
            'name':
                'Collected meditations on restraint, clarity, and making less feel deeper',
            'created_at': DateTime(2026, 3, 14).toIso8601String(),
          },
          <String, Object>{
            'id': 'shelf-2',
            'name':
                'Notes for luminous systems and quiet product decisions under pressure',
            'created_at': DateTime(2026, 3, 13).toIso8601String(),
          },
        ]),
        'v3.collection_memberships': jsonEncode(<String, List<String>>{
          'shelf-1': <String>['q1', 'q2'],
          'shelf-2': <String>['q2'],
        }),
      },
    );

    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('dock-library')));
    await _pumpUntilVisible(tester, find.byType(LibraryTabScreen));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(LibraryTabScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibraryTabScreen)),
    );
    container.read(collectionsProvider.notifier).selectCollection('shelf-1');
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    final likedModeFinder = find.text('Liked').last;
    await tester.scrollUntilVisible(
      likedModeFinder,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(likedModeFinder);
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('library suggested quote shelf does not overflow on smaller phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 780);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final longRecommendationQuotes = <QuoteModel>[
      _sampleQuotes[0].copyWith(
        quote:
            'Build slowly enough to preserve taste and fast enough to keep heat while still leaving room for patience, revision, contradiction, and the quiet discipline that makes an idea worth keeping.',
      ),
      _sampleQuotes[1].copyWith(
        quote:
            'The future is not found. It is prototyped through brave iteration, careful editing, strong points of view, and a refusal to confuse volume with depth.',
      ),
      _sampleQuotes[2],
    ];

    final app = await _buildTestApp(quotes: longRecommendationQuotes);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('dock-library')));
    await _pumpUntilVisible(tester, find.byType(LibraryTabScreen));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(LibraryTabScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library search opens a saved-only search experience', (
    tester,
  ) async {
    final app = await _buildTestApp();
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('dock-library')));
    await _pumpUntilVisible(tester, find.byType(LibraryTabScreen));
    await tester.pump(const Duration(milliseconds: 600));

    final searchField = find.byKey(const ValueKey('library-search-field'));
    await tester.scrollUntilVisible(
      searchField,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(searchField);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField).last, 'future');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Library'), findsWidgets);
    expect(
      find.textContaining('The future is not found. It is prototyped.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared collection creator can create a new collection', (
    tester,
  ) async {
    final app = await _buildCreateCollectionTestApp();
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Collections: 0'), findsOneWidget);

    await tester.tap(find.text('Open collection creator'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Quiet Notes');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Collections: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save sheet can create a new collection with a quote', (
    tester,
  ) async {
    final app = await _buildSaveSheetTestApp();
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Collections: 0'), findsOneWidget);

    await tester.tap(find.text('Open save sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Scroll Saves');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Collections: 1'), findsOneWidget);
    await tester.tap(find.text('Open save sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Scroll Saves'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
