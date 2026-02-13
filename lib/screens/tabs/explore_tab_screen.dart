import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_search/search_service.dart';
import '../../providers/quote_providers.dart';
import '../../services/quote_service.dart';
import '../../widgets/editorial_background.dart';

class ExploreTabScreen extends ConsumerStatefulWidget {
  const ExploreTabScreen({super.key});

  @override
  ConsumerState<ExploreTabScreen> createState() => _ExploreTabScreenState();
}

class _ExploreTabScreenState extends ConsumerState<ExploreTabScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _lengthFilter;
  String? _tagFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(allQuotesProvider);
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final moodsAsync = ref.watch(moodCountsProvider);
    final service = ref.read(quoteServiceProvider);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: quotesAsync.when(
                data: (quotes) {
                  final searchService = SearchService(quotes);
                  final searchResults = _applyFilters(
                    searchService.searchQuotes(_query, limit: 100),
                  );
                  final random = Random(7);
                  final forYou = [...quotes]..shuffle(random);
                  final topTags = _topTags(
                    quotes,
                  ).take(8).toList(growable: false);

                  return ListView(
                    children: [
                      Text(
                        'Explore',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search quotes, author, tags',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any length'),
                            selected: _lengthFilter == null,
                            onSelected: (_) =>
                                setState(() => _lengthFilter = null),
                          ),
                          ChoiceChip(
                            label: const Text('Short'),
                            selected: _lengthFilter == 'short',
                            onSelected: (_) =>
                                setState(() => _lengthFilter = 'short'),
                          ),
                          ChoiceChip(
                            label: const Text('Medium'),
                            selected: _lengthFilter == 'medium',
                            onSelected: (_) =>
                                setState(() => _lengthFilter = 'medium'),
                          ),
                          ChoiceChip(
                            label: const Text('Long'),
                            selected: _lengthFilter == 'long',
                            onSelected: (_) =>
                                setState(() => _lengthFilter = 'long'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topTags.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return ChoiceChip(
                                label: const Text('All tags'),
                                selected: _tagFilter == null,
                                onSelected: (_) =>
                                    setState(() => _tagFilter = null),
                              );
                            }
                            final tag = topTags[index - 1];
                            return ChoiceChip(
                              label: Text(service.toTitleCase(tag)),
                              selected: _tagFilter == tag,
                              onSelected: (_) =>
                                  setState(() => _tagFilter = tag),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_query.isNotEmpty)
                        _SearchResultsSection(results: searchResults)
                      else ...[
                        _PreviewSection(
                          title: 'For You',
                          items: forYou.take(12).toList(growable: false),
                        ),
                        const SizedBox(height: 14),
                        categoriesAsync.when(
                          data: (cats) {
                            final tags = <String>['all', ...cats.keys.take(11)];
                            return _TagSection(
                              title: 'Categories',
                              tags: tags,
                              display: service,
                              onTap: (tag) {
                                if (tag == 'all') {
                                  context.push('/viewer/category/all');
                                  return;
                                }
                                context.push(
                                  '/viewer/category/${Uri.encodeComponent(tag)}',
                                );
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 14),
                        moodsAsync.when(
                          data: (moods) {
                            final tags = moods.keys.take(12).toList();
                            return _TagSection(
                              title: 'Moods',
                              tags: tags,
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
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('Failed to load: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyFilters(List<dynamic> input) {
    return input
        .where((quote) {
          if (_lengthFilter != null) {
            final words = quote.quote
                .split(RegExp(r'\\s+'))
                .where((w) => w.trim().isNotEmpty)
                .length;
            final ok = switch (_lengthFilter) {
              'short' => words <= 12,
              'medium' => words > 12 && words <= 24,
              'long' => words > 24,
              _ => true,
            };
            if (!ok) return false;
          }
          if (_tagFilter != null && !quote.revisedTags.contains(_tagFilter)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<String> _topTags(List<dynamic> quotes) {
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
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({required this.results});

  final List<dynamic> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Text('No search results'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Results'),
        const SizedBox(height: 8),
        for (final quote in results.take(12))
          Card(
            child: ListTile(
              title: Text(
                quote.quote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(quote.author),
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
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final quote = items[index];
              return SizedBox(
                width: 230,
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(
                      '/viewer?type=explore&tag=&quoteId=${quote.id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              quote.quote,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            quote.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
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

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    required this.tags,
    required this.display,
    required this.onTap,
  });

  final String title;
  final List<String> tags;
  final QuoteService display;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ActionChip(
                label: Text(tag == 'all' ? 'All' : display.toTitleCase(tag)),
                onPressed: () => onTap(tag),
              );
            },
          ),
        ),
      ],
    );
  }
}
