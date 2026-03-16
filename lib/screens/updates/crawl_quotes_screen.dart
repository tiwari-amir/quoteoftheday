import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/quote_priority_list_tile.dart';

class CrawlQuotesScreen extends ConsumerWidget {
  const CrawlQuotesScreen({super.key, required this.runId});

  final int runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = FlowLayoutInfo.of(context);
    final batchAsync = ref.watch(crawlRunQuotesProvider(runId));

    return Scaffold(
      floatingActionButton: batchAsync.maybeWhen(
        data: (batch) => batch == null || batch.quotes.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/viewer/crawl/$runId'),
                label: const Text('Scroll'),
                icon: const Icon(Icons.swipe_up_alt_rounded),
              ),
        orElse: () => null,
      ),
      body: Stack(
        children: [
          const EditorialBackground(seed: 89),
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
                  child: batchAsync.when(
                    data: (batch) {
                      if (batch == null) {
                        return _EmptyCrawlState(
                          message: 'That crawl is no longer available.',
                        );
                      }

                      final timestamp = batch.completedAt == null
                          ? null
                          : _formatBatchTimestamp(batch.completedAt!);

                      return Column(
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
                                      'Newly added',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timestamp == null
                                          ? '${batch.quotesAdded} quotes from this crawl'
                                          : '${batch.quotesAdded} quotes from $timestamp',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: _colors(context)
                                                .textSecondary
                                                .withValues(alpha: 0.82),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: FlowSpace.md),
                          if (batch.quotes.isEmpty)
                            const Expanded(
                              child: _EmptyCrawlState(
                                message:
                                    'This crawl did not add any fresh quotes.',
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: batch.quotes.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final quote = batch.quotes[index];
                                  final metaLabel = quote.revisedTags
                                      .take(2)
                                      .map(_toTitleCase)
                                      .join(' • ');
                                  return QuotePriorityListTile(
                                    quote: quote,
                                    metaLabel: metaLabel.isEmpty
                                        ? null
                                        : metaLabel,
                                    onTap: () => context.push(
                                      '/viewer/crawl/$runId?quoteId=${quote.id}',
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => _EmptyCrawlState(
                      message: 'Failed to load this crawl: $error',
                    ),
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

class _EmptyCrawlState extends StatelessWidget {
  const _EmptyCrawlState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PremiumSurface(
        radius: FlowRadii.xl,
        padding: const EdgeInsets.all(FlowSpace.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: _colors(context).textSecondary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

String _formatBatchTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$day/$month';
}

String _toTitleCase(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

FlowColorTokens _colors(BuildContext context) {
  return Theme.of(context).extension<FlowThemeTokens>()!.colors;
}
