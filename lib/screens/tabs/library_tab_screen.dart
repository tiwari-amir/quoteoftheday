import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_collections/collections_ui/collection_chips_bar.dart';
import '../../features/v3_search/search_providers.dart';
import '../../models/quote_model.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../widgets/editorial_background.dart';

enum _LibraryMode { saved, liked }

class LibraryTabScreen extends ConsumerStatefulWidget {
  const LibraryTabScreen({super.key});

  @override
  ConsumerState<LibraryTabScreen> createState() => _LibraryTabScreenState();
}

class _LibraryTabScreenState extends ConsumerState<LibraryTabScreen> {
  _LibraryMode _mode = _LibraryMode.saved;

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final likedIds = ref.watch(likedQuoteIdsProvider);
    final collections = ref.watch(collectionsProvider);
    final collectionsNotifier = ref.read(collectionsProvider.notifier);
    final selectedCollectionId = collections.selectedCollectionId;

    final scopedSavedIds = selectedCollectionId == allSavedCollectionId
        ? savedIds
        : savedIds.intersection(
            collectionsNotifier
                .quoteIdsForCollection(selectedCollectionId)
                .toSet(),
          );

    final activeIds = _mode == _LibraryMode.saved ? scopedSavedIds : likedIds;

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
                    activeIds,
                    queryState.query,
                  );
                  final isSavedMode = _mode == _LibraryMode.saved;

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
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('Saved (${scopedSavedIds.length})'),
                            selected: isSavedMode,
                            onSelected: (_) {
                              setState(() => _mode = _LibraryMode.saved);
                              queryNotifier.setQueryDebounced('');
                            },
                          ),
                          ChoiceChip(
                            label: Text('Liked (${likedIds.length})'),
                            selected: !isSavedMode,
                            onSelected: (_) {
                              setState(() => _mode = _LibraryMode.liked);
                              queryNotifier.setQueryDebounced('');
                            },
                          ),
                        ],
                      ),
                      if (isSavedMode) ...[
                        const SizedBox(height: 12),
                        const CollectionChipsBar(),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: queryNotifier.setQueryDebounced,
                        decoration: InputDecoration(
                          hintText: isSavedMode
                              ? 'Search in saved'
                              : 'Search in liked',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            isSavedMode
                                ? 'No saved quotes found.'
                                : 'No liked quotes found.',
                          ),
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
                                '/viewer/${isSavedMode ? 'saved' : 'liked'}/${isSavedMode ? 'saved' : 'liked'}?quoteId=${quote.id}',
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
                                  if (v == 'remove_saved') {
                                    ref
                                        .read(savedQuoteIdsProvider.notifier)
                                        .remove(quote.id);
                                  }
                                  if (v == 'remove_liked') {
                                    ref
                                        .read(likedQuoteIdsProvider.notifier)
                                        .toggle(quote.id);
                                  }
                                },
                                itemBuilder: (_) => isSavedMode
                                    ? const [
                                        PopupMenuItem(
                                          value: 'collections',
                                          child: Text('Add to collection'),
                                        ),
                                        PopupMenuItem(
                                          value: 'remove_saved',
                                          child: Text('Remove saved'),
                                        ),
                                      ]
                                    : const [
                                        PopupMenuItem(
                                          value: 'remove_liked',
                                          child: Text('Remove liked'),
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
