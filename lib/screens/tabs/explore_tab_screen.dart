import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../features/v3_explore/discovery_category_utils.dart';
import '../../features/v3_search/search_result_groups.dart';
import '../../features/v3_search/search_service.dart';
import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/storage_provider.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium/premium_author_discovery_card.dart';
import '../../widgets/premium/premium_search_field.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/premium/premium_editorial_components.dart';
import '../../widgets/scale_tap.dart';

class ExploreTabScreen extends ConsumerStatefulWidget {
  const ExploreTabScreen({super.key});

  @override
  ConsumerState<ExploreTabScreen> createState() => _ExploreTabScreenState();
}

class _ExploreTabScreenState extends ConsumerState<ExploreTabScreen> {
  static const String _kRecentSearchesKey = 'explore.recent_searches_v1';
  static const int _kRecentSearchesLimit = 12;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  String? _tagFilter;
  SearchService? _searchService;
  String _quotesSignature = '';
  List<String> _recentSearches = const <String>[];
  bool _searchPanelPinned = false;
  bool _preserveSearchPanelOnFocusLoss = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) {
        if (!_searchPanelPinned) {
          setState(() => _searchPanelPinned = true);
          return;
        }
      } else {
        unawaited(_pushRecentSearch(_controller.text));
        if (_query.isEmpty &&
            _searchPanelPinned &&
            !_preserveSearchPanelOnFocusLoss) {
          setState(() => _searchPanelPinned = false);
          return;
        }
      }
      setState(() {});
    });
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    final prefs = ref.read(sharedPreferencesProvider);
    final values = prefs.getStringList(_kRecentSearchesKey) ?? const <String>[];
    _recentSearches = values
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _saveRecentSearches(List<String> values) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_kRecentSearchesKey, values);
  }

  Future<void> _pushRecentSearch(String rawQuery) async {
    final normalized = rawQuery.trim();
    if (normalized.isEmpty) return;
    final updated = <String>[
      normalized,
      ..._recentSearches.where(
        (entry) => entry.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(_kRecentSearchesLimit).toList(growable: false);
    setState(() => _recentSearches = updated);
    await _saveRecentSearches(updated);
  }

  Future<void> _removeRecentSearch(String rawQuery) async {
    final normalized = rawQuery.trim().toLowerCase();
    final updated = _recentSearches
        .where((entry) => entry.trim().toLowerCase() != normalized)
        .toList(growable: false);
    setState(() => _recentSearches = updated);
    await _saveRecentSearches(updated);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kRecentSearchesKey);
  }

  void _restoreSearchFocus() {
    if (mounted && !_searchPanelPinned) {
      setState(() => _searchPanelPinned = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  Future<void> _runSearchPanelAction(Future<void> Function() action) async {
    _preserveSearchPanelOnFocusLoss = true;
    if (mounted && !_searchPanelPinned) {
      setState(() => _searchPanelPinned = true);
    }
    await action();
    _restoreSearchFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preserveSearchPanelOnFocusLoss = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  Future<void> _onSearchSubmitted(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    setState(() => _query = normalized);
    await _pushRecentSearch(normalized);
    if (!mounted) return;
    _searchFocusNode.unfocus();
  }

  Future<void> _selectRecentSearch(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    _controller.text = normalized;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );
    setState(() => _query = normalized);
    await _pushRecentSearch(normalized);
    if (!mounted) return;
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(allQuotesProvider);
    final categoryCountsAsync = ref.watch(categoryCountsProvider);
    final moodsAsync = ref.watch(moodCountsProvider);
    final topAuthorsAsync = ref.watch(topAuthorsOfMonthProvider);
    final authorCatalogAsync = ref.watch(authorCatalogProvider);
    final service = ref.read(quoteServiceProvider);
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(seed: 63),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding,
                    layout.horizontalPadding,
                    layout.isCompact ? FlowSpace.lg : FlowSpace.xl,
                  ),
                  child: quotesAsync.when(
                    data: (quotes) {
                      _ensureExploreCaches(quotes);
                      final searchService = _searchService!;
                      final searchResults = _query.isEmpty
                          ? const <QuoteModel>[]
                          : searchService.searchQuotes(
                              _query,
                              tagFilter: _tagFilter,
                              limit: 80,
                            );
                      final inSearchMode =
                          _searchFocusNode.hasFocus ||
                          _query.isNotEmpty ||
                          _searchPanelPinned;

                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Text(
                            'Explore',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: layout.isCompact ? 32 : null,
                                ),
                          ).animate().fadeIn(duration: FlowDurations.regular),
                          const SizedBox(height: FlowSpace.md),
                          PremiumSearchField(
                            controller: _controller,
                            focusNode: _searchFocusNode,
                            hintText: 'Search quotes, authors, or tags',
                            onChanged: _onSearchChanged,
                            onSubmitted: (value) =>
                                unawaited(_onSearchSubmitted(value)),
                            onClear: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                          const SizedBox(height: FlowSpace.sm),
                          if (inSearchMode)
                            _query.isEmpty
                                ? _RecentSearchesCard(
                                    searches: _recentSearches,
                                    onSelect: (item) =>
                                        unawaited(_selectRecentSearch(item)),
                                    onRemove: (item) => unawaited(
                                      _runSearchPanelAction(() async {
                                        await _removeRecentSearch(item);
                                      }),
                                    ),
                                    onClearAll: () => unawaited(
                                      _runSearchPanelAction(() async {
                                        await _clearRecentSearches();
                                      }),
                                    ),
                                  )
                                : authorCatalogAsync.when(
                                    data: (catalog) => _SearchResultsSection(
                                      query: _query,
                                      moods: searchMoodMatches(
                                        _query,
                                        searchResults,
                                        limit: 12,
                                      ),
                                      authors: searchAuthorMatches(
                                        _query,
                                        searchResults,
                                        catalog,
                                        limit: 18,
                                      ),
                                      quotes: searchResults,
                                      onOpenMood: (tag) =>
                                          unawaited(_showMoodModeSheet(tag)),
                                      onOpenAuthor: (author) => context.push(
                                        '/authors/${Uri.encodeComponent(author.authorKey)}?label=${Uri.encodeQueryComponent(author.authorName)}',
                                      ),
                                      onShowAllAuthors: () => context.push(
                                        '/authors?q=${Uri.encodeQueryComponent(_query)}',
                                      ),
                                      onShowAllQuotes: () => context.push(
                                        '/search/quotes?q=${Uri.encodeQueryComponent(_query)}',
                                      ),
                                      onOpenQuote: (quote) => context.push(
                                        '/viewer/search/${Uri.encodeComponent(_query)}?quoteId=${quote.id}',
                                      ),
                                    ),
                                    loading: () => const Padding(
                                      padding: EdgeInsets.only(
                                        top: FlowSpace.lg,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    error: (error, stack) =>
                                        _ExploreErrorCard(error: error),
                                  )
                          else
                            categoryCountsAsync.when(
                              data: (categoryCounts) => moodsAsync.when(
                                data: (moods) => topAuthorsAsync.when(
                                  data: (authors) => _ExploreBentoBoard(
                                    categories: categoryCounts,
                                    quotes: quotes,
                                    moods: moods,
                                    topAuthors: authors,
                                    service: service,
                                    onOpenAuthors: () =>
                                        context.push('/authors'),
                                    onOpenAuthor: (author) => context.push(
                                      '/authors/${Uri.encodeComponent(author.authorKey)}?label=${Uri.encodeQueryComponent(author.authorName)}',
                                    ),
                                    onOpenCategory: (tag) =>
                                        unawaited(_showCategoryModeSheet(tag)),
                                    onOpenMood: (tag) =>
                                        unawaited(_showMoodModeSheet(tag)),
                                  ),
                                  loading: () => const _ExploreLoader(),
                                  error: (error, stack) =>
                                      _ExploreErrorCard(error: error),
                                ),
                                loading: () => const _ExploreLoader(),
                                error: (error, stack) =>
                                    _ExploreErrorCard(error: error),
                              ),
                              loading: () => const _ExploreLoader(),
                              error: (error, stack) =>
                                  _ExploreErrorCard(error: error),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(child: _ExploreLoader()),
                    error: (error, stack) =>
                        Center(child: _ExploreErrorCard(error: error)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureExploreCaches(List<QuoteModel> quotes) {
    final signature = _quotesSignatureFor(quotes);
    if (_quotesSignature == signature && _searchService != null) return;
    _quotesSignature = signature;
    _searchService = SearchService(quotes);
  }

  String _quotesSignatureFor(List<QuoteModel> quotes) {
    if (quotes.isEmpty) return '0';
    return '${quotes.length}:${quotes.first.id}:${quotes.last.id}';
  }

  Future<void> _showMoodModeSheet(String mood) async {
    final label = ref.read(quoteServiceProvider).toTitleCase(mood);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) => _MoodModeSheet(
        moodLabel: label,
        onList: () {
          Navigator.of(sheetContext).pop();
          context.push('/moods/${Uri.encodeComponent(mood)}');
        },
        onScroll: () {
          Navigator.of(sheetContext).pop();
          context.push('/viewer/mood/${Uri.encodeComponent(mood)}');
        },
      ),
    );
  }

  Future<void> _showCategoryModeSheet(String rawCategory) async {
    final routeTag = _categoryRouteTag(rawCategory);
    final label = _categoryLabel(rawCategory);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) => _CategoryModeSheet(
        categoryLabel: label,
        onList: () {
          Navigator.of(sheetContext).pop();
          context.push('/categories/${Uri.encodeComponent(routeTag)}');
        },
        onScroll: () {
          Navigator.of(sheetContext).pop();
          context.push('/viewer/category/${Uri.encodeComponent(routeTag)}');
        },
      ),
    );
  }
}

class _ExploreBentoBoard extends StatelessWidget {
  const _ExploreBentoBoard({
    required this.categories,
    required this.quotes,
    required this.moods,
    required this.topAuthors,
    required this.service,
    required this.onOpenAuthors,
    required this.onOpenAuthor,
    required this.onOpenCategory,
    required this.onOpenMood,
  });

  final Map<String, int> categories;
  final List<QuoteModel> quotes;
  final Map<String, int> moods;
  final List<MonthlyAuthorSpotlight> topAuthors;
  final QuoteService service;
  final VoidCallback onOpenAuthors;
  final ValueChanged<MonthlyAuthorSpotlight> onOpenAuthor;
  final ValueChanged<String> onOpenCategory;
  final ValueChanged<String> onOpenMood;

  @override
  Widget build(BuildContext context) {
    final layout = FlowLayoutInfo.of(context);
    final featuredRailHeight = layout.isCompact
        ? 206.0
        : layout.isTablet
        ? 220.0
        : 214.0;
    final featuredRailCardWidth = layout.isCompact
        ? 136.0
        : layout.isTablet
        ? 154.0
        : 146.0;
    final sortedMoods = moods.entries.toList(growable: false)
      ..sort((a, b) {
        final ai = moodAllowlist.indexOf(a.key);
        final bi = moodAllowlist.indexOf(b.key);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        return a.key.compareTo(b.key);
      });
    final allCategories = categories.entries.toList(growable: false)
      ..sort(
        (a, b) => discoveryCategoryLabel(
          a.key,
        ).compareTo(discoveryCategoryLabel(b.key)),
      );
    final recentCategory = pickRecentDiscoveryCategory(quotes);
    final topCategoryKeys = selectTopCategoryKeys(
      categories,
      recentCategory: recentCategory,
    );

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialSectionHeader(title: 'Moods', eyebrow: 'DISCOVER'),
            const SizedBox(height: FlowSpace.xxs),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = layout.fluid(min: 4, max: 8);
                final columns = layout.columnsFor(
                  constraints.maxWidth,
                  minTileWidth: layout.isCompact
                      ? 96
                      : layout.isTablet
                      ? 120
                      : 108,
                  maxColumns: layout.isDesktop
                      ? 8
                      : layout.isTablet
                      ? 6
                      : constraints.maxWidth >= 500
                      ? 5
                      : constraints.maxWidth >= 420
                      ? 4
                      : constraints.maxWidth >= 360
                      ? 3
                      : 2,
                );
                final tileWidth = layout.tileWidthFor(
                  constraints.maxWidth,
                  columns: columns,
                  gap: gap,
                );
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final mood in sortedMoods)
                      SizedBox(
                        width: tileWidth,
                        child: _ExploreMoodTile(
                          moodKey: mood.key,
                          title: service.toTitleCase(mood.key),
                          width: tileWidth,
                          onTap: () => onOpenMood(mood.key),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: FlowSpace.lg),
            EditorialSectionHeader(
              title: 'Top Authors',
              eyebrow: 'PEOPLE',
              actionLabel: 'All',
              onActionTap: onOpenAuthors,
            ),
            const SizedBox(height: FlowSpace.xs),
            SizedBox(
              height: featuredRailHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: topAuthors
                    .take(
                      layout.isDesktop
                          ? 12
                          : layout.isTablet
                          ? 10
                          : 8,
                    )
                    .length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: layout.fluid(min: 10, max: 14)),
                itemBuilder: (context, index) {
                  final author = topAuthors[index];
                  return SizedBox(
                    width: featuredRailCardWidth,
                    child: PremiumAuthorDiscoveryCard(
                      authorName: author.authorName,
                      rank: index + 1,
                      quoteCount: author.totalQuotes,
                      variant: PremiumAuthorDiscoveryCardVariant.rail,
                      animationIndex: index,
                      onTap: () => onOpenAuthor(author),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: FlowSpace.xl),
            EditorialSectionHeader(title: 'Top Categories', eyebrow: 'POPULAR'),
            const SizedBox(height: FlowSpace.xs),
            SizedBox(
              height: featuredRailHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: topCategoryKeys.length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: layout.fluid(min: 10, max: 14)),
                itemBuilder: (context, index) {
                  final categoryKey = topCategoryKeys[index];
                  final isNewlyAdded =
                      index == 0 && recentCategory == categoryKey;
                  return SizedBox(
                    width: featuredRailCardWidth,
                    child: _FeaturedExploreCategoryCard(
                      categoryKey: categoryKey,
                      title: isNewlyAdded
                          ? 'Newly Added'
                          : discoveryCategoryLabel(categoryKey),
                      subtitle: isNewlyAdded
                          ? discoveryCategoryLabel(categoryKey)
                          : 'Popular category',
                      rankLabel: (index + 1).toString().padLeft(2, '0'),
                      width: featuredRailCardWidth,
                      onTap: () => onOpenCategory(categoryKey),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: FlowSpace.xl),
            EditorialSectionHeader(title: 'Categories', eyebrow: 'A-Z'),
            const SizedBox(height: FlowSpace.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = layout.fluid(min: 8, max: 12);
                final columns = layout.columnsFor(
                  constraints.maxWidth,
                  minTileWidth: layout.isCompact ? 118 : 138,
                  maxColumns: layout.isDesktop
                      ? 6
                      : layout.isTablet
                      ? 5
                      : constraints.maxWidth >= 520
                      ? 4
                      : constraints.maxWidth >= 420
                      ? 3
                      : constraints.maxWidth >= 360
                      ? 3
                      : 2,
                );
                final tileWidth = layout.tileWidthFor(
                  constraints.maxWidth,
                  columns: columns,
                  gap: gap,
                );
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final category in allCategories)
                      SizedBox(
                        width: tileWidth,
                        child: _ExploreCategoryCard(
                          categoryKey: category.key,
                          title: discoveryCategoryLabel(category.key),
                          width: tileWidth,
                          onTap: () => onOpenCategory(category.key),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        )
        .animate()
        .fadeIn(duration: FlowDurations.regular)
        .moveY(
          begin: 14,
          end: 0,
          duration: FlowDurations.emphasized,
          curve: FlowDurations.curve,
        );
  }
}

class _ExploreMoodTile extends StatelessWidget {
  const _ExploreMoodTile({
    required this.moodKey,
    required this.title,
    required this.onTap,
    this.width,
  });

  final String moodKey;
  final String title;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final layout = FlowLayoutInfo.of(context);
    final visual = _moodVisuals[moodKey] ?? _moodVisuals['calm']!;
    final tileWidth = width ?? (layout.isCompact ? 104 : 116);
    final tileHeight = layout.isCompact ? 42.0 : 46.0;

    return ScaleTap(
      onTap: onTap,
      child: PremiumGlassCard(
        borderRadius: 14,
        elevation: 0,
        tone: PremiumGlassTone.subtle,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    visual.start,
                    colors?.surface ?? Colors.black,
                    0.42,
                  )!.withValues(alpha: 0.88),
                  Color.lerp(
                    visual.end,
                    colors?.elevatedSurface ?? Colors.black,
                    0.56,
                  )!.withValues(alpha: 0.86),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: visual.start.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: layout.isCompact ? 6 : 8,
                vertical: layout.isCompact ? 5 : 6,
              ),
              child: Row(
                children: [
                  Container(
                    width: layout.isCompact ? 20 : 22,
                    height: layout.isCompact ? 20 : 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: SvgPicture.asset(
                      visual.assetPath,
                      width: layout.isCompact ? 9 : 10,
                      height: layout.isCompact ? 9 : 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors?.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: layout.isCompact ? 10.6 : 11.3,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodModeSheet extends StatelessWidget {
  const _MoodModeSheet({
    required this.moodLabel,
    required this.onList,
    required this.onScroll,
  });

  final String moodLabel;
  final VoidCallback onList;
  final VoidCallback onScroll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.lg,
      ),
      child: PremiumSurface(
        radius: FlowRadii.xl,
        elevation: 2,
        blurSigma: 20,
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.lg,
          FlowSpace.lg,
          FlowSpace.lg,
          FlowSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(moodLabel, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: FlowSpace.xs),
            Text(
              'Choose how you want to browse this mood.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: FlowSpace.md),
            _MoodModeOption(
              icon: Icons.view_agenda_rounded,
              title: 'List',
              subtitle: 'Browse quotes in a clean vertical list',
              onTap: onList,
            ),
            const SizedBox(height: FlowSpace.sm),
            _MoodModeOption(
              icon: Icons.vertical_distribute_rounded,
              title: 'Scroll',
              subtitle: 'Open the full-screen quote reel',
              onTap: onScroll,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryModeSheet extends StatelessWidget {
  const _CategoryModeSheet({
    required this.categoryLabel,
    required this.onList,
    required this.onScroll,
  });

  final String categoryLabel;
  final VoidCallback onList;
  final VoidCallback onScroll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.lg,
      ),
      child: PremiumSurface(
        radius: FlowRadii.xl,
        elevation: 2,
        blurSigma: 20,
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.lg,
          FlowSpace.lg,
          FlowSpace.lg,
          FlowSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: FlowSpace.xs),
            Text(
              'Choose how you want to browse this category.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: FlowSpace.md),
            _MoodModeOption(
              icon: Icons.view_agenda_rounded,
              title: 'List',
              subtitle: 'Browse quotes in a clean vertical list',
              onTap: onList,
            ),
            const SizedBox(height: FlowSpace.sm),
            _MoodModeOption(
              icon: Icons.vertical_distribute_rounded,
              title: 'Scroll',
              subtitle: 'Open the full-screen quote reel',
              onTap: onScroll,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodModeOption extends StatelessWidget {
  const _MoodModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return ScaleTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.xs,
          vertical: FlowSpace.xs,
        ),
        child: Row(
          children: [
            Icon(icon, color: colors?.accentSecondary, size: 20),
            const SizedBox(width: FlowSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colors?.textSecondary.withValues(alpha: 0.78),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodVisualSpec {
  const _MoodVisualSpec({
    required this.assetPath,
    required this.start,
    required this.end,
  });

  final String assetPath;
  final Color start;
  final Color end;
}

const Map<String, _MoodVisualSpec> _moodVisuals = {
  'happy': _MoodVisualSpec(
    assetPath: 'assets/moods/happy.svg',
    start: Color(0xFFE7A93C),
    end: Color(0xFFF6D77C),
  ),
  'sad': _MoodVisualSpec(
    assetPath: 'assets/moods/sad.svg',
    start: Color(0xFF5C7BA8),
    end: Color(0xFF9BB8D9),
  ),
  'motivated': _MoodVisualSpec(
    assetPath: 'assets/moods/motivated.svg',
    start: Color(0xFFE08B44),
    end: Color(0xFFF0C06B),
  ),
  'calm': _MoodVisualSpec(
    assetPath: 'assets/moods/calm.svg',
    start: Color(0xFF4F9F8B),
    end: Color(0xFF97D0C2),
  ),
  'confident': _MoodVisualSpec(
    assetPath: 'assets/moods/confident.svg',
    start: Color(0xFF9674E0),
    end: Color(0xFFC7A4F1),
  ),
  'lonely': _MoodVisualSpec(
    assetPath: 'assets/moods/lonely.svg',
    start: Color(0xFF546178),
    end: Color(0xFF9CA8BE),
  ),
  'angry': _MoodVisualSpec(
    assetPath: 'assets/moods/angry.svg',
    start: Color(0xFFC65538),
    end: Color(0xFFE88F59),
  ),
  'grateful': _MoodVisualSpec(
    assetPath: 'assets/moods/grateful.svg',
    start: Color(0xFF8F7A43),
    end: Color(0xFFD6B86B),
  ),
  'anxious': _MoodVisualSpec(
    assetPath: 'assets/moods/anxious.svg',
    start: Color(0xFF5E6A86),
    end: Color(0xFF8AA0C0),
  ),
  'romantic': _MoodVisualSpec(
    assetPath: 'assets/moods/romantic.svg',
    start: Color(0xFFC56E7E),
    end: Color(0xFFE5A2B1),
  ),
  'hopeful': _MoodVisualSpec(
    assetPath: 'assets/moods/hopeful.svg',
    start: Color(0xFF6E8AC6),
    end: Color(0xFFD0C17A),
  ),
  'stressed': _MoodVisualSpec(
    assetPath: 'assets/moods/stressed.svg',
    start: Color(0xFF7B6A92),
    end: Color(0xFFB79BC4),
  ),
};

class _ExploreCategoryCard extends StatelessWidget {
  const _ExploreCategoryCard({
    required this.categoryKey,
    required this.title,
    required this.onTap,
    this.width,
  });

  final String categoryKey;
  final String title;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final layout = FlowLayoutInfo.of(context);
    final visual = _categoryVisualFor(categoryKey);
    final tileWidth = width ?? (layout.isCompact ? 118 : 132);
    final tileHeight = layout.isCompact ? 42.0 : 46.0;

    return ScaleTap(
      onTap: onTap,
      child: PremiumGlassCard(
        borderRadius: 14,
        elevation: 0,
        tone: PremiumGlassTone.subtle,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    visual.start,
                    colors?.surface ?? Colors.black,
                    0.42,
                  )!.withValues(alpha: 0.88),
                  Color.lerp(
                    visual.end,
                    colors?.elevatedSurface ?? Colors.black,
                    0.56,
                  )!.withValues(alpha: 0.86),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: visual.start.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: layout.isCompact ? 6 : 8,
                vertical: layout.isCompact ? 5 : 6,
              ),
              child: Row(
                children: [
                  Container(
                    width: layout.isCompact ? 20 : 22,
                    height: layout.isCompact ? 20 : 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: SvgPicture.asset(
                      visual.assetPath,
                      width: layout.isCompact ? 9 : 10,
                      height: layout.isCompact ? 9 : 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors?.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: layout.isCompact ? 10.6 : 11.3,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedExploreCategoryCard extends StatelessWidget {
  const _FeaturedExploreCategoryCard({
    required this.categoryKey,
    required this.title,
    required this.subtitle,
    required this.rankLabel,
    required this.onTap,
    this.width,
  });

  final String categoryKey;
  final String title;
  final String subtitle;
  final String rankLabel;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final visual = _categoryVisualFor(categoryKey);
    final tileWidth = width ?? 146.0;

    return ScaleTap(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.02,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    visual.surfaceColor(
                      colors?.surface ?? const Color(0xFF0D141C),
                    ),
                    (colors?.surface ?? const Color(0xFF0D141C)).withValues(
                      alpha: 0.9,
                    ),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: visual.start.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visual.start.withValues(alpha: 0.76),
                            visual.end.withValues(alpha: 0.46),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: -18,
                      bottom: -24,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.16,
                          child: SvgPicture.asset(
                            visual.assetPath,
                            width: 88,
                            height: 88,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _FeaturedCategoryBadge(
                        label: rankLabel,
                        color: colors?.textPrimary ?? Colors.white,
                      ),
                    ),
                    Positioned(
                      right: -8,
                      top: -10,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 26,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const SizedBox(width: 1, height: 1),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset(
                            visual.assetPath,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.34),
                            ],
                          ),
                        ),
                        child: const SizedBox(height: 56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: tileWidth,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors?.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15.2,
                height: 1.06,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: tileWidth,
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors?.textSecondary.withValues(alpha: 0.88),
                fontSize: 11.1,
                height: 1.16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCategoryBadge extends StatelessWidget {
  const _FeaturedCategoryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.22,
        ),
      ),
    );
  }
}

class _CategoryVisualSpec {
  const _CategoryVisualSpec({
    required this.assetPath,
    required this.start,
    required this.end,
  });

  final String assetPath;
  final Color start;
  final Color end;

  Color surfaceColor(Color fallback) {
    return Color.lerp(start, fallback, 0.46)!.withValues(alpha: 0.96);
  }
}

const _CategoryVisualSpec _kCategoryHeartSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/heart.svg',
  start: Color(0xFFC8746F),
  end: Color(0xFFE2A08E),
);

const _CategoryVisualSpec _kCategoryLeafSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/leaf.svg',
  start: Color(0xFF5E8B70),
  end: Color(0xFF9BC39F),
);

const _CategoryVisualSpec _kCategoryBookSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/book.svg',
  start: Color(0xFF6B79A6),
  end: Color(0xFFA7B6E0),
);

const _CategoryVisualSpec _kCategorySummitSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/summit.svg',
  start: Color(0xFFAD814A),
  end: Color(0xFFE4BF76),
);

const _CategoryVisualSpec _kCategoryPeopleSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/people.svg',
  start: Color(0xFF7B6A95),
  end: Color(0xFFB1A1D1),
);

const _CategoryVisualSpec _kCategoryScaleSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/scale.svg',
  start: Color(0xFF7C8698),
  end: Color(0xFFBAC4D7),
);

const _CategoryVisualSpec _kCategoryFilmSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/film.svg',
  start: Color(0xFF3D6D82),
  end: Color(0xFF70A9BF),
);

const _CategoryVisualSpec _kCategoryHourglassSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/hourglass.svg',
  start: Color(0xFF8C6A62),
  end: Color(0xFFC8A395),
);

const _CategoryVisualSpec _kCategorySparkSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/spark.svg',
  start: Color(0xFF9A7642),
  end: Color(0xFFE1C17E),
);

const _CategoryVisualSpec _kCategoryCompassSpec = _CategoryVisualSpec(
  assetPath: 'assets/categories/compass.svg',
  start: Color(0xFF4E7E84),
  end: Color(0xFF8BC2BC),
);

_CategoryVisualSpec _categoryVisualFor(String rawCategory) {
  final tag = rawCategory.trim().toLowerCase();
  if (tag.contains('love') ||
      tag.contains('romance') ||
      tag.contains('passion') ||
      tag.contains('desire') ||
      tag.contains('heart')) {
    return _kCategoryHeartSpec;
  }
  if (tag.contains('life') ||
      tag.contains('growth') ||
      tag.contains('nature') ||
      tag.contains('healing') ||
      tag.contains('peace')) {
    return _kCategoryLeafSpec;
  }
  if (tag.contains('wisdom') ||
      tag.contains('knowledge') ||
      tag.contains('truth') ||
      tag.contains('faith') ||
      tag.contains('beauty')) {
    return _kCategoryBookSpec;
  }
  if (tag.contains('success') ||
      tag.contains('strength') ||
      tag.contains('ambition') ||
      tag.contains('resilience') ||
      tag.contains('courage') ||
      tag.contains('leadership') ||
      tag.contains('discipline')) {
    return _kCategorySummitSpec;
  }
  if (tag.contains('friend') ||
      tag.contains('society') ||
      tag.contains('identity')) {
    return _kCategoryPeopleSpec;
  }
  if (tag.contains('justice') || tag.contains('freedom')) {
    return _kCategoryScaleSpec;
  }
  if (tag.contains('series') || tag.contains('movie')) {
    return _kCategoryFilmSpec;
  }
  if (tag.contains('time') ||
      tag.contains('death') ||
      tag.contains('loss') ||
      tag.contains('grief') ||
      tag.contains('mortality') ||
      tag.contains('regret')) {
    return _kCategoryHourglassSpec;
  }
  if (tag.contains('inspiration') ||
      tag.contains('motivation') ||
      tag.contains('hope') ||
      tag.contains('power') ||
      tag.contains('creativity') ||
      tag.contains('imagination')) {
    return _kCategorySparkSpec;
  }
  return _kCategoryCompassSpec;
}

String _categoryRouteTag(String raw) {
  return discoveryCategoryRouteTag(raw);
}

String _categoryLabel(String raw) {
  return discoveryCategoryLabel(raw);
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.query,
    required this.moods,
    required this.authors,
    required this.quotes,
    required this.onOpenMood,
    required this.onOpenAuthor,
    required this.onShowAllAuthors,
    required this.onShowAllQuotes,
    required this.onOpenQuote,
  });

  final String query;
  final List<String> moods;
  final List<AuthorCatalogEntry> authors;
  final List<QuoteModel> quotes;
  final ValueChanged<String> onOpenMood;
  final ValueChanged<AuthorCatalogEntry> onOpenAuthor;
  final VoidCallback onShowAllAuthors;
  final VoidCallback onShowAllQuotes;
  final ValueChanged<QuoteModel> onOpenQuote;

  @override
  Widget build(BuildContext context) {
    final layout = FlowLayoutInfo.of(context);
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    if (moods.isEmpty && authors.isEmpty && quotes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: FlowSpace.lg),
        child: Text(
          'No results for "$trimmedQuery".',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (moods.isNotEmpty) ...[
          const SizedBox(height: FlowSpace.md),
          const _SearchSectionHeader(title: 'Moods'),
          const SizedBox(height: FlowSpace.xs),
          SizedBox(
            height: layout.isCompact ? 48 : 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: moods.length,
              separatorBuilder: (_, _) => const SizedBox(width: FlowSpace.xs),
              itemBuilder: (context, index) => _ExploreMoodTile(
                moodKey: moods[index],
                title: _categoryLabel(moods[index]),
                width: layout.isCompact ? 112 : 124,
                onTap: () => onOpenMood(moods[index]),
              ),
            ),
          ),
        ],
        if (authors.isNotEmpty) ...[
          const SizedBox(height: FlowSpace.lg),
          _SearchSectionHeader(
            title: 'Authors',
            actionLabel: 'Show all',
            onActionTap: onShowAllAuthors,
          ),
          const SizedBox(height: FlowSpace.xs),
          Builder(
            builder: (context) {
              final cardWidth = layout.isCompact ? 146.0 : 164.0;
              final cardHeight = layout.isCompact ? 228.0 : 248.0;
              return SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: authors.take(10).length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: FlowSpace.sm),
                  itemBuilder: (context, index) {
                    final author = authors[index];
                    return SizedBox(
                      width: cardWidth,
                      child: PremiumAuthorDiscoveryCard(
                        authorName: author.authorName,
                        rank: index + 1,
                        quoteCount: author.quoteCount,
                        variant: PremiumAuthorDiscoveryCardVariant.rail,
                        animationIndex: index,
                        onTap: () => onOpenAuthor(author),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
        if (quotes.isNotEmpty) ...[
          const SizedBox(height: FlowSpace.lg),
          _SearchSectionHeader(
            title: 'Quotes',
            actionLabel: 'Show all',
            onActionTap: onShowAllQuotes,
          ),
          const SizedBox(height: FlowSpace.xs),
          for (final quote in quotes.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: FlowSpace.sm),
              child: _ExploreResultTile(
                quote: quote,
                onTap: () => onOpenQuote(quote),
              ),
            ),
        ],
      ],
    );
  }
}

class _RecentSearchesCard extends StatelessWidget {
  const _RecentSearchesCard({
    required this.searches,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> searches;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: FlowSpace.md),
        child: Text(
          'Start typing to search quotes, moods, and authors.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Padding(
      padding: const EdgeInsets.only(top: FlowSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.82),
                  letterSpacing: 0.18,
                ),
              ),
              const Spacer(),
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                child: TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FlowSpace.xs,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 26),
                  ),
                  onPressed: onClearAll,
                  child: const Text('Clear all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.xxs),
          for (final item in searches.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: ScaleTap(
                      onTap: () => onSelect(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      onPressed: () => onRemove(item),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color:
                            colors?.textSecondary.withValues(alpha: 0.74) ??
                            Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (actionLabel != null && onActionTap != null)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: FlowSpace.xs,
                vertical: 0,
              ),
              minimumSize: const Size(0, 26),
              foregroundColor: colors?.textSecondary,
            ),
            onPressed: onActionTap,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _ExploreLoader extends StatefulWidget {
  const _ExploreLoader();

  @override
  State<_ExploreLoader> createState() => _ExploreLoaderState();
}

class _ExploreLoaderState extends State<_ExploreLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      blurSigma: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeInOut,
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 30),
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(
            'Curating the bento board...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ExploreErrorCard extends StatelessWidget {
  const _ExploreErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      blurSigma: 18,
      child: Text(
        'Explore failed to load: $error',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ExploreResultTile extends StatelessWidget {
  const _ExploreResultTile({required this.quote, required this.onTap});

  final QuoteModel quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    return ScaleTap(
      onTap: onTap,
      child: PremiumSurface(
        radius: FlowRadii.lg,
        elevation: 1,
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.md,
          FlowSpace.sm,
          FlowSpace.sm,
          FlowSpace.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors?.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.accentSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FlowSpace.xs),
            Icon(Icons.north_east_rounded, color: colors?.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
