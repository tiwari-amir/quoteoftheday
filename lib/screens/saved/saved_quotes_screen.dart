import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_collections/collections_ui/collection_chips_bar.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../features/v3_search/search_bar_widget.dart';
import '../../features/v3_search/search_providers.dart';
import '../../models/quote_model.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/author_portrait_circle.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/scale_tap.dart';

enum _SavedLengthFilter { all, short, medium, long }

enum _SavedSort { authorAz, authorZa, shortestFirst, longestFirst, quoteAz }

class SavedQuotesScreen extends ConsumerStatefulWidget {
  const SavedQuotesScreen({super.key});

  @override
  ConsumerState<SavedQuotesScreen> createState() => _SavedQuotesScreenState();
}

class _SavedQuotesScreenState extends ConsumerState<SavedQuotesScreen> {
  final ScrollController _scrollController = ScrollController();
  _SavedLengthFilter _lengthFilter = _SavedLengthFilter.all;
  _SavedSort _sort = _SavedSort.authorAz;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final collections = ref.watch(collectionsProvider);
    final collectionsNotifier = ref.read(collectionsProvider.notifier);
    final layout = FlowLayoutInfo.of(context);

    final selectedCollectionId = collections.selectedCollectionId;
    final scopedIds = selectedCollectionId == allSavedCollectionId
        ? savedIds
        : savedIds.intersection(
            collectionsNotifier
                .quoteIdsForCollection(selectedCollectionId)
                .toSet(),
          );

