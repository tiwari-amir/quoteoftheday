import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_search/search_service.dart';
import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/scale_tap.dart';

class SearchQuotesResultsScreen extends ConsumerWidget {
  const SearchQuotesResultsScreen({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = FlowLayoutInfo.of(context);
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final normalizedQuery = query.trim();
    final quotesAsync = ref.watch(allQuotesProvider);

    return Scaffold(
      floatingActionButton: normalizedQuery.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '/viewer/search/${Uri.encodeComponent(normalizedQuery)}',
              ),
              backgroundColor: (colors?.elevatedSurface ?? Colors.black)
                  .withValues(alpha: 0.94),
              foregroundColor: colors?.textPrimary,
              label: const Text('Scroll'),
              icon: const Icon(Icons.vertical_distribute_rounded),
            ),
      body: Stack(
        children: [
          const EditorialBackground(seed: 91),
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
                          PremiumIconPillButton(
                            icon: Icons.arrow_back_rounded,
                            compact: true,
                            onTap: context.pop,
                          ),
                          const SizedBox(width: FlowSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quotes',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  normalizedQuery,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors?.textSecondary.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FlowSpace.md),
                      Expanded(
                        child: quotesAsync.when(
                          data: (quotes) {
                            final results = normalizedQuery.isEmpty
                                ? const <QuoteModel>[]
                                : SearchService(
                                    quotes,
                                  ).searchQuotes(normalizedQuery, limit: 200);
                            if (results.isEmpty) {
                              return Center(
                                child: Text(
                                  'No quotes found.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: FlowSpace.sm),
                              itemBuilder: (context, index) {
                                final quote = results[index];
                                return _SearchQuoteResultTile(
                                  quote: quote,
                                  onTap: () => context.push(
                                    '/viewer/search/${Uri.encodeComponent(normalizedQuery)}?quoteId=${quote.id}',
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

class _SearchQuoteResultTile extends StatelessWidget {
  const _SearchQuoteResultTile({required this.quote, required this.onTap});

  final QuoteModel quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return ScaleTap(
      onTap: onTap,
      child: PremiumSurface(
        radius: FlowRadii.lg,
        elevation: 1,
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.md,
          FlowSpace.md,
          FlowSpace.md,
          FlowSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quote.quote,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors?.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.42,
              ),
            ),
            const SizedBox(height: FlowSpace.sm),
            Text(
              quote.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors?.textSecondary.withValues(alpha: 0.84),
                letterSpacing: 0.12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
