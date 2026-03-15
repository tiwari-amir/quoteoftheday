import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_collections/collections_model.dart';
import '../../features/v3_collections/collections_providers.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../models/quote_model.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/viewer_progress_provider.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/author_portrait_circle.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_search_field.dart';
import '../../widgets/premium/premium_components.dart';

enum _LibraryMode { saved, liked }

class LibraryTabScreen extends ConsumerStatefulWidget {
  const LibraryTabScreen({super.key});

  @override
  ConsumerState<LibraryTabScreen> createState() => _LibraryTabScreenState();
}

class _LibraryTabScreenState extends ConsumerState<LibraryTabScreen> {
  _LibraryMode _mode = _LibraryMode.saved;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _showBackToTop = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.hasClients
        ? _scrollController.offset > 220
        : false;
    if (shouldShow == _showBackToTop) return;
    setState(() => _showBackToTop = shouldShow);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();
    if (!mounted) return;
    setState(() => _searchQuery = value.trim());
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (!mounted) return;
    setState(() => _searchQuery = '');
  }

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

    final quotesAsync = ref.watch(allQuotesProvider);
    final scrolledCount = ref.watch(
      viewerProgressProvider.select((state) => state.scrolledCount),
    );
    final layout = FlowLayoutInfo.of(context);
    final rankTitle = _scrollRankTitle(scrolledCount);
    final nextMilestone = _nextMilestone(scrolledCount);
    final previousMilestone = _previousMilestone(scrolledCount);

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
                  child: quotesAsync.when(
                    data: (quotes) {
                      final availableQuoteIds = quotes
                          .map((quote) => quote.id)
                          .toSet();
                      final availableSavedIds = scopedSavedIds.intersection(
                        availableQuoteIds,
                      );
                      final availableLikedIds = likedIds.intersection(
                        availableQuoteIds,
                      );
                      final activeIds = _mode == _LibraryMode.saved
                          ? availableSavedIds
                          : availableLikedIds;
                      final staleSavedIds = scopedSavedIds.difference(
                        availableQuoteIds,
                      );
                      final staleLikedIds = likedIds.difference(
                        availableQuoteIds,
                      );
                      if (staleSavedIds.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          unawaited(
                            ref
                                .read(savedQuoteIdsProvider.notifier)
                                .pruneUnavailable(availableQuoteIds),
                          );
                        });
                      }
                      if (staleLikedIds.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          unawaited(
                            ref
                                .read(likedQuoteIdsProvider.notifier)
                                .pruneUnavailable(availableQuoteIds),
                          );
                        });
                      }
                      final filtered = _filterQuotes(
                        quotes,
                        activeIds,
                        _searchQuery,
                      );
                      final searchResults = _filterQuotes(
                        quotes,
                        availableSavedIds,
                        _searchQuery,
                      );
                      final isSavedMode = _mode == _LibraryMode.saved;
                      final inSearchMode =
                          _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;
                      final selectedCollectionName = _selectedCollectionName(
                        collections,
                      );
                      final hasFocusedShelf =
                          isSavedMode && selectedCollectionName != 'All Saved';
                      final commandDeckExtent = _libraryCommandDeckExtent(
                        layout,
                        hasFocusedShelf: hasFocusedShelf,
                      );
                      final libraryIds = <String>{
                        ...availableSavedIds,
                        ...availableLikedIds,
                      };
                      final libraryQuotes = _quotesForIds(quotes, libraryIds);
                      final focusQuotes = libraryQuotes.isEmpty
                          ? quotes
                          : libraryQuotes;
                      final topThemes = _topThemes(focusQuotes);
                      final topAuthors = _topAuthors(focusQuotes);
                      final focusLine = _buildLibraryFocusLine(
                        service: ref.read(quoteServiceProvider),
                        focusQuotes: focusQuotes,
                        topThemes: topThemes,
                        topAuthors: topAuthors,
                        savedCount: availableSavedIds.length,
                        likedCount: availableLikedIds.length,
                      );
                      final recommendations = _buildRecommendations(
                        quotes: quotes,
                        savedIds: availableSavedIds,
                        likedIds: availableLikedIds,
                        topThemes: topThemes,
                        topAuthors: topAuthors,
                        service: ref.read(quoteServiceProvider),
                      );
                      final collectionSummaries = _buildCollectionSummaries(
                        quotes: quotes,
                        availableSavedIds: availableSavedIds,
                        availableQuoteIds: availableQuoteIds,
                        collections: collections,
                        collectionsNotifier: collectionsNotifier,
                        service: ref.read(quoteServiceProvider),
                      );
                      void selectSavedMode() {
                        _searchFocusNode.unfocus();
                        _clearSearch();
                        setState(() => _mode = _LibraryMode.saved);
                      }

                      void selectLikedMode() {
                        _searchFocusNode.unfocus();
                        _clearSearch();
                        setState(() => _mode = _LibraryMode.liked);
                      }

                      void selectShelf(String collectionId) {
                        _searchFocusNode.unfocus();
                        _clearSearch();
                        setState(() => _mode = _LibraryMode.saved);
                        ref
                            .read(collectionsProvider.notifier)
                            .selectCollection(collectionId);
                      }

                      if (quotes.isEmpty) {
                        return const _LibraryMessageState(
                          title: 'Library is empty',
                          body:
                              'Quotes are still loading into the archive. Try again in a moment.',
                        );
                      }
                      if (inSearchMode) {
                        return _LibrarySearchExperience(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          query: _searchQuery,
                          selectedCollectionName: selectedCollectionName,
                          savedCount: availableSavedIds.length,
                          results: searchResults,
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          onClear: _clearSearch,
                          onOpenQuote: (quote) => context.push(
                            '/viewer/saved/saved?quoteId=${quote.id}',
                          ),
                          onCollections: (quote) =>
                              showSaveQuoteSheet(context, ref, quote.id),
                          onToggleLiked: (quote) => ref
                              .read(likedQuoteIdsProvider.notifier)
                              .toggle(quote.id),
                          onRemoveSaved: (quote) async {
                            await ref
                                .read(savedQuoteIdsProvider.notifier)
                                .remove(quote.id);
                            await ref
                                .read(collectionsProvider.notifier)
                                .removeQuoteFromAllCollections(quote.id);
                          },
                          likedQuoteIds: availableLikedIds,
                          onStatusMessage: (message) {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(message)));
                          },
                        );
                      }
                      return Stack(
                        children: [
                          CustomScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: _LibraryTopHeader(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  selectedCollectionName:
                                      selectedCollectionName,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: _onSearchSubmitted,
                                  onClear: _clearSearch,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: FlowSpace.lg),
                              ),
                              SliverToBoxAdapter(
                                child: _PremiumLibraryAchievementPanel(
                                  scrolledCount: scrolledCount,
                                  savedCount: availableSavedIds.length,
                                  likedCount: availableLikedIds.length,
                                  collectionCount:
                                      collections.collections.length,
                                  rankTitle: rankTitle,
                                  nextMilestone: nextMilestone,
                                  previousMilestone: previousMilestone,
                                  focusLine: focusLine,
                                  topThemes: topThemes,
                                  topAuthors: topAuthors,
                                  selectedCollectionName: isSavedMode
                                      ? selectedCollectionName
                                      : null,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: FlowSpace.lg),
                              ),
                              if (recommendations.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _LibraryForYouShelf(
                                    recommendations: recommendations
                                        .take(layout.isCompact ? 4 : 6)
                                        .toList(growable: false),
                                    topThemes: topThemes,
                                    topAuthors: topAuthors,
                                    onOpenQuote: (quote) => context.push(
                                      '/viewer/category/all?quoteId=${quote.id}',
                                    ),
                                  ),
                                ),
                              if (recommendations.isNotEmpty)
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: FlowSpace.lg),
                                ),
                              SliverToBoxAdapter(
                                child: _LibraryCollectionGallery(
                                  collections: collectionSummaries,
                                  selectedCollectionId:
                                      collections.selectedCollectionId,
                                  onSelectCollection: selectShelf,
                                  onCreateCollection: () =>
                                      _showCreateCollectionDialog(context),
                                  onCollectionActions: (collection) =>
                                      _showCollectionActions(
                                        context,
                                        collection,
                                      ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: FlowSpace.lg),
                              ),
                              SliverToBoxAdapter(
                                child: _LibrarySectionHeader(
                                  title: isSavedMode
                                      ? 'Saved lines'
                                      : 'Liked lines',
                                  eyebrow: 'READING ROOM',
                                  subtitle: hasFocusedShelf
                                      ? 'Focused on $selectedCollectionName'
                                      : null,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: FlowSpace.sm),
                              ),
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _LibraryPinnedToolbarDelegate(
                                  minExtentValue: commandDeckExtent,
                                  maxExtentValue: commandDeckExtent,
                                  child: _LibraryCommandDeck(
                                    isSavedMode: isSavedMode,
                                    selectedCollectionName:
                                        selectedCollectionName,
                                    availableSavedCount:
                                        availableSavedIds.length,
                                    availableLikedCount:
                                        availableLikedIds.length,
                                    onSelectSaved: selectSavedMode,
                                    onSelectLiked: selectLikedMode,
                                    onResetCollection: () =>
                                        selectShelf(allSavedCollectionId),
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: FlowSpace.sm),
                              ),
                              if (filtered.isEmpty)
                                SliverToBoxAdapter(
                                  child: PremiumSurface(
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SliverList.separated(
                                  itemCount: filtered.take(100).length,
                                  itemBuilder: (context, index) {
                                    final quote = filtered[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: FlowSpace.sm,
                                      ),
                                      child: _LibraryQuoteTile(
                                        quote: quote,
                                        isSavedMode: isSavedMode,
                                        shelfLabel: isSavedMode
                                            ? selectedCollectionName
                                            : 'Liked',
                                        onOpen: () => context.push(
                                          '/viewer/${isSavedMode ? 'saved' : 'liked'}/${isSavedMode ? 'saved' : 'liked'}?quoteId=${quote.id}',
                                        ),
                                        onCollections: () => showSaveQuoteSheet(
                                          context,
                                          ref,
                                          quote.id,
                                        ),
                                        isLiked: availableLikedIds.contains(
                                          quote.id,
                                        ),
                                        onToggleLiked: () => ref
                                            .read(
                                              likedQuoteIdsProvider.notifier,
                                            )
                                            .toggle(quote.id),
                                        onRemoveSaved: () async {
                                          await ref
                                              .read(
                                                savedQuoteIdsProvider.notifier,
                                              )
                                              .remove(quote.id);
                                          await ref
                                              .read(
                                                collectionsProvider.notifier,
                                              )
                                              .removeQuoteFromAllCollections(
                                                quote.id,
                                              );
                                        },
                                        onRemoveLiked: () => ref
                                            .read(
                                              likedQuoteIdsProvider.notifier,
                                            )
                                            .toggle(quote.id),
                                        onStatusMessage: (message) {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          messenger
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(content: Text(message)),
                                            );
                                        },
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, _) =>
                                      const SizedBox.shrink(),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 120),
                              ),
                            ],
                          ),
                          if (_showBackToTop)
                            Positioned(
                              right: 4,
                              bottom: 12,
                              child: SafeArea(
                                child: PremiumIconPillButton(
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  compact: true,
                                  onTap: () => _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const _LibraryMessageState(
                      title: 'Loading library',
                      body:
                          'Preparing your saved quotes, liked quotes, and collections.',
                      loading: true,
                    ),
                    error: (e, s) => _LibraryMessageState(
                      title: 'Library unavailable',
                      body: 'Failed to load library data: $e',
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

  List<QuoteModel> _quotesForIds(List<QuoteModel> quotes, Set<String> ids) {
    return quotes
        .where((quote) => ids.contains(quote.id))
        .toList(growable: false);
  }

  List<String> _topThemes(List<QuoteModel> quotes, {int limit = 6}) {
    final counts = <String, int>{};
    for (final quote in quotes) {
      for (final tag in quote.revisedTags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty || normalized == 'all') continue;
        counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return sorted.take(limit).map((entry) => entry.key).toList(growable: false);
  }

  List<_LibraryAuthorSignal> _topAuthors(
    List<QuoteModel> quotes, {
    int limit = 5,
  }) {
    final grouped = <String, _LibraryAuthorSignal>{};
    for (final quote in quotes) {
      final authorName = quote.author.trim();
      final authorKey = normalizeAuthorKey(
        quote.canonicalAuthor.isNotEmpty ? quote.canonicalAuthor : authorName,
      );
      if (authorKey.isEmpty || authorKey == 'unknown') continue;
      final existing = grouped[authorKey];
      if (existing == null) {
        grouped[authorKey] = _LibraryAuthorSignal(
          authorKey: authorKey,
          authorName: authorName,
          quoteCount: 1,
        );
      } else {
        grouped[authorKey] = _LibraryAuthorSignal(
          authorKey: authorKey,
          authorName: existing.authorName,
          quoteCount: existing.quoteCount + 1,
        );
      }
    }

    final ranked = grouped.values.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.quoteCount.compareTo(a.quoteCount);
        if (byCount != 0) return byCount;
        return a.authorName.compareTo(b.authorName);
      });
    return ranked.take(limit).toList(growable: false);
  }

  String _buildLibraryFocusLine({
    required QuoteService service,
    required List<QuoteModel> focusQuotes,
    required List<String> topThemes,
    required List<_LibraryAuthorSignal> topAuthors,
    required int savedCount,
    required int likedCount,
  }) {
    if (focusQuotes.isEmpty) {
      return 'Start saving lines and the library will begin forming its own character.';
    }

    final List<String> themeLabels = topThemes
        .take(3)
        .map((theme) => service.toTitleCase(theme))
        .toList(growable: false);
    final List<String> authorLabels = topAuthors
        .take(2)
        .map((author) => author.authorName)
        .toList(growable: false);

    final countPhrase = savedCount > 0 && likedCount > 0
        ? '$savedCount saved and $likedCount liked lines'
        : savedCount > 0
        ? '$savedCount saved lines'
        : '$likedCount liked lines';

    if (themeLabels.isNotEmpty && authorLabels.isNotEmpty) {
      return '$countPhrase shaped around ${_joinReadable(themeLabels)} and the voices of ${_joinReadable(authorLabels)}.';
    }
    if (themeLabels.isNotEmpty) {
      return '$countPhrase gathered around ${_joinReadable(themeLabels)}.';
    }
    if (authorLabels.isNotEmpty) {
      return '$countPhrase anchored by ${_joinReadable(authorLabels)}.';
    }
    return '$countPhrase preserved as a personal archive you can return to at any time.';
  }

  List<_LibraryRecommendation> _buildRecommendations({
    required List<QuoteModel> quotes,
    required Set<String> savedIds,
    required Set<String> likedIds,
    required List<String> topThemes,
    required List<_LibraryAuthorSignal> topAuthors,
    required QuoteService service,
  }) {
    final themeSet = topThemes.take(4).toSet();
    final authorSet = topAuthors
        .take(3)
        .map((author) => author.authorKey)
        .toSet();
    final ranked = <_LibraryRecommendation>[];

    for (final quote in quotes) {
      if (savedIds.contains(quote.id) || likedIds.contains(quote.id)) {
        continue;
      }

      var score = 0.0;
      String? reason;
      for (final tag in quote.revisedTags) {
        final normalized = tag.trim().toLowerCase();
        if (themeSet.contains(normalized)) {
          score += 40;
          reason ??= 'Matches ${service.toTitleCase(normalized)}';
        }
      }

      final authorKey = normalizeAuthorKey(
        quote.canonicalAuthor.isNotEmpty ? quote.canonicalAuthor : quote.author,
      );
      if (authorSet.contains(authorKey)) {
        score += 52;
        reason ??= 'Another voice from ${quote.author}';
      }

      score +=
          (quote.likesCount * 0.12) +
          (quote.savesCount * 0.18) +
          (quote.popularityScore * 0.04);

      if (score <= 0 && (themeSet.isNotEmpty || authorSet.isNotEmpty)) {
        continue;
      }

      ranked.add(
        _LibraryRecommendation(
          quote: quote,
          reason: reason ?? 'Outside your current shelves',
          score: score,
        ),
      );
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isNotEmpty) {
      return ranked.take(8).toList(growable: false);
    }

    return quotes
        .where(
          (quote) =>
              !savedIds.contains(quote.id) && !likedIds.contains(quote.id),
        )
        .take(6)
        .map(
          (quote) => _LibraryRecommendation(
            quote: quote,
            reason: 'Fresh for your archive',
            score: 0,
          ),
        )
        .toList(growable: false);
  }

  List<_LibraryCollectionSummary> _buildCollectionSummaries({
    required List<QuoteModel> quotes,
    required Set<String> availableSavedIds,
    required Set<String> availableQuoteIds,
    required CollectionsState collections,
    required CollectionsNotifier collectionsNotifier,
    required QuoteService service,
  }) {
    final summaries = <_LibraryCollectionSummary>[
      _LibraryCollectionSummary(
        id: allSavedCollectionId,
        name: 'All Saved',
        count: availableSavedIds.length,
        subtitle: availableSavedIds.isEmpty
            ? 'Your main archive is waiting for its first line.'
            : 'Every quote you decided to keep lives here.',
        accentLabel: null,
        collection: null,
      ),
    ];
    if (availableSavedIds.isNotEmpty) {
      final savedThemes = _topThemes(
        _quotesForIds(quotes, availableSavedIds),
        limit: 1,
      );
      summaries[0] = _LibraryCollectionSummary(
        id: allSavedCollectionId,
        name: 'All Saved',
        count: availableSavedIds.length,
        subtitle: 'Every quote you decided to keep lives here.',
        accentLabel: savedThemes.isEmpty
            ? null
            : service.toTitleCase(savedThemes.first),
        collection: null,
      );
    }

    for (final collection in collections.collections) {
      final ids = collectionsNotifier
          .quoteIdsForCollection(collection.id)
          .toSet()
          .intersection(availableQuoteIds);
      final collectionQuotes = _quotesForIds(quotes, ids);
      final accent = _topThemes(collectionQuotes, limit: 1);
      summaries.add(
        _LibraryCollectionSummary(
          id: collection.id,
          name: collection.name,
          count: ids.length,
          subtitle: ids.isEmpty
              ? 'An empty shelf, ready for a point of view.'
              : ids.length == 1
              ? '1 kept line on this shelf.'
              : '${ids.length} kept lines on this shelf.',
          accentLabel: accent.isEmpty
              ? null
              : service.toTitleCase(accent.first),
          collection: collection,
        ),
      );
    }

    return summaries;
  }

  String _selectedCollectionName(CollectionsState collections) {
    if (collections.selectedCollectionId == allSavedCollectionId) {
      return 'All Saved';
    }
    for (final collection in collections.collections) {
      if (collection.id == collections.selectedCollectionId) {
        return collection.name;
      }
    }
    return 'All Saved';
  }

  String _joinReadable(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} and ${values.last}';
    return '${values[0]}, ${values[1]}, and ${values[2]}';
  }

  Future<void> _showCreateCollectionDialog(BuildContext context) async {
    await showCreateCollectionSheet(
      context,
      ref,
      title: 'Create a new shelf',
      description: 'Name a dedicated space for a specific train of thought.',
      hintText: 'Shelf name',
    );
  }

  Future<void> _showCollectionActions(
    BuildContext context,
    QuoteCollection collection,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FlowSpace.md),
            child: PremiumSurface(
              radius: FlowRadii.xl,
              blurSigma: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Rename shelf'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _showRenameCollectionDialog(context, collection);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Delete shelf'),
                    onTap: () async {
                      await ref
                          .read(collectionsProvider.notifier)
                          .deleteCollection(collection.id);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRenameCollectionDialog(
    BuildContext context,
    QuoteCollection collection,
  ) async {
    final controller = TextEditingController(text: collection.name);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
          title: const Text('Rename shelf'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Shelf name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(collectionsProvider.notifier)
                    .renameCollection(collection.id, controller.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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

double _libraryCommandDeckExtent(
  FlowLayoutInfo layout, {
  required bool hasFocusedShelf,
}) {
  if (hasFocusedShelf) {
    return layout.isCompact ? 168 : 152;
  }
  return layout.isCompact ? 106 : 96;
}

class _LibraryAuthorSignal {
  const _LibraryAuthorSignal({
    required this.authorKey,
    required this.authorName,
    required this.quoteCount,
  });

  final String authorKey;
  final String authorName;
  final int quoteCount;
}

class _LibraryRecommendation {
  const _LibraryRecommendation({
    required this.quote,
    required this.reason,
    required this.score,
  });

  final QuoteModel quote;
  final String reason;
  final double score;
}

class _LibraryCollectionSummary {
  const _LibraryCollectionSummary({
    required this.id,
    required this.name,
    required this.count,
    required this.subtitle,
    required this.accentLabel,
    required this.collection,
  });

  final String id;
  final String name;
  final int count;
  final String subtitle;
  final String? accentLabel;
  final QuoteCollection? collection;
}

String _libraryDisplayLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.toLowerCase() == 'movies/series') return 'Movies/Series';
  return trimmed
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
      )
      .join(' ');
}

// ignore: unused_element
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
    final currentBadge = _badgeForCount(scrolledCount);
    final badges = _visibleBadges(scrolledCount);
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
              (colors?.accent ?? Colors.white).withValues(alpha: 0.2),
              (colors?.surface ?? Colors.black).withValues(alpha: 0.58),
              (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.84),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.24,
                      ),
                      border: Border.all(
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Icon(
                      currentBadge.icon,
                      size: 20,
                      color: colors?.accent ?? Colors.white,
                    ),
                  ),
                  const SizedBox(width: FlowSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARCHIVE PROGRESS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors?.accent.withValues(alpha: 0.84),
                                letterSpacing: 0.68,
                              ),
                        ),
                        Text(
                          '${currentBadge.title} · $rankTitle',
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
                        const SizedBox(height: 4),
                        Text(
                          currentBadge.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.96,
                                ),
                                height: 1.28,
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
              Wrap(
                spacing: FlowSpace.xs,
                runSpacing: FlowSpace.xs,
                children: [
                  for (final badge in badges)
                    _LibraryBadgePill(
                      badge: badge,
                      unlocked: scrolledCount >= badge.threshold,
                      active: badge.threshold == currentBadge.threshold,
                    ),
                ],
              ),
              const SizedBox(height: FlowSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.toDouble(),
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

class _LibraryTopHeader extends StatelessWidget {
  const _LibraryTopHeader({
    required this.controller,
    required this.focusNode,
    required this.selectedCollectionName,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String selectedCollectionName;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    final scopeLabel = selectedCollectionName == 'All Saved'
        ? 'Searches all saved quotes'
        : 'Searching inside $selectedCollectionName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Library',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: layout.isCompact ? 32 : null,
          ),
        ),
        const SizedBox(height: FlowSpace.xs),
        Text(
          'A private room for the ideas, voices, and convictions you keep returning to.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors?.textSecondary.withValues(alpha: 0.84),
            height: 1.45,
          ),
        ),
        const SizedBox(height: FlowSpace.md),
        _LibrarySearchHeader(
          key: const ValueKey<String>('library-search-field'),
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onClear: onClear,
        ),
        const SizedBox(height: FlowSpace.xs),
        Text(
          scopeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors?.textSecondary.withValues(alpha: 0.76),
            letterSpacing: 0.28,
          ),
        ),
      ],
    );
  }
}

