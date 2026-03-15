import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/premium/premium_search_field.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/quote_priority_list_tile.dart';
import '../../widgets/scale_tap.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key, this.selectedMood});

  final String? selectedMood;

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.selectedMood?.trim().isNotEmpty ?? false)) {
      return _MoodDetailView(selectedMood: widget.selectedMood!.trim());
    }

    final moodsAsync = ref.watch(moodCountsProvider);
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
                              'Moods',
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
                      ),
                      const SizedBox(height: 14),
                      PremiumSearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hintText: 'Search moods',
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: moodsAsync.when(
                          data: (moods) {
                            final list =
                                moods.entries
                                    .map(
                                      (entry) => _MoodCount(
                                        mood: entry.key,
                                        label: service.toTitleCase(entry.key),
                                        count: entry.value,
                                      ),
                                    )
                                    .where(
                                      (item) => item.label
                                          .toLowerCase()
                                          .contains(_query),
                                    )
                                    .toList()
                                  ..sort((a, b) => a.label.compareTo(b.label));

                            if (list.isEmpty) {
                              return const Center(
                                child: Text('No moods available in dataset'),
                              );
                            }

                            return GridView.builder(
                              itemCount: list.length,
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: layout.isDesktop
                                        ? 280
                                        : layout.isTablet
                                        ? 250
                                        : 210,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: layout.isTablet
                                        ? 1.15
                                        : 1.08,
                                  ),
                              itemBuilder: (context, index) {
                                final item = list[index];
                                return ScaleTap(
                                      onTap: () => context.push(
                                        '/viewer/mood/${Uri.encodeComponent(item.mood)}',
                                      ),
                                      child: _MoodCard(item: item),
                                    )
                                    .animate(delay: (index * 24).ms)
                                    .fadeIn(duration: 260.ms)
                                    .slideY(begin: 0.08, end: 0);
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
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatefulWidget {
  const _MoodCard({required this.item});

  final _MoodCount item;

  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard> {
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
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface.withValues(alpha: 0.92),
              scheme.surface.withValues(alpha: 0.68),
            ],
          ),
          border: Border.all(color: _hovering ? borderHover : borderIdle),
          boxShadow: [
            BoxShadow(
              color: _hovering ? glow : Colors.black.withValues(alpha: 0.25),
              blurRadius: _hovering ? 28 : 18,
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${widget.item.count} quotes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodCount {
  const _MoodCount({
    required this.mood,
    required this.label,
    required this.count,
  });

  final String mood;
  final String label;
  final int count;
}

class _MoodDetailView extends ConsumerWidget {
  const _MoodDetailView({required this.selectedMood});

  final String selectedMood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = FlowLayoutInfo.of(context);
    final service = ref.read(quoteServiceProvider);
    final label = service.toTitleCase(selectedMood);
    final quotesAsync = ref.watch(
      quotesByFilterProvider(
        QuoteViewerFilter(type: 'mood', tag: selectedMood.toLowerCase()),
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
                  '/viewer/mood/${Uri.encodeComponent(selectedMood)}',
                ),
                child: const Icon(Icons.vertical_distribute_rounded),
              ),
        orElse: () => null,
      ),
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
                              label,
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
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      Text(
                        'List view for this mood. Use the action button for the reel.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .extension<FlowThemeTokens>()
                              ?.colors
                              .textSecondary
                              .withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: FlowSpace.md),
                      Expanded(
                        child: quotesAsync.when(
                          data: (quotes) {
                            if (quotes.isEmpty) {
                              return Center(
                                child: Text(
                                  'No quotes found for $label',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: quotes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: FlowSpace.sm),
                              itemBuilder: (context, index) {
                                final quote = quotes[index];
                                return _MoodQuoteTile(
                                  quote: quote,
                                  service: service,
                                  onTap: () => context.push(
                                    '/viewer/mood/${Uri.encodeComponent(selectedMood)}?quoteId=${quote.id}',
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodQuoteTile extends StatelessWidget {
  const _MoodQuoteTile({
    required this.quote,
    required this.onTap,
    required this.service,
  });

  final QuoteModel quote;
  final VoidCallback onTap;
  final QuoteService service;

  @override
  Widget build(BuildContext context) {
    final meta = quote.revisedTags.isEmpty
        ? null
        : service.toTitleCase(quote.revisedTags.first);
    return QuotePriorityListTile(quote: quote, onTap: onTap, metaLabel: meta);
  }
}
