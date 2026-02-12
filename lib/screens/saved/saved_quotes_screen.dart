import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/scale_tap.dart';

class SavedQuotesScreen extends ConsumerWidget {
  const SavedQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final quotesAsync = ref.watch(allQuotesProvider);

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
                      GlassIconButton(icon: Icons.close_rounded, onTap: context.pop),
                      const SizedBox(width: 12),
                      Text('Saved', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: quotesAsync.when(
                      data: (quotes) {
                        final savedQuotes = quotes.where((q) => savedIds.contains(q.id)).toList();

                        if (savedQuotes.isEmpty) {
                          return Center(
                            child: Text(
                              'No saved quotes yet',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: savedQuotes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final quote = savedQuotes[index];
                            return ScaleTap(
                              onTap: () => _showQuoteDetail(context, quote),
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
                                    IconButton(
                                      onPressed: () => ref.read(savedQuoteIdsProvider.notifier).remove(quote.id),
                                      icon: const Icon(Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(child: Text('Failed to load: $error')),
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

  void _showQuoteDetail(BuildContext context, QuoteModel quote) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.quote, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(quote.author, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
