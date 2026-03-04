import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../features/v3_search/search_service.dart';
import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/storage_provider.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';

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
  String? _lengthFilter;
  String? _tagFilter;
  SearchService? _searchService;
  String _quotesSignature = '';
  List<QuoteModel> _forYouCache = const <QuoteModel>[];
  List<String> _topTagsCache = const <String>[];
  bool _showMostLikedSection = false;
  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (!_searchFocusNode.hasFocus) {
        unawaited(_pushRecentSearch(_controller.text));
      }
      setState(() {});
    });
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showMostLikedSection = true);
    });
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
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final moodsAsync = ref.watch(moodCountsProvider);
    final service = ref.read(quoteServiceProvider);
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.md,
                FlowSpace.lg,
                FlowSpace.md,
              ),
              child: quotesAsync.when(
                data: (quotes) {
                  _ensureExploreCaches(quotes);
                  final searchService = _searchService!;
                  final searchResults = _query.isEmpty
                      ? const <QuoteModel>[]
                      : searchService.searchQuotes(
                          _query,
                          lengthFilter: _lengthFilter,
                          tagFilter: _tagFilter,
                          limit: 100,
                        );
                  final topTags = categoriesAsync.maybeWhen(
                    data: (cats) =>
                        _topCategoryPreviewTags(cats.keys, limit: 8),
                    orElse: () => _topTagsCache.take(8).toList(growable: false),
                  );
                  final showRecentSearches =
                      _searchFocusNode.hasFocus &&
                      _query.isEmpty &&
                      _recentSearches.isNotEmpty;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SectionHeader(
                        title: 'Explore',
                        subtitle:
                            'Curated categories, moods, and timeless favorites.',
                      ).animate().fadeIn(duration: FlowDurations.regular),
                      const SizedBox(height: FlowSpace.md),
                      _ExploreSearchBar(
                        controller: _controller,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) =>
                            unawaited(_onSearchSubmitted(value)),
                        onClear: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ).animate().fadeIn(duration: FlowDurations.regular),
                      if (showRecentSearches) ...[
                        const SizedBox(height: FlowSpace.sm),
                        PremiumSurface(
                          radius: FlowRadii.lg,
                          elevation: 1,
                          padding: const EdgeInsets.fromLTRB(
                            FlowSpace.sm,
                            FlowSpace.xs,
                            FlowSpace.sm,
                            FlowSpace.xs,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Recent searches',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        unawaited(_clearRecentSearches()),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Clear all'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: FlowSpace.xs),
                              for (final item in _recentSearches)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: FlowSpace.xxs,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: FlowRadii.radiusMd,
                                      onTap: () =>
                                          unawaited(_selectRecentSearch(item)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: FlowSpace.xs,
                                          vertical: FlowSpace.xs,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.history_rounded,
                                              size: 17,
                                            ),
                                            const SizedBox(width: FlowSpace.xs),
                                            Expanded(
                                              child: Text(
                                                item,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              splashRadius: 16,
                                              onPressed: () => unawaited(
                                                _removeRecentSearch(item),
                                              ),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 17,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: FlowSpace.sm),
                      Wrap(
                        spacing: FlowSpace.xs,
                        runSpacing: FlowSpace.xs,
                        children: [
                          PremiumPillChip(
                            label: 'Any length',
                            selected: _lengthFilter == null,
                            onTap: () => setState(() => _lengthFilter = null),
                          ),
                          PremiumPillChip(
                            label: 'Short',
                            selected: _lengthFilter == 'short',
                            onTap: () =>
                                setState(() => _lengthFilter = 'short'),
                          ),
                          PremiumPillChip(
                            label: 'Medium',
                            selected: _lengthFilter == 'medium',
                            onTap: () =>
                                setState(() => _lengthFilter = 'medium'),
                          ),
                          PremiumPillChip(
                            label: 'Long',
                            selected: _lengthFilter == 'long',
                            onTap: () => setState(() => _lengthFilter = 'long'),
                          ),
                        ],
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: topTags.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: FlowSpace.xs),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return PremiumPillChip(
                                label: 'All tags',
                                selected: _tagFilter == null,
                                onTap: () => setState(() => _tagFilter = null),
                              );
                            }
                            final tag = topTags[index - 1];
                            return PremiumPillChip(
                              label: _displayTag(tag, service),
                              selected: _tagFilter == tag,
                              onTap: () => setState(() => _tagFilter = tag),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: FlowSpace.lg),
                      if (_query.isNotEmpty)
                        _SearchResultsSection(results: searchResults)
                      else ...[
                        _PreviewSection(title: 'For You', items: _forYouCache),
                        const SizedBox(height: FlowSpace.xl),
                        if (_showMostLikedSection)
                          const _ExploreMostLikedSection(),
                        const SizedBox(height: FlowSpace.xl),
                        categoriesAsync.when(
                          data: (cats) {
                            final tags = _categoryPreviewTags(cats.keys);
                            return _TagSection(
                              title: 'Categories',
                              subtitle: 'Browse by focus and topic',
                              tags: tags,
                              display: service,
                              onSeeMore: () => context.push('/categories'),
                              onTap: (tag) {
                                if (tag == 'all') {
                                  context.push('/viewer/category/all');
                                  return;
                                }
                                final routeTag = tag == 'series'
                                    ? 'movies/series'
                                    : tag;
                                context.push(
                                  '/viewer/category/${Uri.encodeComponent(routeTag)}',
                                );
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: FlowSpace.xl),
                        moodsAsync.when(
                          data: (moods) {
                            final moodTags = _pickExploreMoods(moods);
                            return _MoodGridSection(
                              moods: moodTags,
                              display: service,
                              onTap: (tag) => context.push(
                                '/viewer/mood/${Uri.encodeComponent(tag)}',
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                      ],
                      SizedBox(height: FlowSpace.sm + (colors == null ? 0 : 0)),
                    ],
                  );
                },
                loading: () => const Center(child: _ExploreLoader()),
                error: (error, stack) =>
                    Center(child: Text('Failed to load: $error')),
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
    _forYouCache = _sampleForYou(quotes, count: 12);
    _topTagsCache = _topTags(quotes).take(8).toList(growable: false);
  }

  String _quotesSignatureFor(List<QuoteModel> quotes) {
    if (quotes.isEmpty) return '0';
    return '${quotes.length}:${quotes.first.id}:${quotes.last.id}';
  }

  List<QuoteModel> _sampleForYou(
    List<QuoteModel> quotes, {
    required int count,
  }) {
    if (quotes.length <= count) {
      return List<QuoteModel>.from(quotes, growable: false);
    }

    final random = Random(7);
    final used = <int>{};
    final picked = <QuoteModel>[];

    while (picked.length < count && used.length < quotes.length) {
      final index = random.nextInt(quotes.length);
      if (!used.add(index)) continue;
      picked.add(quotes[index]);
    }

    return picked;
  }

  List<String> _topTags(List<QuoteModel> quotes) {
    final counts = <String, int>{};
    for (final quote in quotes) {
      for (final tag in quote.revisedTags) {
        counts.update(tag, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList(growable: false);
  }

  List<String> _topCategoryPreviewTags(
    Iterable<String> rawTags, {
    required int limit,
  }) {
    final ordered = rawTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty && tag != 'all')
        .toList(growable: true);
    final preview = ordered.take(limit).toList(growable: true);
    for (final requiredTag in const ['movies', 'series']) {
      if (preview.contains(requiredTag)) continue;
      if (preview.length >= limit) {
        preview.removeLast();
      }
      preview.add(requiredTag);
    }
    return preview;
  }

  List<String> _categoryPreviewTags(Iterable<String> rawTags) {
    final top = _topCategoryPreviewTags(rawTags, limit: 20);
    return <String>['all', ...top];
  }

  List<String> _pickExploreMoods(Map<String, int> moodCounts) {
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final picked = <String>[];

    for (final entry in sortedMoods) {
      if (picked.length == 6) break;
      picked.add(entry.key);
    }

    if (picked.length < 6) {
      for (final fallback in moodAllowlist) {
        if (picked.length == 6) break;
        if (!picked.contains(fallback)) picked.add(fallback);
      }
    }

    return picked.take(6).toList(growable: false);
  }

  String _displayTag(String tag, QuoteService service) {
    if (tag.trim().toLowerCase() == 'series') {
      return 'Movies/Series';
    }
    return service.toTitleCase(tag);
  }
}

class _ExploreSearchBar extends StatelessWidget {
  const _ExploreSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final focused = focusNode.hasFocus;

    return Container(
      decoration: BoxDecoration(
        borderRadius: FlowRadii.radiusXl,
        boxShadow: [
          BoxShadow(
            color: (colors?.accent ?? Colors.white).withValues(
              alpha: focused ? 0.22 : 0.12,
            ),
            blurRadius: focused ? 30 : 22,
            spreadRadius: focused ? 1 : 0,
          ),
          ...?flow?.shadows.level1,
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: FlowRadii.radiusXl,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.9),
              (colors?.surface ?? Colors.black).withValues(alpha: 0.82),
            ],
          ),
          border: Border.all(
            color:
                (focused
                    ? colors?.accent.withValues(alpha: 0.65)
                    : colors?.divider.withValues(alpha: 0.82)) ??
                Colors.white24,
            width: focused ? 1.15 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.sm,
            FlowSpace.xs,
            FlowSpace.xs,
            FlowSpace.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (colors?.accent ?? Colors.white).withValues(
                    alpha: 0.15,
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: colors?.textPrimary.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search quotes, author, tags',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.88),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: controller.text.isEmpty ? 0 : 1,
                duration: FlowDurations.quick,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                  onPressed: controller.text.isEmpty ? null : onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({required this.results});

  final List<QuoteModel> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: FlowSpace.lg),
        child: Text('No search results'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Results'),
        const SizedBox(height: FlowSpace.sm),
        for (final quote in results.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: FlowSpace.sm),
            child: _ExploreResultTile(
              quote: quote,
              onTap: () =>
                  context.push('/viewer?type=explore&tag=&quoteId=${quote.id}'),
            ),
          ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.items});

  final String title;
  final List<QuoteModel> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: FlowSpace.sm),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: FlowSpace.sm),
            itemBuilder: (context, index) {
              final quote = items[index];
              return SizedBox(
                width: 264,
                child: _ExploreQuotePreviewCard(
                  quote: quote,
                  onTap: () => context.push(
                    '/viewer?type=explore&tag=&quoteId=${quote.id}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExploreMostLikedSection extends ConsumerWidget {
  const _ExploreMostLikedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topLikedAsync = ref.watch(topLikedQuotesProvider);
    return topLikedAsync.when(
      data: (likedQuotes) => _PreviewSection(
        title: 'Most liked',
        items: likedQuotes.take(12).toList(growable: false),
      ),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          child: const Icon(Icons.auto_awesome_rounded, size: 30),
        ),
        const SizedBox(height: FlowSpace.sm),
        Text(
          'Curating quotes...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    this.subtitle,
    required this.tags,
    required this.display,
    required this.onTap,
    required this.onSeeMore,
  });

  final String title;
  final String? subtitle;
  final List<String> tags;
  final QuoteService display;
  final ValueChanged<String> onTap;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: TextButton(
            onPressed: onSeeMore,
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: FlowSpace.sm),
        Wrap(
          spacing: FlowSpace.xs,
          runSpacing: FlowSpace.xs,
          children: [
            for (final tag in tags)
              PremiumPillChip(
                label: tag == 'all'
                    ? 'All'
                    : tag == 'series'
                    ? 'Movies/Series'
                    : display.toTitleCase(tag),
                onTap: () => onTap(tag),
              ),
          ],
        ),
      ],
    );
  }
}

class _MoodGridSection extends StatelessWidget {
  const _MoodGridSection({
    required this.moods,
    required this.display,
    required this.onTap,
  });

  final List<String> moods;
  final QuoteService display;
  final ValueChanged<String> onTap;

  static const Map<String, IconData> _moodIcons = {
    'happy': Icons.sentiment_very_satisfied_rounded,
    'calm': Icons.spa_rounded,
    'motivated': Icons.bolt_rounded,
    'confident': Icons.self_improvement_rounded,
    'grateful': Icons.volunteer_activism_rounded,
    'hopeful': Icons.wb_sunny_rounded,
    'sad': Icons.sentiment_dissatisfied_rounded,
    'anxious': Icons.psychology_alt_rounded,
    'romantic': Icons.favorite_rounded,
    'stressed': Icons.air_rounded,
    'lonely': Icons.person_outline_rounded,
    'angry': Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final visibleMoods = moods.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Moods'),
        const SizedBox(height: FlowSpace.sm),
        Wrap(
          spacing: FlowSpace.xs,
          runSpacing: FlowSpace.xs,
          children: [
            for (final tag in visibleMoods)
              PremiumPillChip(
                label: display.toTitleCase(tag),
                icon: _moodIcons[tag] ?? Icons.mood_rounded,
                onTap: () => onTap(tag),
              ),
          ],
        ),
      ],
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
    return PremiumSurface(
      radius: FlowRadii.lg,
      elevation: 1,
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.sm,
        FlowSpace.sm,
        FlowSpace.sm,
      ),
      child: InkWell(
        borderRadius: FlowRadii.radiusLg,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _ExploreQuotePreviewCard extends StatelessWidget {
  const _ExploreQuotePreviewCard({required this.quote, required this.onTap});

  final QuoteModel quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return PremiumSurface(
      radius: FlowRadii.lg,
      elevation: 2,
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.sm,
      ),
      child: InkWell(
        borderRadius: FlowRadii.radiusLg,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 20,
              color: colors?.accent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: FlowSpace.xs),
            Expanded(
              child: Text(
                quote.quote,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors?.textPrimary,
                  height: 1.36,
                ),
              ),
            ),
            const SizedBox(height: FlowSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: colors?.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
