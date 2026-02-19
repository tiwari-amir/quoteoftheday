import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/scale_tap.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToLetter({
    required String letter,
    required List<_TagCount> items,
    required double availableWidth,
  }) {
    if (!_scrollController.hasClients) return;

    final index = items.indexWhere((item) => item.label.startsWith(letter));
    if (index < 0) return;

    const crossAxisCount = 2;
    const spacing = 14.0;
    const sideBarWidth = 28.0;
    final gridWidth = math.max(140.0, availableWidth - sideBarWidth - 14);
    final tileWidth = (gridWidth - spacing) / crossAxisCount;
    final tileHeight = tileWidth / 1.08;
    final row = index ~/ crossAxisCount;
    final offset = row * (tileHeight + spacing);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final topLikedAsync = ref.watch(topLikedQuotesProvider);
    final service = ref.read(quoteServiceProvider);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
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
                        'Browse by Category',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    borderRadius: 18,
                    blur: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        hintText: 'Search categories',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: categoriesAsync.when(
                      data: (categories) {
                        final all =
                            categories.entries
                                .map(
                                  (entry) => _TagCount(
                                    tag: entry.key,
                                    label: service.toTitleCase(entry.key),
                                    count: entry.value,
                                  ),
                                )
                                .toList()
                              ..sort((a, b) => a.label.compareTo(b.label));

                        final filtered = all
                            .where(
                              (item) =>
                                  item.label.toLowerCase().contains(_query),
                            )
                            .toList(growable: false);

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text('No categories found'),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
                              children: [
                                Expanded(
                                  child: CustomScrollView(
                                    controller: _scrollController,
                                    slivers: [
                                      SliverGrid(
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          final item = filtered[index];
                                          return ScaleTap(
                                                onTap: () => context.push(
                                                  '/viewer/category/${Uri.encodeComponent(item.tag)}',
                                                ),
                                                child: _CategoryCard(
                                                  item: item,
                                                ),
                                              )
                                              .animate(delay: (index * 24).ms)
                                              .fadeIn(duration: 260.ms)
                                              .slideY(begin: 0.08, end: 0);
                                        }, childCount: filtered.length),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 14,
                                              mainAxisSpacing: 14,
                                              childAspectRatio: 1.08,
                                            ),
                                      ),
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 22,
                                            bottom: 4,
                                          ),
                                          child: _MostLikedSection(
                                            quotesAsync: topLikedAsync,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _LetterQuickBar(
                                  onLetterTap: (letter) => _jumpToLetter(
                                    letter: letter,
                                    items: filtered,
                                    availableWidth: constraints.maxWidth,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Failed to load: $error')),
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

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.item});

  final _TagCount item;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderIdle = Colors.white.withValues(alpha: 0.16);
    final borderHover = scheme.primary.withValues(alpha: 0.7);
    final glow = scheme.primary.withValues(alpha: 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.surface.withValues(alpha: 0.5),
          border: Border.all(color: _hovering ? borderHover : borderIdle),
          boxShadow: [
            BoxShadow(
              color: _hovering ? glow : Colors.black.withValues(alpha: 0.25),
              blurRadius: _hovering ? 22 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.label,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${widget.item.count} quotes',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterQuickBar extends StatelessWidget {
  const _LetterQuickBar({required this.onLetterTap});

  final ValueChanged<String> onLetterTap;

  static const List<String> _letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 16,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final letter in _letters)
            ScaleTap(
              onTap: () => onLetterTap(letter),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  letter,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagCount {
  const _TagCount({
    required this.tag,
    required this.label,
    required this.count,
  });

  final String tag;
  final String label;
  final int count;
}

class _MostLikedSection extends StatelessWidget {
  const _MostLikedSection({required this.quotesAsync});

  final AsyncValue<List<QuoteModel>> quotesAsync;

  @override
  Widget build(BuildContext context) {
    return quotesAsync.when(
      data: (quotes) {
        if (quotes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most liked', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quotes.length.clamp(0, 10).toInt(),
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  return SizedBox(
                    width: 238,
                    child: GlassCard(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      borderRadius: 16,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(
                          '/viewer?type=explore&tag=&quoteId=${quote.id}',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.quote,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
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
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
