import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_search/search_result_groups.dart';
import '../../features/v3_search/search_service.dart';
import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_author_discovery_card.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/premium/premium_search_field.dart';

class AuthorsIndexScreen extends ConsumerStatefulWidget {
  const AuthorsIndexScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<AuthorsIndexScreen> createState() => _AuthorsIndexScreenState();
}

class _AuthorsIndexScreenState extends ConsumerState<AuthorsIndexScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial.toLowerCase();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authorsAsync = ref.watch(authorCatalogProvider);
    final quotesAsync = ref.watch(allQuotesProvider);
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
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
                                  'Authors',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Browse every voice in your library.',
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
                      PremiumSearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hintText: 'Search authors',
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: FlowSpace.md),
                      Expanded(
                        child: quotesAsync.when(
                          data: (quotes) => authorsAsync.when(
                            data: (authors) {
                              final normalizedQuery = _query
                                  .trim()
                                  .toLowerCase();
                              final filtered = normalizedQuery.isEmpty
                                  ? authors
                                  : searchAuthorMatches(
                                      normalizedQuery,
                                      SearchService(quotes).searchQuotes(
                                        normalizedQuery,
                                        limit: 120,
                                      ),
                                      authors,
                                      limit: authors.length,
                                    );

                              if (filtered.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No authors found.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                );
                              }

                              return GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: layout.isDesktop
                                          ? 280
                                          : layout.isTablet
                                          ? 260
                                          : 220,
                                      crossAxisSpacing: FlowSpace.sm,
                                      mainAxisSpacing: FlowSpace.sm,
                                      childAspectRatio: layout.isDesktop
                                          ? 0.78
                                          : layout.isTablet
                                          ? 0.72
                                          : 0.68,
                                    ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    PremiumAuthorDiscoveryCard(
                                      authorName: filtered[index].authorName,
                                      rank: index + 1,
                                      quoteCount: filtered[index].quoteCount,
                                      variant: PremiumAuthorDiscoveryCardVariant
                                          .grid,
                                      animationIndex: index,
                                      onTap: () => context.push(
                                        '/authors/${Uri.encodeComponent(filtered[index].authorKey)}?label=${Uri.encodeComponent(filtered[index].authorName)}',
                                      ),
                                    ),
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stack) =>
                                Center(child: Text('Failed to load: $error')),
                          ),
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
