import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_collections/collections_ui/collection_chips_bar.dart';
import '../../features/v3_search/search_bar_widget.dart';
import '../../features/v3_search/search_providers.dart';
import '../../models/quote_model.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
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
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close_rounded,
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
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$savedCount saved',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(_sortLabel(sort)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: lengthFilter == _SavedLengthFilter.all,
                onSelected: (_) =>
                    onLengthFilterChanged(_SavedLengthFilter.all),
              ),
              ChoiceChip(
                label: const Text('Short'),
                selected: lengthFilter == _SavedLengthFilter.short,
                onSelected: (_) =>
                    onLengthFilterChanged(_SavedLengthFilter.short),
              ),
              ChoiceChip(
                label: const Text('Medium'),
                selected: lengthFilter == _SavedLengthFilter.medium,
                onSelected: (_) =>
                    onLengthFilterChanged(_SavedLengthFilter.medium),
              ),
              ChoiceChip(
                label: const Text('Long'),
                selected: lengthFilter == _SavedLengthFilter.long,
                onSelected: (_) =>
                    onLengthFilterChanged(_SavedLengthFilter.long),
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
    return ScaleTap(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quote.author,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
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

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
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
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) {
                        final quote = widget.quotes[index];
                        final isSaved = savedIds.contains(quote.id);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                          child: GlassCard(
                            borderRadius: 24,
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      quote.quote,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(height: 1.42),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  quote.author,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => ref
                                          .read(savedQuoteIdsProvider.notifier)
                                          .toggle(quote.id),
                                      icon: Icon(
                                        isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_outline_rounded,
                                      ),
                                      label: Text(isSaved ? 'Saved' : 'Save'),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: () => Share.share(
                                        '"${quote.quote}"\n\n- ${quote.author}',
                                        subject: 'Saved Quote',
                                      ),
                                      icon: const Icon(Icons.share_outlined),
                                      label: const Text('Share'),
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
        ],
      ),
    );
  }
}
