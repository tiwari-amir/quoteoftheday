import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_collections/collections_ui/collection_chips_bar.dart';
import '../../features/v3_search/search_providers.dart';
import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../widgets/editorial_background.dart';

class LibraryTabScreen extends ConsumerWidget {
  const LibraryTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final collections = ref.watch(collectionsProvider);
    final collectionsNotifier = ref.read(collectionsProvider.notifier);
    final selectedCollectionId = collections.selectedCollectionId;
    final scopedIds = selectedCollectionId == allSavedCollectionId
        ? savedIds
        : savedIds.intersection(
            collectionsNotifier
                .quoteIdsForCollection(selectedCollectionId)
                .toSet(),
          );

    final quotesAsync = ref.watch(allQuotesProvider);
    final queryState = ref.watch(searchQueryProvider);
    final queryNotifier = ref.read(searchQueryProvider.notifier);
    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: quotesAsync.when(
                data: (quotes) {
                  final filtered = _filterQuotes(
                    quotes,
                    scopedIds,
                    queryState.query,
                  );
                  return ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Library',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const CollectionChipsBar(),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: queryNotifier.setQueryDebounced,
                        decoration: const InputDecoration(
                          hintText: 'Search in saved',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('No saved quotes found.'),
                        )
                      else
                        for (final quote in filtered.take(100))
                          Card(
                            child: ListTile(
                              title: Text(
                                quote.quote,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(quote.author),
                              onTap: () => context.push(
                                '/viewer/saved/saved?quoteId=${quote.id}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'collections') {
                                    showAddToCollectionSheet(
                                      context,
                                      ref,
                                      quote.id,
                                    );
                                  }
                                  if (v == 'remove') {
                                    ref
                                        .read(savedQuoteIdsProvider.notifier)
                                        .remove(quote.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'collections',
                                    child: Text('Add to collection'),
                                  ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Failed to load: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<QuoteModel> _filterQuotes(
    List<QuoteModel> quotes,
    Set<String> ids,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return quotes
        .where((quote) {
          if (!ids.contains(quote.id)) return false;
          if (q.isEmpty) return true;
          return quote.quote.toLowerCase().contains(q) ||
              quote.author.toLowerCase().contains(q) ||
              quote.revisedTags.join(' ').toLowerCase().contains(q);
        })
        .toList(growable: false);
  }
}
