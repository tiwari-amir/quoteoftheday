import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_search/search_service.dart';
import '../../core/constants.dart';
import '../../models/quote_model.dart';
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
                            final tags = <String>['all', ...cats.keys.take(18)];
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

  List<QuoteModel> _applyFilters(List<QuoteModel> input) {
    return input
        .where((quote) {
          if (_lengthFilter != null) {
            final words = quote.quote
                .split(RegExp(r'\s+'))
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
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({required this.results});

  final List<QuoteModel> results;

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
  final List<QuoteModel> items;

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              _FlowPillChip(
                label: tag == 'all' ? 'All' : display.toTitleCase(tag),
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
        Text('Moods', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in visibleMoods)
              _FlowPillChip(
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

class _FlowPillChip extends StatelessWidget {
  const _FlowPillChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF173229).withValues(alpha: 0.82),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