class _PremiumLibraryAchievementPanel extends StatelessWidget {
  const _PremiumLibraryAchievementPanel({
    required this.scrolledCount,
    required this.savedCount,
    required this.likedCount,
    required this.collectionCount,
    required this.rankTitle,
    required this.nextMilestone,
    required this.previousMilestone,
    required this.focusLine,
    required this.topThemes,
    required this.topAuthors,
    this.selectedCollectionName,
  });

  final int scrolledCount;
  final int savedCount;
  final int likedCount;
  final int collectionCount;
  final String rankTitle;
  final int nextMilestone;
  final int previousMilestone;
  final String focusLine;
  final List<String> topThemes;
  final List<_LibraryAuthorSignal> topAuthors;
  final String? selectedCollectionName;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final layout = FlowLayoutInfo.of(context);
    final nextSavedGoal = savedCount < 25 ? 25 : ((savedCount ~/ 25) + 1) * 25;
    final previousSavedGoal = (nextSavedGoal - 25).clamp(0, nextSavedGoal);
    final savedSpan = (nextSavedGoal - previousSavedGoal).clamp(1, 1000000);
    final savedProgressed = (savedCount - previousSavedGoal).clamp(
      0,
      savedSpan,
    );
    final progress = savedProgressed / savedSpan;
    final remainingSaved = (nextSavedGoal - savedCount).clamp(0, nextSavedGoal);
    final readingProgress =
        (scrolledCount - previousMilestone).clamp(
          0,
          (nextMilestone - previousMilestone).clamp(1, 1000000),
        ) /
        (nextMilestone - previousMilestone).clamp(1, 1000000);
    final shelfLabel = selectedCollectionName?.trim();
    final visibleThemes = topThemes.take(4).toList(growable: false);
    final visibleAuthors = topAuthors
        .take(layout.isCompact ? 3 : 4)
        .toList(growable: false);
    final hasFocusedShelf = shelfLabel != null && shelfLabel != 'All Saved';
    final statusLine =
        '$rankTitle • $scrolledCount explored • ${nextMilestone - scrolledCount <= 0 ? 'milestone reached' : '${nextMilestone - scrolledCount} to next milestone'}';

