import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_author_discovery_card.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/premium/premium_search_field.dart';

class AttributionSourcesIndexScreen extends ConsumerStatefulWidget {
  const AttributionSourcesIndexScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<AttributionSourcesIndexScreen> createState() =>
      _AttributionSourcesIndexScreenState();
}

class _AttributionSourcesIndexScreenState
    extends ConsumerState<AttributionSourcesIndexScreen> {
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
    final sourcesAsync = ref.watch(attributionSourceCatalogProvider);
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const EditorialBackground(seed: 79),
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
                                  'Sources',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Proverbs, sayings, slogans, and anonymous voices.',
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
                        hintText: 'Search proverb or source',
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: FlowSpace.md),
                      Expanded(
                        child: sourcesAsync.when(
                          data: (sources) {
                            final normalizedQuery = _query.trim().toLowerCase();
                            final filtered = normalizedQuery.isEmpty
                                ? sources
                                : sources
                                      .where(
                                        (entry) =>
                                            entry.sourceName
                                                .toLowerCase()
                                                .contains(normalizedQuery) ||
                                            entry.kindLabel
                                                .toLowerCase()
                                                .contains(normalizedQuery),
                                      )
                                      .toList(growable: false);

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  'No sources found.',
                                  style: Theme.of(context).textTheme.bodyLarge,
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
                              itemBuilder: (context, index) {
                                final source = filtered[index];
                                return PremiumAuthorDiscoveryCard(
                                  authorName: source.sourceName,
                                  rank: index + 1,
                                  quoteCount: source.quoteCount,
                                  descriptorOverride: sourceStyleDescriptor(
                                    source.sourceName,
                                  ),
                                  roleLabelOverride: source.kindLabel,
                                  fetchProfile: false,
                                  variant:
                                      PremiumAuthorDiscoveryCardVariant.grid,
                                  animationIndex: index,
                                  onTap: () => context.push(
                                    '/sources/${Uri.encodeComponent(source.sourceKey)}?label=${Uri.encodeComponent(source.sourceName)}',
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
