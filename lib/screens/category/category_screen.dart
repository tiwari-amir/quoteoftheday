import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_search_field.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/quote_priority_list_tile.dart';
import '../../widgets/scale_tap.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, this.selectedTag});

  final String? selectedTag;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  String _query = '';

  bool get _showCategoryDetail =>
      (widget.selectedTag?.trim().isNotEmpty ?? false);

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
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

    const spacing = 14.0;
    const sideBarWidth = 30.0;
    final layout = FlowLayoutInfo.of(context);
    final gridWidth = math.max(140.0, availableWidth - sideBarWidth - 14);
    final columns = layout.columnsFor(
      gridWidth,
      minTileWidth: _categoryTileMaxExtent(layout),
      maxColumns: layout.isDesktop ? 4 : 3,
    );
    final tileWidth = layout.tileWidthFor(
      gridWidth,
      columns: columns,
      gap: spacing,
    );
    final tileHeight = tileWidth / 1.08;
    final row = index ~/ columns;
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

  double _categoryTileMaxExtent(FlowLayoutInfo layout) {
    if (layout.isDesktop) return 280;
    if (layout.isTablet) return 240;
    return 210;
  }

  @override
  Widget build(BuildContext context) {
    return _showCategoryDetail
        ? _buildCategoryDetail(context)
        : _buildCategoryBrowser(context);
  }

  Widget _buildCategoryBrowser(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final service = ref.read(quoteServiceProvider);
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Categories',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              PremiumIconPillButton(
                                icon: Icons.arrow_back_rounded,
                                compact: true,
                                onTap: context.pop,
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
                      const SizedBox(height: 14),
                      PremiumSearchField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            hintText: 'Search categories',
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
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
                                        label: _categoryLabel(
                                          entry.key,
                                          service,
                                        ),
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
                                            physics:
                                                const BouncingScrollPhysics(),
                                            slivers: [
                                              SliverGrid(
                                                delegate: SliverChildBuilderDelegate((
                                                  context,
                                                  index,
                                                ) {
                                                  final item = filtered[index];
                                                  final routeTag =
                                                      _categoryRouteTag(
                                                        item.tag,
                                                      );
                                                  return ScaleTap(
                                                    onTap: () => context.push(
                                                      '/categories/${Uri.encodeComponent(routeTag)}',
                                                    ),
                                                    child: _CategoryCard(
                                                      item: item,
                                                    ),
                                                  );
                                                }, childCount: filtered.length),
                                                gridDelegate:
                                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                                      maxCrossAxisExtent:
                                                          _categoryTileMaxExtent(
                                                            layout,
                                                          ),
                                                      crossAxisSpacing: 14,
                                                      mainAxisSpacing: 14,
                                                      childAspectRatio: 1.08,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        _LetterQuickBar(
                                          letters: quickLetters,
                                          onLetterTap: (letter) =>
                                              _jumpToLetter(
                                                letter: letter,
                                                items: filtered,
                                                availableWidth:
                                                    constraints.maxWidth,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDetail(BuildContext context) {
    final selectedTag = (widget.selectedTag ?? '').trim().toLowerCase();
    final routeTag = _categoryRouteTag(selectedTag);
    final service = ref.read(quoteServiceProvider);
    final label = _categoryLabel(selectedTag, service);
    final quotesAsync = ref.watch(
      quotesByFilterProvider(
        QuoteViewerFilter(type: 'category', tag: selectedTag),
      ),
    );

    return Scaffold(
      floatingActionButton: quotesAsync.maybeWhen(
        data: (quotes) => quotes.isEmpty
            ? null
            : FloatingActionButton(
                backgroundColor: Theme.of(
                  context,
                ).extension<FlowThemeTokens>()?.colors.accent,
                foregroundColor: Theme.of(
                  context,
                ).extension<FlowThemeTokens>()?.colors.background,
                onPressed: () => context.push(
                  '/viewer/category/${Uri.encodeComponent(routeTag)}',
                ),
                child: const Icon(Icons.menu_book_rounded),
              ),
        orElse: () => null,
      ),
      body: Stack(
        children: [
          const EditorialBackground(),
          quotesAsync.when(
            data: (quotes) {
              final colors = Theme.of(
                context,
              ).extension<FlowThemeTokens>()?.colors;
              return SafeArea(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: quotes.isNotEmpty,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: (colors?.surface ?? Colors.black)
                            .withValues(alpha: 0.9),
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        toolbarHeight: 78,
                        leadingWidth: 74,
                        titleSpacing: 0,
                        flexibleSpace: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (colors?.surface ?? Colors.black).withValues(
                                  alpha: 0.96,
                                ),
                                (colors?.elevatedSurface ?? Colors.black)
                                    .withValues(alpha: 0.88),
                              ],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: (colors?.divider ?? Colors.white24)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 20, top: 10),
                          child: PremiumIconPillButton(
                            icon: Icons.arrow_back_rounded,
                            compact: true,
                            onTap: context.pop,
                          ),
                        ),
                        title: Padding(
                          padding: const EdgeInsets.only(
                            left: 6,
                            right: 20,
                            top: 12,
                            bottom: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${quotes.length} quotes',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.68,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                          child: _CategoryDetailHero(
                            label: label,
                            entryCount: quotes.length,
                            onScrollMode: () => context.push(
                              '/viewer/category/${Uri.encodeComponent(routeTag)}',
                            ),
                          ),
                        ),
                      ),
                      if (quotes.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'No quotes found for $label',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                          sliver: SliverList.separated(
                            itemCount: quotes.length,
                            itemBuilder: (context, index) {
                              final quote = quotes[index];
                              return _CategoryQuoteCard(
                                quote: quote,
                                service: service,
                                onTap: () => context.push(
                                  '/viewer/category/${Uri.encodeComponent(routeTag)}?quoteId=${quote.id}',
                                ),
                              );
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Failed to load: $error')),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String rawTag, QuoteService service) {
    final tag = rawTag.trim().toLowerCase();
    if (tag == 'series' || tag == 'movies/series') return 'Movies/Series';
    return service.toTitleCase(tag);
  }

  String _categoryRouteTag(String rawTag) {
    final tag = rawTag.trim().toLowerCase();
    if (tag == 'series') return 'movies/series';
    return tag;
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
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface.withValues(alpha: _hovering ? 0.92 : 0.88),
                scheme.surface.withValues(alpha: _hovering ? 0.72 : 0.66),
              ],
            ),
            border: Border.all(color: _hovering ? borderHover : borderIdle),
            boxShadow: [
              BoxShadow(
                color: _hovering ? glow : Colors.black.withValues(alpha: 0.25),
                blurRadius: _hovering ? 30 : 18,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  height: 1.02,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '${widget.item.count} quotes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDetailHero extends StatelessWidget {
  const _CategoryDetailHero({
    required this.label,
    required this.entryCount,
    required this.onScrollMode,
  });

  final String label;
  final int entryCount;
  final VoidCallback onScrollMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return PremiumSurface(
      radius: FlowRadii.xl,
      elevation: 2,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$entryCount quotes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors?.textPrimary,
            ),
          ),
          const SizedBox(height: FlowSpace.xs),
          Text(
            _categoryHeroCopy(label),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.42,
              color: colors?.textSecondary.withValues(alpha: 0.94),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CategoryInfoChip(
                icon: Icons.menu_book_rounded,
                label: '$entryCount entries',
              ),
              const SizedBox(width: FlowSpace.xs),
              GestureDetector(
                onTap: onScrollMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FlowSpace.sm,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (colors?.accent ?? Colors.white).withValues(
                      alpha: 0.14,
                    ),
                    border: Border.all(
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.44,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_up_alt_rounded,
                        size: 15,
                        color: colors?.accent ?? Colors.white,
                      ),
                      const SizedBox(width: FlowSpace.xs),
                      Text(
                        'Scroll mode',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors?.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryInfoChip extends StatelessWidget {
  const _CategoryInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumPillChip(label: label, icon: icon, compact: true);
  }
}

class _CategoryQuoteCard extends StatelessWidget {
  const _CategoryQuoteCard({
    required this.quote,
    required this.service,
    required this.onTap,
  });

  final QuoteModel quote;
  final QuoteService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = quote.revisedTags.isEmpty
        ? null
        : service.toTitleCase(quote.revisedTags.first);
    return QuotePriorityListTile(quote: quote, onTap: onTap, metaLabel: meta);
  }
}

String _categoryHeroCopy(String label) {
  final lower = label.toLowerCase();
  if (lower == 'love') {
    return 'A collected reading of tenderness, longing, devotion, and loss.';
  }
  if (lower == 'death') {
    return 'Reflections on mortality, grief, and what it means to be human.';
  }
  if (lower == 'philosophy') {
    return 'Lines on thought, meaning, doubt, and the shape of a life.';
  }
  return 'A curated set of memorable lines gathered around $label.';
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
          color: scheme.surface.withValues(alpha: 0.52),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
