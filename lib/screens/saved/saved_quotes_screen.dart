import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';

class SavedQuotesScreen extends ConsumerWidget {
  const SavedQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final quotesAsync = ref.watch(allQuotesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: context.pop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saved Quotes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: quotesAsync.when(
                      data: (quotes) {
                        final savedQuotes = quotes
                            .where((quote) => savedIds.contains(quote.id))
                            .toList();

                        if (savedQuotes.isEmpty) {
                          return const Center(
                            child: Text('No saved quotes yet.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: savedQuotes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final quote = savedQuotes[index];

                            return GlassCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('"${quote.quote}"'),
                                        const SizedBox(height: 8),
                                        Text('- ${quote.author}'),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      ref
                                          .read(savedQuoteIdsProvider.notifier)
                                          .remove(quote.id);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Failed to load saved quotes: $error'),
                      ),
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