    final searchAsync = ref.watch(searchResultsProvider(scopedIds));

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding + 2,
                    layout.horizontalPadding,
                    layout.isCompact ? FlowSpace.md : FlowSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PremiumIconPillButton(
                            icon: Icons.arrow_back_rounded,
                            compact: true,
                            onTap: context.pop,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Saved',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const CollectionChipsBar(),
                      const SizedBox(height: 10),
                      const V3SearchBarWidget(),
                      const SizedBox(height: 10),
                      _SavedControls(
                        lengthFilter: _lengthFilter,
                        sort: _sort,
                        onLengthFilterChanged: (value) {
                          setState(() => _lengthFilter = value);
                        },
                        onSortChanged: (value) {
                          setState(() => _sort = value);
                        },
                        savedCount: scopedIds.length,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: searchAsync.when(
                          data: (searchResults) {
                            final base = searchResults
                                .where((q) => scopedIds.contains(q.id))
                                .toList(growable: false);
                            final finalQuotes = _applySortAndFilters(base);

                            if (finalQuotes.isEmpty) {
                              return Center(
                                child: Text(
                                  'No saved quotes found',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              );
                            }

                            return Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: ListView.separated(
                                controller: _scrollController,
                                itemCount: finalQuotes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final quote = finalQuotes[index];
                                  return _SavedCard(
                                    quote: quote,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => _SavedQuotePagerScreen(
                                          quotes: finalQuotes,
                                          initialIndex: index,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stack) =>
                              Center(child: Text('Search failed: $error')),
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
    );
  }

  List<QuoteModel> _applySortAndFilters(List<QuoteModel> input) {
    final filtered = input.where((quote) {
      final words = _wordCount(quote.quote);
      return switch (_lengthFilter) {
        _SavedLengthFilter.all => true,
        _SavedLengthFilter.short => words <= 12,
        _SavedLengthFilter.medium => words > 12 && words <= 24,
        _SavedLengthFilter.long => words > 24,
      };
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _SavedSort.authorAz => a.author.toLowerCase().compareTo(
          b.author.toLowerCase(),
        ),
        _SavedSort.authorZa => b.author.toLowerCase().compareTo(
          a.author.toLowerCase(),
        ),
        _SavedSort.shortestFirst => _wordCount(
          a.quote,
        ).compareTo(_wordCount(b.quote)),
        _SavedSort.longestFirst => _wordCount(
          b.quote,
        ).compareTo(_wordCount(a.quote)),
        _SavedSort.quoteAz => a.quote.toLowerCase().compareTo(
          b.quote.toLowerCase(),
        ),
      };
    });

    return filtered;
  }

  int _wordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;
  }
}

class _SavedControls extends StatelessWidget {
  const _SavedControls({
    required this.lengthFilter,
    required this.sort,
    required this.onLengthFilterChanged,
    required this.onSortChanged,
    required this.savedCount,
  });

  final _SavedLengthFilter lengthFilter;
  final _SavedSort sort;
  final ValueChanged<_SavedLengthFilter> onLengthFilterChanged;
  final ValueChanged<_SavedSort> onSortChanged;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      radius: FlowRadii.lg,
      elevation: 1,
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.sm,
        FlowSpace.md,
        FlowSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$savedCount saved',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              PopupMenuButton<_SavedSort>(
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _SavedSort.authorAz,
                    child: Text('Author A-Z'),
                  ),
                  PopupMenuItem(
                    value: _SavedSort.authorZa,
                    child: Text('Author Z-A'),
                  ),
                  PopupMenuItem(
                    value: _SavedSort.shortestFirst,
                    child: Text('Shortest first'),
                  ),
                  PopupMenuItem(
                    value: _SavedSort.longestFirst,
                    child: Text('Longest first'),
                  ),
                  PopupMenuItem(
                    value: _SavedSort.quoteAz,
                    child: Text('Quote A-Z'),
                  ),
                ],
                child: PremiumPillChip(
                  label: _sortLabel(sort),
                  icon: Icons.swap_vert_rounded,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.xs),
          Wrap(
            spacing: FlowSpace.xs,
            runSpacing: FlowSpace.xs,
            children: [
              PremiumPillChip(
                label: 'All',
                compact: true,
                selected: lengthFilter == _SavedLengthFilter.all,
                onTap: () => onLengthFilterChanged(_SavedLengthFilter.all),
              ),
              PremiumPillChip(
                label: 'Short',
                compact: true,
                selected: lengthFilter == _SavedLengthFilter.short,
                onTap: () => onLengthFilterChanged(_SavedLengthFilter.short),
              ),
              PremiumPillChip(
                label: 'Medium',
                compact: true,
                selected: lengthFilter == _SavedLengthFilter.medium,
                onTap: () => onLengthFilterChanged(_SavedLengthFilter.medium),
              ),
              PremiumPillChip(
                label: 'Long',
                compact: true,
                selected: lengthFilter == _SavedLengthFilter.long,
                onTap: () => onLengthFilterChanged(_SavedLengthFilter.long),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(_SavedSort sort) {
    return switch (sort) {
      _SavedSort.authorAz => 'Author A-Z',
      _SavedSort.authorZa => 'Author Z-A',
      _SavedSort.shortestFirst => 'Shortest first',
      _SavedSort.longestFirst => 'Longest first',
      _SavedSort.quoteAz => 'Quote A-Z',
    };
  }
}

class _SavedCard extends ConsumerWidget {
  const _SavedCard({required this.quote, required this.onTap});

  final QuoteModel quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    return ScaleTap(
      onTap: onTap,
      child: PremiumSurface(
        radius: FlowRadii.lg,
        elevation: 1,
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.md,
          FlowSpace.sm,
          FlowSpace.xs,
          FlowSpace.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorPortraitCircle(author: quote.author, size: 54),
            const SizedBox(width: FlowSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: FlowTypography.quoteStyle(
                      context: context,
                      color: colors?.textPrimary ?? Colors.white,
                      fontSize: 16.5,
                    ).copyWith(height: 1.34),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colors?.textSecondary),
              onSelected: (value) {
                if (value == 'remove') {
                  ref.read(savedQuoteIdsProvider.notifier).remove(quote.id);
                  return;
                }
                if (value == 'collections') {
                  showAddToCollectionSheet(context, ref, quote.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'collections',
                  child: Text('Add to collection'),
                ),
                PopupMenuItem(value: 'remove', child: Text('Remove saved')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedQuotePagerScreen extends ConsumerStatefulWidget {
  const _SavedQuotePagerScreen({
    required this.quotes,
    required this.initialIndex,
  });

  final List<QuoteModel> quotes;
  final int initialIndex;

  @override
  ConsumerState<_SavedQuotePagerScreen> createState() =>
      _SavedQuotePagerScreenState();
}

class _SavedQuotePagerScreenState
    extends ConsumerState<_SavedQuotePagerScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.quotes.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.textColumnWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding + 4,
                    layout.horizontalPadding,
                    FlowSpace.md,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          PremiumIconPillButton(
                            icon: Icons.arrow_back_rounded,
                            compact: true,
                            onTap: context.pop,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_index + 1} / ${widget.quotes.length}',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 46),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          itemCount: widget.quotes.length,
                          onPageChanged: (index) =>
                              setState(() => _index = index),
                          itemBuilder: (context, index) {
                            final quote = widget.quotes[index];
                            final isSaved = savedIds.contains(quote.id);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                              child: PremiumSurface(
                                radius: FlowRadii.xl,
                                elevation: 2,
                                padding: const EdgeInsets.fromLTRB(
                                  FlowSpace.lg,
                                  FlowSpace.lg,
                                  FlowSpace.lg,
                                  FlowSpace.md,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          quote.quote,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(height: 1.3),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: FlowSpace.md),
                                    Text(
                                      '- ${quote.author}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .extension<FlowThemeTokens>()
                                                ?.colors
                                                .accent,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: FlowSpace.md),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        PremiumIconPillButton(
                                          onTap: () => ref
                                              .read(
                                                savedQuoteIdsProvider.notifier,
                                              )
                                              .toggle(quote.id),
                                          icon: isSaved
                                              ? Icons.bookmark
                                              : Icons.bookmark_outline_rounded,
                                          label: isSaved ? 'Saved' : 'Save',
                                          active: isSaved,
                                        ),
                                        const SizedBox(width: FlowSpace.sm),
                                        PremiumIconPillButton(
                                          onTap: () => showStoryShareSheet(
                                            context: context,
                                            quote: quote,
                                            subject: 'Saved Quote',
                                          ),
                                          icon: Icons.share_outlined,
                                          label: 'Share',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
    );
  }
}
