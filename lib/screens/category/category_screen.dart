import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../services/quote_service.dart';
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
  bool _showMostLikedSection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showMostLikedSection = true);
    });
  }

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

    final normalized = letter.trim().toUpperCase();
    final index = items.indexWhere((item) {
      final label = item.label.trim();
      if (label.isEmpty) return false;
      return label[0].toUpperCase() == normalized;
    });
    if (index < 0) return;

    const crossAxisCount = 2;
    const spacing = 14.0;
    const sideBarWidth = 30.0;
    final gridWidth = math.max(140.0, availableWidth - sideBarWidth - 14);
    final tileWidth = (gridWidth - spacing) / crossAxisCount;
    final tileHeight = tileWidth / 1.08;
    final row = index ~/ crossAxisCount;
    final targetOffset = row * (tileHeight + spacing);
    final maxOffset = _scrollController.position.maxScrollExtent;
    final offset = targetOffset.clamp(0.0, maxOffset);
    final distance = (offset - _scrollController.offset).abs();

    if (distance > 620) {
      _scrollController.jumpTo(offset);
      return;
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCountsProvider);
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
                      )
                      .animate()
                      .fadeIn(duration: 260.ms)
                      .slideY(
                        begin: -0.05,
                        end: 0,
                        duration: 320.ms,
                        curve: Curves.easeOutCubic,
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
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search_rounded),
                            border: InputBorder.none,
                            hintText: 'Search categories',
                          ),
                        ),
                      )
                      .animate(delay: 70.ms)
                      .fadeIn(duration: 260.ms)
                      .slideY(
                        begin: 0.04,
                        end: 0,
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
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
                                    label: _categoryLabel(entry.key, service),
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
                        final quickLetters = _buildQuickLetters(filtered);

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
                                        physics: const BouncingScrollPhysics(),
                                        slivers: [
                                          SliverGrid(
                                            delegate: SliverChildBuilderDelegate((
                                              context,
                                              index,
                                            ) {
                                              final item = filtered[index];
                                              final routeTag =
                                                  item.tag == 'series'
                                                  ? 'movies/series'
                                                  : item.tag;
                                              return ScaleTap(
                                                onTap: () => context.push(
                                                  '/viewer/category/${Uri.encodeComponent(routeTag)}',
                                                ),
                                                child: _CategoryCard(
                                                  item: item,
                                                ),
                                              );
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
                                              child: _showMostLikedSection
                                                  ? const _MostLikedSection()
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _LetterQuickBar(
                                      letters: quickLetters,
                                      onLetterTap: (letter) => _jumpToLetter(
                                        letter: letter,
                                        items: filtered,
                                        availableWidth: constraints.maxWidth,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                            .animate(delay: 120.ms)
                            .fadeIn(duration: 280.ms)
                            .slideY(
                              begin: 0.03,
                              end: 0,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
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

  String _categoryLabel(String rawTag, QuoteService service) {
    final tag = rawTag.trim().toLowerCase();
    if (tag == 'series') return 'Movies/Series';
    return service.toTitleCase(tag);
  }

  List<String> _buildQuickLetters(List<_TagCount> items) {
    final letters = <String>{};
    for (final item in items) {
      final normalized = item.label.trim();
      if (normalized.isEmpty) continue;
      final first = normalized[0].toUpperCase();
      if (RegExp(r'^[A-Z]$').hasMatch(first)) {
        letters.add(first);
      }
    }
    final sorted = letters.toList(growable: false)..sort();
    return sorted;
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
    final cardScale = _hovering ? 1.01 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: cardScale,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface.withValues(alpha: _hovering ? 0.86 : 0.8),
                scheme.surface.withValues(alpha: _hovering ? 0.68 : 0.6),
              ],
            ),
            border: Border.all(color: _hovering ? borderHover : borderIdle),
            boxShadow: [
              BoxShadow(
                color: _hovering ? glow : Colors.black.withValues(alpha: 0.25),
                blurRadius: _hovering ? 24 : 14,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${widget.item.count} quotes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: scheme.primary.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterQuickBar extends StatefulWidget {
  const _LetterQuickBar({required this.letters, required this.onLetterTap});

  final List<String> letters;
  final ValueChanged<String> onLetterTap;

  @override
  State<_LetterQuickBar> createState() => _LetterQuickBarState();
}

class _LetterQuickBarState extends State<_LetterQuickBar> {
  String? _focusedLetter;
  String? _lastDispatched;

  void _dispatchLetterAtY(BoxConstraints constraints, double y) {
    final safeHeight = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
    final clampedY = y.clamp(0.0, safeHeight - 0.001);
    final itemHeight = safeHeight / widget.letters.length;
    var index = (clampedY / itemHeight).floor();
    if (index < 0) index = 0;
    if (index >= widget.letters.length) index = widget.letters.length - 1;

    final selected = widget.letters[index];
    if (selected != _lastDispatched) {
      _lastDispatched = selected;
      HapticFeedback.selectionClick();
      widget.onLetterTap(selected);
    }

    if (!mounted) return;
    setState(() {
      _focusedLetter = selected;
    });
  }

  void _endInteraction() {
    if (!mounted) return;
    setState(() {
      _lastDispatched = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.letters.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.surface.withValues(alpha: 0.36),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _dispatchLetterAtY(constraints, details.localPosition.dy),
              onTapUp: (_) => _endInteraction(),
              onTapCancel: _endInteraction,
              onLongPressStart: (details) =>
                  _dispatchLetterAtY(constraints, details.localPosition.dy),
              onLongPressMoveUpdate: (details) =>
                  _dispatchLetterAtY(constraints, details.localPosition.dy),
              onLongPressEnd: (_) => _endInteraction(),
              onVerticalDragStart: (details) =>
                  _dispatchLetterAtY(constraints, details.localPosition.dy),
              onVerticalDragUpdate: (details) =>
                  _dispatchLetterAtY(constraints, details.localPosition.dy),
              onVerticalDragEnd: (_) => _endInteraction(),
              onVerticalDragCancel: _endInteraction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final letter in widget.letters)
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: letter == _focusedLetter ? 11 : 10,
                          fontWeight: letter == _focusedLetter
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: letter == _focusedLetter
                              ? scheme.primary
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        child: Text(letter),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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

class _MostLikedSection extends ConsumerWidget {
  const _MostLikedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(topLikedQuotesProvider);
    return quotesAsync.when(
      data: (quotes) {
        if (quotes.isEmpty) return const SizedBox.shrink();
        return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most liked',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quotes.length.clamp(0, 10).toInt(),
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
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
            )
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(
              begin: 0.03,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOutCubic,
            );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
