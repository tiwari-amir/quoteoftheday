import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_collections/collections_ui/collection_chips_bar.dart';
import '../../features/v3_search/search_providers.dart';
import '../../models/quote_model.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/storage_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';

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
    final prefs = ref.read(sharedPreferencesProvider);
    final scrolledCount = prefs.getInt(prefViewerScrolledCount) ?? 0;
    final rankTitle = _scrollRankTitle(scrolledCount);
    final nextMilestone = _nextMilestone(scrolledCount);
    final previousMilestone = _previousMilestone(scrolledCount);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.md,
                FlowSpace.lg,
                FlowSpace.md,
              ),
              child: quotesAsync.when(
                data: (quotes) {
                  final filtered = _filterQuotes(
                    quotes,
                    activeIds,
                    queryState.query,
                  );
                  final isSavedMode = _mode == _LibraryMode.saved;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SectionHeader(
                        title: 'Library',
                        subtitle: 'Saved thoughts and personal favorites',
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      _LibraryAchievementPanel(
                        scrolledCount: scrolledCount,
                        rankTitle: rankTitle,
                        nextMilestone: nextMilestone,
                        previousMilestone: previousMilestone,
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      Wrap(
                        spacing: FlowSpace.xs,
                        runSpacing: FlowSpace.xs,
                        children: [
                          PremiumPillChip(
                            label: 'Saved (${scopedSavedIds.length})',
                            selected: isSavedMode,
                            onTap: () {
                              setState(() => _mode = _LibraryMode.saved);
                              queryNotifier.setQueryDebounced('');
                            },
                          ),
                          PremiumPillChip(
                            label: 'Liked (${likedIds.length})',
                            selected: !isSavedMode,
                            onTap: () {
                              setState(() => _mode = _LibraryMode.liked);
                              queryNotifier.setQueryDebounced('');
                            },
                          ),
                        ],
                      ),
                      if (isSavedMode) ...[
                        const SizedBox(height: FlowSpace.sm),
                        const CollectionChipsBar(),
                      ],
                      const SizedBox(height: FlowSpace.sm),
                      PremiumSurface(
                        radius: FlowRadii.lg,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FlowSpace.sm,
                          vertical: FlowSpace.xxs,
                        ),
                        child: TextField(
                          onChanged: queryNotifier.setQueryDebounced,
                          decoration: InputDecoration(
                            hintText: isSavedMode
                                ? 'Search in saved quotes'
                                : 'Search in liked quotes',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: FlowSpace.sm,
                              vertical: FlowSpace.sm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: FlowSpace.md),
                      if (filtered.isEmpty)
                        PremiumSurface(
                          radius: FlowRadii.lg,
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: FlowSpace.sm,
                            ),
                            child: Text(
                              isSavedMode
                                  ? 'No saved quotes found.'
                                  : 'No liked quotes found.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        for (final quote in filtered.take(100))
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: FlowSpace.sm,
                            ),
                            child: _LibraryQuoteTile(
                              quote: quote,
                              isSavedMode: isSavedMode,
                              onOpen: () => context.push(
                                '/viewer/${isSavedMode ? 'saved' : 'liked'}/${isSavedMode ? 'saved' : 'liked'}?quoteId=${quote.id}',
                              ),
                              onCollections: () => showAddToCollectionSheet(
                                context,
                                ref,
                                quote.id,
                              ),
                              onRemoveSaved: () => ref
                                  .read(savedQuoteIdsProvider.notifier)
                                  .remove(quote.id),
                              onRemoveLiked: () => ref
                                  .read(likedQuoteIdsProvider.notifier)
                                  .toggle(quote.id),
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

  String _scrollRankTitle(int count) {
    if (count >= 1000) return 'Quote Legend';
    if (count >= 500) return 'Quote Master';
    if (count >= 250) return 'Deep Reader';
    if (count >= 100) return 'Night Scroller';
    if (count >= 50) return 'Quote Voyager';
    if (count >= 25) return 'Flow Reader';
    if (count >= 10) return 'Rising Reader';
    return 'Fresh Explorer';
  }

  int _nextMilestone(int count) {
    if (count < 5) return 5;
    if (count < 15) return 15;
    if (count < 25) return 25;
    if (count < 50) return 50;
    return ((count ~/ 50) + 1) * 50;
  }

  int _previousMilestone(int count) {
    if (count < 5) return 0;
    if (count < 15) return 5;
    if (count < 25) return 15;
    if (count < 50) return 25;
    return (count ~/ 50) * 50;
  }
}

class _LibraryAchievementPanel extends StatelessWidget {
  const _LibraryAchievementPanel({
    required this.scrolledCount,
    required this.rankTitle,
    required this.nextMilestone,
    required this.previousMilestone,
  });

  final int scrolledCount;
  final String rankTitle;
  final int nextMilestone;
  final int previousMilestone;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final span = (nextMilestone - previousMilestone).clamp(1, 1000000);
    final progressed = (scrolledCount - previousMilestone).clamp(0, span);
    final progress = progressed / span;
    final remaining = (nextMilestone - scrolledCount).clamp(0, nextMilestone);

    return PremiumSurface(
      radius: FlowRadii.xl,
      elevation: 2,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: FlowRadii.radiusXl,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (colors?.accent ?? Colors.white).withValues(alpha: 0.15),
              (colors?.surface ?? Colors.black).withValues(alpha: 0.55),
              (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.md,
            FlowSpace.md,
            FlowSpace.md,
            FlowSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.2,
                      ),
                      border: Border.all(
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 18,
                      color: colors?.accent ?? Colors.white,
                    ),
                  ),
                  const SizedBox(width: FlowSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scroll Achievement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.96,
                                ),
                                letterSpacing: 0.35,
                              ),
                        ),
                        Text(
                          rankTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors?.textPrimary.withValues(
                                  alpha: 0.97,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FlowSpace.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: (colors?.surface ?? Colors.black).withValues(
                        alpha: 0.82,
                      ),
                      border: Border.all(
                        color:
                            colors?.divider.withValues(alpha: 0.75) ??
                            Colors.white24,
                      ),
                    ),
                    child: Text(
                      '$scrolledCount',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors?.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FlowSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  color: colors?.accent,
                  backgroundColor:
                      colors?.divider.withValues(alpha: 0.55) ?? Colors.white24,
                ),
              ),
              const SizedBox(height: FlowSpace.xs),
              Text(
                remaining == 0
                    ? 'Milestone reached: $nextMilestone'
                    : '$remaining more to reach $nextMilestone',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.96),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryQuoteTile extends StatelessWidget {
  const _LibraryQuoteTile({
    required this.quote,
    required this.isSavedMode,
    required this.onOpen,
    required this.onCollections,
    required this.onRemoveSaved,
    required this.onRemoveLiked,
  });

  final QuoteModel quote;
  final bool isSavedMode;
  final VoidCallback onOpen;
  final VoidCallback onCollections;
  final VoidCallback onRemoveSaved;
  final VoidCallback onRemoveLiked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return PremiumSurface(
      radius: FlowRadii.lg,
      elevation: 1,
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.sm,
        FlowSpace.xs,
        FlowSpace.sm,
      ),
      child: InkWell(
        borderRadius: FlowRadii.radiusLg,
        onTap: onOpen,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.quote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colors?.textSecondary),
              onSelected: (v) {
                if (v == 'collections') onCollections();
                if (v == 'remove_saved') onRemoveSaved();
                if (v == 'remove_liked') onRemoveLiked();
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
          ],
        ),
      ),
    );
  }
}