    return PremiumSurface(
      radius: FlowRadii.xl,
      elevation: 2,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: FlowRadii.radiusXl,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (colors?.accent ?? Colors.white).withValues(alpha: 0.14),
              (colors?.surface ?? Colors.black).withValues(alpha: 0.78),
              (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.94),
            ],
            stops: const [0.0, 0.28, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.isCompact ? FlowSpace.md : FlowSpace.lg,
            layout.isCompact ? FlowSpace.md : FlowSpace.lg,
            layout.isCompact ? FlowSpace.md : FlowSpace.lg,
            layout.isCompact ? FlowSpace.md : FlowSpace.lg,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final gap = layout.fluid(min: 10, max: 14);
              final statColumns = layout.columnsFor(
                constraints.maxWidth,
                minTileWidth: wide ? 120 : 108,
                maxColumns: 3,
              );
              final statTileWidth = layout.tileWidthFor(
                constraints.maxWidth,
                columns: statColumns,
                gap: gap,
              );

              final narrative = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR SIGNAL',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors?.accent.withValues(alpha: 0.82),
                      letterSpacing: 0.88,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  AutoSizeText(
                    _libraryIdentityHeadline(topThemes, topAuthors),
                    maxLines: 1,
                    minFontSize: 24,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors?.textPrimary,
                      fontSize: layout.fluid(min: 30, max: 44),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    focusLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.92),
                      height: 1.5,
                    ),
                  ),
                  if (hasFocusedShelf) ...[
                    const SizedBox(height: FlowSpace.sm),
                    Text(
                      'Focused shelf: $shelfLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors?.textPrimary.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (visibleThemes.isNotEmpty) ...[
                    const SizedBox(height: FlowSpace.md),
                    Wrap(
                      spacing: FlowSpace.xs,
                      runSpacing: FlowSpace.xs,
                      children: [
                        for (final theme in visibleThemes)
                          PremiumPillChip(
                            label: _libraryDisplayLabel(theme),
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ],
              );

              final stats = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: wide ? statTileWidth : statTileWidth,
                        child: _ArchiveMetricCard(
                          label: 'Saved',
                          value: '$savedCount',
                        ),
                      ),
                      SizedBox(
                        width: wide ? statTileWidth : statTileWidth,
                        child: _ArchiveMetricCard(
                          label: 'Liked',
                          value: '$likedCount',
                        ),
                      ),
                      SizedBox(
                        width: wide ? statTileWidth : statTileWidth,
                        child: _ArchiveMetricCard(
                          label: 'Shelves',
                          value: '$collectionCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FlowSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.toDouble(),
                      minHeight: 4,
                      color: colors?.accent,
                      backgroundColor:
                          colors?.divider.withValues(alpha: 0.38) ??
                          Colors.white24,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    remainingSaved == 0
                        ? 'Shelf goal reached'
                        : '$remainingSaved more to reach $nextSavedGoal saved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              );

              final voices = visibleAuthors.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: FlowSpace.md),
                        Text(
                          'Recurring voices',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.82,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: FlowSpace.xs),
                        Wrap(
                          spacing: FlowSpace.xs,
                          runSpacing: FlowSpace.xs,
                          children: [
                            for (final author in visibleAuthors)
                              _LibraryVoiceChip(author: author),
                          ],
                        ),
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: narrative),
                        const SizedBox(width: FlowSpace.lg),
                        Expanded(flex: 4, child: stats),
                      ],
                    )
                  else ...[
                    narrative,
                    const SizedBox(height: FlowSpace.md),
                    stats,
                  ],
                  voices,
                  const SizedBox(height: FlowSpace.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: readingProgress.toDouble(),
                      minHeight: 2,
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.62,
                      ),
                      backgroundColor:
                          colors?.divider.withValues(alpha: 0.2) ??
                          Colors.white24,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    statusLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ArchiveMetricCard extends StatelessWidget {
  const _ArchiveMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.sm,
        FlowSpace.sm,
        FlowSpace.sm,
        FlowSpace.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (colors?.surface ?? Colors.black).withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.88),
              letterSpacing: 0.28,
            ),
          ),
          const SizedBox(height: 4),
          AutoSizeText(
            value,
            minFontSize: 18,
            maxLines: 1,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors?.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryVoiceChip extends StatelessWidget {
  const _LibraryVoiceChip({required this.author});

  final _LibraryAuthorSignal author;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Container(
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.xs,
        vertical: FlowSpace.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (colors?.surface ?? Colors.black).withValues(alpha: 0.44),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthorPortraitCircle(
            author: author.authorName,
            size: 24,
            interactive: false,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              author.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors?.textPrimary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySectionHeader extends StatelessWidget {
  const _LibrarySectionHeader({
    required this.title,
    required this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors?.accent.withValues(alpha: 0.78),
            letterSpacing: 0.76,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.84),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LibraryCollectionGallery extends StatelessWidget {
  const _LibraryCollectionGallery({
    required this.collections,
    required this.selectedCollectionId,
    required this.onSelectCollection,
    required this.onCreateCollection,
    required this.onCollectionActions,
  });

  final List<_LibraryCollectionSummary> collections;
  final String selectedCollectionId;
  final ValueChanged<String> onSelectCollection;
  final VoidCallback onCreateCollection;
  final ValueChanged<QuoteCollection> onCollectionActions;

  @override
  Widget build(BuildContext context) {
    final layout = FlowLayoutInfo.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LibrarySectionHeader(
          title: 'Shelves',
          eyebrow: 'CURATION',
          subtitle:
              'Shape your archive into moods, beliefs, and recurring questions.',
        ),
        const SizedBox(height: FlowSpace.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = layout.fluid(min: 8, max: 14);
            final columns = layout.columnsFor(
              constraints.maxWidth,
              minTileWidth: layout.isCompact ? 156 : 192,
              maxColumns: layout.isDesktop
                  ? 4
                  : layout.isTablet
                  ? 3
                  : 2,
            );
            final tileWidth = layout.tileWidthFor(
              constraints.maxWidth,
              columns: columns,
              gap: gap,
            );
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final collection in collections)
                  SizedBox(
                    width: tileWidth,
                    child: _LibraryCollectionCard(
                      key: ValueKey<String>('library-shelf-${collection.id}'),
                      collection: collection,
                      selected: selectedCollectionId == collection.id,
                      onTap: () => onSelectCollection(collection.id),
                      onMenu: collection.collection == null
                          ? null
                          : () => onCollectionActions(collection.collection!),
                    ),
                  ),
                SizedBox(
                  width: tileWidth,
                  child: _LibraryCreateShelfCard(onTap: onCreateCollection),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LibraryCollectionCard extends StatelessWidget {
  const _LibraryCollectionCard({
    super.key,
    required this.collection,
    required this.selected,
    required this.onTap,
    this.onMenu,
  });

  final _LibraryCollectionSummary collection;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onMenu,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.md,
            FlowSpace.sm,
            FlowSpace.md,
            FlowSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (selected
                        ? colors?.accent ?? Colors.white
                        : colors?.elevatedSurface ?? Colors.white)
                    .withValues(alpha: selected ? 0.14 : 0.08),
                (colors?.surface ?? Colors.black).withValues(
                  alpha: selected ? 0.74 : 0.56,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AutoSizeText(
                      collection.name,
                      minFontSize: 14,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: FlowSpace.xs),
                  if (onMenu != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        onPressed: onMenu,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: colors?.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FlowSpace.xs),
              Text(
                '${collection.count} kept',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colors?.accent.withValues(alpha: 0.92)
                      : colors?.textSecondary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                collection.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.82),
                  height: 1.36,
                ),
              ),
              if (collection.accentLabel != null) ...[
                const SizedBox(height: FlowSpace.sm),
                Text(
                  collection.accentLabel!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors?.accent.withValues(alpha: 0.76),
                    letterSpacing: 0.64,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryCreateShelfCard extends StatelessWidget {
  const _LibraryCreateShelfCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(FlowSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: (colors?.surface ?? Colors.black).withValues(alpha: 0.42),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_rounded, color: colors?.accent, size: 22),
              const SizedBox(height: FlowSpace.sm),
              Text(
                'New shelf',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: FlowSpace.xs),
              Text(
                'Start a new thread.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryCommandDeck extends StatelessWidget {
  const _LibraryCommandDeck({
    required this.isSavedMode,
    required this.selectedCollectionName,
    required this.availableSavedCount,
    required this.availableLikedCount,
    required this.onSelectSaved,
    required this.onSelectLiked,
    required this.onResetCollection,
  });

  final bool isSavedMode;
  final String selectedCollectionName;
  final int availableSavedCount;
  final int availableLikedCount;
  final VoidCallback onSelectSaved;
  final VoidCallback onSelectLiked;
  final VoidCallback onResetCollection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final hasFocusedShelf =
        isSavedMode && selectedCollectionName != 'All Saved';

    return Padding(
      padding: const EdgeInsets.only(bottom: FlowSpace.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: (colors?.surface ?? Colors.black).withValues(alpha: 0.74),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            FlowLayoutInfo.of(context).isCompact ? FlowSpace.sm : FlowSpace.md,
            FlowSpace.sm,
            FlowLayoutInfo.of(context).isCompact ? FlowSpace.sm : FlowSpace.md,
            FlowSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LibraryModeRow(
                isSavedMode: isSavedMode,
                onSelectSaved: onSelectSaved,
                onSelectLiked: onSelectLiked,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: FlowSpace.xs,
                runSpacing: FlowSpace.xs,
                children: [
                  _ReadingRoomMetaChip(
                    label: '$availableSavedCount saved',
                    subtle: !isSavedMode,
                  ),
                  _ReadingRoomMetaChip(
                    label: '$availableLikedCount liked',
                    subtle: isSavedMode,
                  ),
                ],
              ),
              if (hasFocusedShelf) ...[
                const SizedBox(height: 6),
                _FocusedShelfLine(
                  shelfName: selectedCollectionName,
                  onReset: onResetCollection,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySearchExperience extends StatelessWidget {
  const _LibrarySearchExperience({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.selectedCollectionName,
    required this.savedCount,
    required this.results,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onOpenQuote,
    required this.onCollections,
    required this.onToggleLiked,
    required this.onRemoveSaved,
    required this.likedQuoteIds,
    required this.onStatusMessage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final String selectedCollectionName;
  final int savedCount;
  final List<QuoteModel> results;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<QuoteModel> onOpenQuote;
  final ValueChanged<QuoteModel> onCollections;
  final ValueChanged<QuoteModel> onToggleLiked;
  final ValueChanged<QuoteModel> onRemoveSaved;
  final Set<String> likedQuoteIds;
  final ValueChanged<String> onStatusMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final scopeLabel = selectedCollectionName == 'All Saved'
        ? 'All saved quotes'
        : selectedCollectionName;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _LibraryTopHeader(
          controller: controller,
          focusNode: focusNode,
          selectedCollectionName: selectedCollectionName,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onClear: onClear,
        ),
        const SizedBox(height: FlowSpace.sm),
        if (query.isEmpty)
          PremiumSurface(
            radius: FlowRadii.lg,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FlowSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search the lines that shaped you',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    'Try a quote fragment, author, or tag. $savedCount saved quotes are indexed here, ready to bring back a mood, belief, or lesson you wanted to keep.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.84),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            results.isEmpty
                ? 'No matches in $scopeLabel'
                : '${results.length} matches in $scopeLabel',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.82),
              letterSpacing: 0.32,
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          if (results.isEmpty)
            PremiumSurface(
              radius: FlowRadii.lg,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: FlowSpace.sm),
                child: Text(
                  'No saved quotes match "$query". Try a different idea, voice, or tag.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            for (final quote in results.take(100)) ...[
              _LibraryQuoteTile(
                quote: quote,
                isSavedMode: true,
                shelfLabel: selectedCollectionName,
                onOpen: () => onOpenQuote(quote),
                onCollections: () async => onCollections(quote),
                isLiked: likedQuoteIds.contains(quote.id),
                onToggleLiked: () async => onToggleLiked(quote),
                onRemoveSaved: () async => onRemoveSaved(quote),
                onRemoveLiked: () async {},
                onStatusMessage: onStatusMessage,
              ),
              const SizedBox(height: FlowSpace.sm),
            ],
        ],
        const SizedBox(height: 120),
      ],
    );
  }
}

class _ReadingRoomMetaChip extends StatelessWidget {
  const _ReadingRoomMetaChip({required this.label, this.subtle = false});

  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color:
            (subtle
                    ? colors?.elevatedSurface ?? Colors.black
                    : colors?.surface ?? Colors.black)
                .withValues(alpha: subtle ? 0.46 : 0.62),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors?.textSecondary.withValues(alpha: subtle ? 0.86 : 0.94),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.24,
        ),
      ),
    );
  }
}

class _FocusedShelfLine extends StatelessWidget {
  const _FocusedShelfLine({required this.shelfName, required this.onReset});

  final String shelfName;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = Text(
          shelfName,
          maxLines: constraints.maxWidth < 360 ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors?.textPrimary.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        );

        final resetAction = TextButton(
          onPressed: onReset,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: colors?.accent,
          ),
          child: const Text('Show all'),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Focused shelf',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors?.textSecondary.withValues(alpha: 0.74),
                        letterSpacing: 0.48,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: FlowSpace.xs),
                  resetAction,
                ],
              ),
              const SizedBox(height: 2),
              summary,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Focused shelf  ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors?.textSecondary.withValues(alpha: 0.74),
                        letterSpacing: 0.48,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: shelfName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors?.textPrimary.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FlowSpace.sm),
            resetAction,
          ],
        );
      },
    );
  }
}

class _LibraryForYouShelf extends StatelessWidget {
  const _LibraryForYouShelf({
    required this.recommendations,
    required this.topThemes,
    required this.topAuthors,
    required this.onOpenQuote,
  });

  final List<_LibraryRecommendation> recommendations;
  final List<String> topThemes;
  final List<_LibraryAuthorSignal> topAuthors;
  final ValueChanged<QuoteModel> onOpenQuote;

  @override
  Widget build(BuildContext context) {
    final layout = FlowLayoutInfo.of(context);
    final useGrid = layout.isTablet;
    final subtitle = topThemes.isNotEmpty
        ? 'Built around ${_joinShelfThemes(topThemes)}.'
        : topAuthors.isNotEmpty
        ? 'Chosen around voices you return to when you want perspective.'
        : 'A quieter set of ideas to deepen the archive you are building.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LibrarySectionHeader(
          title: 'Aligned With You',
          eyebrow: 'DISCOVERY',
          subtitle: subtitle,
        ),
        const SizedBox(height: FlowSpace.sm),
        if (useGrid)
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = layout.fluid(min: 10, max: 16);
              final columns = layout.columnsFor(
                constraints.maxWidth,
                minTileWidth: 260,
                maxColumns: layout.isDesktop ? 3 : 2,
              );
              final tileWidth = layout.tileWidthFor(
                constraints.maxWidth,
                columns: columns,
                gap: gap,
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var index = 0; index < recommendations.length; index++)
                    SizedBox(
                      width: tileWidth,
                      child: _LibraryRecommendationCard(
                        recommendation: recommendations[index],
                        index: index,
                        onOpenQuote: onOpenQuote,
                      ),
                    ),
                ],
              );
            },
          )
        else
          SizedBox(
            height: layout.isCompact ? 224 : 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: FlowSpace.sm),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: layout.isCompact ? 236 : 264,
                  child: _LibraryRecommendationCard(
                    recommendation: recommendations[index],
                    index: index,
                    onOpenQuote: onOpenQuote,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

String _joinShelfThemes(List<String> themes) {
  final labels = themes
      .take(3)
      .map(_libraryDisplayLabel)
      .toList(growable: false);
  if (labels.isEmpty) return 'the archive you are building';
  if (labels.length == 1) return labels.first;
  if (labels.length == 2) return '${labels.first} and ${labels.last}';
  return '${labels[0]}, ${labels[1]}, and ${labels[2]}';
}

String _libraryIdentityHeadline(
  List<String> themes,
  List<_LibraryAuthorSignal> authors,
) {
  final labels = themes
      .take(2)
      .map(_libraryDisplayLabel)
      .toList(growable: false);
  if (labels.length == 2) {
    return '${labels[0]} and ${labels[1]} live here';
  }
  if (labels.length == 1) {
    return '${labels.first} keeps returning';
  }
  if (authors.isNotEmpty) {
    return '${authors.first.authorName} keeps the tone';
  }
  return 'Your inner library is taking shape';
}

class _LibraryRecommendationCard extends StatelessWidget {
  const _LibraryRecommendationCard({
    required this.recommendation,
    required this.index,
    required this.onOpenQuote,
  });

  final _LibraryRecommendation recommendation;
  final int index;
  final ValueChanged<QuoteModel> onOpenQuote;

  @override
  Widget build(BuildContext context) {
    final quote = recommendation.quote;
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onOpenQuote(quote),
        child: Ink(
          padding: const EdgeInsets.all(FlowSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (colors?.accent ?? Colors.white).withValues(alpha: 0.08),
                (colors?.surface ?? Colors.black).withValues(alpha: 0.52),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasBoundedHeight = constraints.hasBoundedHeight;
              final isTight = hasBoundedHeight && constraints.maxHeight < 214;
              final quoteLines = isTight ? 4 : 5;
              final quoteFontSize = layout.fluid(
                min: isTight ? 17.2 : 18.0,
                max: isTight ? 18.4 : 19.4,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PICK ${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors?.accent.withValues(alpha: 0.82),
                      letterSpacing: 0.64,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    quote.quote,
                    maxLines: quoteLines,
                    overflow: TextOverflow.ellipsis,
                    style: FlowTypography.quoteStyle(
                      context: context,
                      color: colors?.textPrimary ?? Colors.white,
                      fontSize: quoteFontSize,
                    ).copyWith(height: 1.24),
                  ),
                  SizedBox(
                    height: hasBoundedHeight ? FlowSpace.sm : FlowSpace.md,
                  ),
                  Text(
                    quote.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors?.textPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LibraryModeRow extends StatelessWidget {
  const _LibraryModeRow({
    required this.isSavedMode,
    required this.onSelectSaved,
    required this.onSelectLiked,
  });

  final bool isSavedMode;
  final VoidCallback onSelectSaved;
  final VoidCallback onSelectLiked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (colors?.elevatedSurface ?? Colors.black).withValues(
          alpha: 0.58,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegmentButton(
              key: const ValueKey<String>('library-mode-saved'),
              title: 'Saved',
              selected: isSavedMode,
              onTap: onSelectSaved,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeSegmentButton(
              key: const ValueKey<String>('library-mode-liked'),
              title: 'Liked',
              selected: !isSavedMode,
              onTap: onSelectLiked,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySearchHeader extends StatelessWidget {
  const _LibrarySearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FlowSpace.xs),
      child: PremiumSearchField(
        controller: controller,
        focusNode: focusNode,
        hintText: 'Search saved quotes, authors, or tags',
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onClear: onClear,
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: FlowDurations.regular,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.sm,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                (selected ? colors?.accent ?? Colors.white : Colors.transparent)
                    .withValues(alpha: selected ? 0.14 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected
                    ? colors?.textPrimary
                    : colors?.textSecondary.withValues(alpha: 0.92),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryPinnedToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _LibraryPinnedToolbarDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (colors?.surface ?? Colors.black).withValues(alpha: 0.96),
            (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.9),
          ],
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _LibraryPinnedToolbarDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
  }
}

class _LibraryMessageState extends StatelessWidget {
  const _LibraryMessageState({
    required this.title,
    required this.body,
    this.loading = false,
  });

  final String title;
  final String body;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Center(
      child: PremiumSurface(
        radius: FlowRadii.xl,
        elevation: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: FlowSpace.md),
            ],
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: colors?.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FlowSpace.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.92),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryBadgeTier {
  const _LibraryBadgeTier({
    required this.threshold,
    required this.title,
    required this.caption,
    required this.icon,
  });

  final int threshold;
  final String title;
  final String caption;
  final IconData icon;
}

const List<_LibraryBadgeTier> _libraryBadgeTiers = <_LibraryBadgeTier>[
  _LibraryBadgeTier(
    threshold: 0,
    title: 'Explorer',
    caption: 'The journey has started.',
    icon: Icons.explore_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 10,
    title: 'Rising',
    caption: 'A new rhythm is forming.',
    icon: Icons.rocket_launch_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 25,
    title: 'Flow',
    caption: 'Scrolling becomes instinct.',
    icon: Icons.auto_awesome_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 50,
    title: 'Voyager',
    caption: 'Premium miles in the quote universe.',
    icon: Icons.travel_explore_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 100,
    title: 'Night Scroller',
    caption: 'A collector with real depth.',
    icon: Icons.nights_stay_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 250,
    title: 'Deep Reader',
    caption: 'Taste sharpened by volume.',
    icon: Icons.menu_book_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 500,
    title: 'Master',
    caption: 'A serious curator of quotes.',
    icon: Icons.workspace_premium_rounded,
  ),
  _LibraryBadgeTier(
    threshold: 1000,
    title: 'Legend',
    caption: 'Hall-of-fame status unlocked.',
    icon: Icons.emoji_events_rounded,
  ),
];

_LibraryBadgeTier _badgeForCount(int count) {
  return _libraryBadgeTiers.lastWhere(
    (badge) => count >= badge.threshold,
    orElse: () => _libraryBadgeTiers.first,
  );
}

List<_LibraryBadgeTier> _visibleBadges(int count) {
  final current = _badgeForCount(count);
  final index = _libraryBadgeTiers.indexOf(current);
  final start = (index - 1).clamp(0, _libraryBadgeTiers.length - 1);
  final end = (index + 3).clamp(1, _libraryBadgeTiers.length);
  return _libraryBadgeTiers.sublist(start, end);
}

class _LibraryBadgePill extends StatelessWidget {
  const _LibraryBadgePill({
    required this.badge,
    required this.unlocked,
    required this.active,
  });

  final _LibraryBadgeTier badge;
  final bool unlocked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.sm,
        vertical: FlowSpace.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color:
            (active
                    ? colors?.accent ?? Colors.white
                    : unlocked
                    ? colors?.elevatedSurface ?? Colors.white
                    : colors?.surface ?? Colors.black)
                .withValues(
                  alpha: active
                      ? 0.22
                      : unlocked
                      ? 0.72
                      : 0.52,
                ),
        border: Border.all(
          color:
              (active
                      ? colors?.accent ?? Colors.white
                      : colors?.divider ?? Colors.white24)
                  .withValues(alpha: active ? 0.8 : 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.icon,
            size: 13,
            color: active
                ? colors?.accent
                : unlocked
                ? colors?.textPrimary
                : colors?.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            badge.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: unlocked
                  ? colors?.textPrimary
                  : colors?.textSecondary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryQuoteTile extends StatelessWidget {
  const _LibraryQuoteTile({
    required this.quote,
    required this.isSavedMode,
    required this.shelfLabel,
    required this.onOpen,
    required this.onCollections,
    required this.isLiked,
    required this.onToggleLiked,
    required this.onRemoveSaved,
    required this.onRemoveLiked,
    required this.onStatusMessage,
  });

  final QuoteModel quote;
  final bool isSavedMode;
  final String shelfLabel;
  final VoidCallback onOpen;
  final Future<void> Function() onCollections;
  final bool isLiked;
  final Future<void> Function() onToggleLiked;
  final Future<void> Function() onRemoveSaved;
  final Future<void> Function() onRemoveLiked;
  final ValueChanged<String> onStatusMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    final sectionLabel = isSavedMode
        ? (shelfLabel == 'All Saved' ? null : shelfLabel.toUpperCase())
        : 'LIKED';
    final metaText = quote.revisedTags.isEmpty
        ? quote.author
        : '${quote.author} / ${_libraryDisplayLabel(quote.revisedTags.first)}';

    final destructiveLabel = isSavedMode
        ? 'Removed from saved'
        : 'Removed from liked';

    return Dismissible(
      key: ValueKey('library-${quote.id}-${isSavedMode ? 'saved' : 'liked'}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          await onCollections();
          onStatusMessage('Collection actions opened');
          return false;
        }

        HapticFeedback.mediumImpact();
        if (isSavedMode) {
          await onRemoveSaved();
        } else {
          await onRemoveLiked();
        }
        onStatusMessage(destructiveLabel);
        return true;
      },
      background: _LibrarySwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.bookmark_add_rounded,
        label: 'Collect',
        accent: colors?.accentSecondary ?? Colors.white,
      ),
      secondaryBackground: _LibrarySwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_outline_rounded,
        label: 'Remove',
        accent: Colors.redAccent.shade100,
        destructive: true,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Ink(
            padding: EdgeInsets.fromLTRB(
              layout.isCompact ? FlowSpace.sm : FlowSpace.md,
              FlowSpace.sm,
              FlowSpace.sm,
              FlowSpace.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (colors?.surface ?? Colors.black).withValues(alpha: 0.58),
                  (colors?.elevatedSurface ?? Colors.black).withValues(
                    alpha: 0.34,
                  ),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AuthorPortraitCircle(
                    author: quote.author,
                    size: layout.isCompact ? 38 : 42,
                  ),
                ),
                const SizedBox(width: FlowSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sectionLabel != null) ...[
                        Text(
                          sectionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors?.accent.withValues(alpha: 0.8),
                                letterSpacing: 0.56,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        quote.quote,
                        maxLines: layout.isCompact ? 4 : 5,
                        overflow: TextOverflow.ellipsis,
                        style: FlowTypography.quoteStyle(
                          context: context,
                          color: colors?.textPrimary ?? Colors.white,
                          fontSize: layout.fluid(min: 15.2, max: 17.1),
                        ).copyWith(height: 1.32),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors?.textSecondary.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FlowSpace.xs),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        onPressed: () => unawaited(onToggleLiked()),
                        tooltip: isLiked ? 'Liked' : 'Like quote',
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked
                              ? colors?.accent
                              : colors?.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: colors?.textSecondary,
                        size: 18,
                      ),
                      onSelected: (v) {
                        if (v == 'collections') {
                          unawaited(onCollections());
                          onStatusMessage('Collection actions opened');
                        }
                        if (v == 'remove_saved') {
                          unawaited(onRemoveSaved());
                          onStatusMessage('Removed from saved');
                        }
                        if (v == 'remove_liked') {
                          unawaited(onRemoveLiked());
                          onStatusMessage('Removed from liked');
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
                                value: 'collections',
                                child: Text('Add to collection'),
                              ),
                              PopupMenuItem(
                                value: 'remove_liked',
                                child: Text('Remove liked'),
                              ),
                            ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibrarySwipeBackground extends StatelessWidget {
  const _LibrarySwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.accent,
    this.destructive = false,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: FlowSpace.lg),
      decoration: BoxDecoration(
        borderRadius: FlowRadii.radiusLg,
        gradient: LinearGradient(
          begin: alignment == Alignment.centerLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: alignment == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: [
            accent.withValues(alpha: destructive ? 0.24 : 0.18),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) Text(label),
          if (alignment == Alignment.centerRight)
            const SizedBox(width: FlowSpace.xs),
          Icon(icon, color: accent),
          if (alignment == Alignment.centerLeft)
            const SizedBox(width: FlowSpace.xs),
          if (alignment == Alignment.centerLeft) Text(label),
        ],
      ),
    );
  }
}
