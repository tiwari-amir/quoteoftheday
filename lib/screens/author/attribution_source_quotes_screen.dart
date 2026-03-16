import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/quote_priority_list_tile.dart';

class AttributionSourceQuotesScreen extends ConsumerWidget {
  const AttributionSourceQuotesScreen({
    super.key,
    required this.sourceKey,
    required this.sourceName,
  });

  final String sourceKey;
  final String sourceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = FlowLayoutInfo.of(context);
    final service = ref.read(quoteServiceProvider);
    final quotesAsync = ref.watch(
      quotesByFilterProvider(QuoteViewerFilter(type: 'source', tag: sourceKey)),
    );

    return Scaffold(
      floatingActionButton: quotesAsync.maybeWhen(
        data: (quotes) => quotes.isEmpty
            ? null
            : FloatingActionButton.small(
                onPressed: () => context.push(
                  '/viewer/source/${Uri.encodeComponent(sourceKey)}',
                ),
                child: const Icon(Icons.swipe_up_alt_rounded),
              ),
        orElse: () => null,
      ),
      body: Stack(
        children: [
          const EditorialBackground(seed: 91),
          quotesAsync.when(
            data: (quotes) {
              final colors = Theme.of(
                context,
              ).extension<FlowThemeTokens>()?.colors;
              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.maxContentWidth,
                    ),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          expandedHeight: layout.isCompact
                              ? 300
                              : layout.fluid(min: 284, max: 336),
                          backgroundColor: (colors?.surface ?? Colors.black)
                              .withValues(alpha: 0.88),
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          toolbarHeight: layout.isCompact ? 76 : 82,
                          leadingWidth: 74,
                          titleSpacing: 0,
                          title: const SizedBox.shrink(),
                          flexibleSpace: FlexibleSpaceBar(
                            collapseMode: CollapseMode.pin,
                            background: _AttributionSourceHero(
                              sourceName: sourceName,
                              quoteCount: quotes.length,
                            ),
                          ),
                          leading: Padding(
                            padding: EdgeInsets.only(
                              left: layout.horizontalPadding,
                              top: 10,
                            ),
                            child: PremiumIconPillButton(
                              icon: Icons.arrow_back_rounded,
                              compact: true,
                              onTap: context.pop,
                            ),
                          ),
                        ),
                        if (quotes.isEmpty) ...[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No quotes found for $sourceName',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ] else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                layout.horizontalPadding,
                                18,
                                layout.horizontalPadding,
                                14,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final chip = PremiumPillChip(
                                    label: '${quotes.length} entries',
                                    compact: true,
                                    icon: Icons.collections_bookmark_rounded,
                                  );

                                  if (constraints.maxWidth < 320) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Collected quotes',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: FlowSpace.xs),
                                        chip,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Collected quotes',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      chip,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              layout.horizontalPadding,
                              0,
                              layout.horizontalPadding,
                              layout.dockBodyInset + 48,
                            ),
                            sliver: SliverList.separated(
                              itemCount: quotes.length,
                              itemBuilder: (context, index) {
                                final quote = quotes[index];
                                final metaLabel = quote.revisedTags
                                    .take(2)
                                    .map(service.toTitleCase)
                                    .join(' • ');
                                return QuotePriorityListTile(
                                  quote: quote,
                                  metaLabel: metaLabel.isEmpty
                                      ? null
                                      : metaLabel,
                                  showAuthorName: false,
                                  showPortrait: false,
                                  onTap: () => context.push(
                                    '/viewer/source/${Uri.encodeComponent(sourceKey)}?quoteId=${quote.id}',
                                  ),
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                            ),
                          ),
                        ],
                      ],
                    ),
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
}

class _AttributionSourceHero extends StatelessWidget {
  const _AttributionSourceHero({
    required this.sourceName,
    required this.quoteCount,
  });

  final String sourceName;
  final int quoteCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (colors?.surface ?? Colors.black).withValues(alpha: 0.9),
            (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.97),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -44,
            left: -12,
            right: -12,
            child: IgnorePointer(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      (colors?.accent ?? Colors.white).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              layout.horizontalPadding,
              layout.isCompact ? 96 : 108,
              layout.horizontalPadding,
              24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: layout.isCompact ? 84 : 96,
                  height: layout.isCompact ? 84 : 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.24,
                        ),
                        (colors?.surface ?? Colors.black).withValues(
                          alpha: 0.94,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: layout.isCompact ? 34 : 40,
                    color: colors?.accent ?? Colors.white70,
                  ),
                ),
                const SizedBox(height: FlowSpace.md),
                Text(
                  sourceName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  sourceStyleDescriptor(sourceName),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors?.textSecondary.withValues(alpha: 0.86),
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$quoteCount curated quotes',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors?.textSecondary.withValues(alpha: 0.78),
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
