import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../services/author_wiki_service.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/author_portrait_circle.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/quote_priority_list_tile.dart';

final _authorHeroProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, authorName) async {
      final normalized = authorName.trim();
      if (normalized.isEmpty) return null;
      return ref.read(authorWikiServiceProvider).fetchAuthor(normalized);
    });

class AuthorQuotesScreen extends ConsumerWidget {
  const AuthorQuotesScreen({
    super.key,
    required this.authorKey,
    required this.authorName,
  });

  final String authorKey;
  final String authorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(quoteServiceProvider);
    final layout = FlowLayoutInfo.of(context);
    final authorProfileAsync = ref.watch(
      _authorHeroProfileProvider(authorName),
    );
    final quotesAsync = ref.watch(
      quotesByFilterProvider(QuoteViewerFilter(type: 'author', tag: authorKey)),
    );

    return Scaffold(
      floatingActionButton: quotesAsync.maybeWhen(
        data: (quotes) => quotes.isEmpty
            ? null
            : FloatingActionButton.small(
                onPressed: () => context.push(
                  '/viewer/author/${Uri.encodeComponent(authorKey)}',
                ),
                child: const Icon(Icons.swipe_up_alt_rounded),
              ),
        orElse: () => null,
      ),
      body: Stack(
        children: [
          const EditorialBackground(),
          quotesAsync.when(
            data: (quotes) {
              final colors = Theme.of(
                context,
              ).extension<FlowThemeTokens>()?.colors;
              return SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.maxContentWidth,
                    ),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          expandedHeight: layout.isCompact
                              ? 328
                              : layout.fluid(min: 304, max: 360),
                          backgroundColor: (colors?.surface ?? Colors.black)
                              .withValues(alpha: 0.88),
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          toolbarHeight: layout.isCompact ? 76 : 82,
                          leadingWidth: 74,
                          titleSpacing: 0,
                          title: const SizedBox.shrink(),
                          flexibleSpace: FlexibleSpaceBar(
                            collapseMode: CollapseMode.pin,
                            background: _AuthorHero(
                              authorName: authorName,
                              quoteCount: quotes.length,
                              descriptor: _authorDescriptor(
                                authorProfileAsync.valueOrNull?.summary,
                              ),
                            ),
                          ),
                          leading: Padding(
                            padding: EdgeInsets.only(
                              left: layout.horizontalPadding,
                              top: 10,
                            ),
                            child: PremiumIconPillButton(
                              icon: Icons.arrow_back_rounded,
                              compact: true,
                              onTap: context.pop,
                            ),
                          ),
                        ),
                        if (quotes.isEmpty) ...[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No quotes found for $authorName',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ] else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                layout.horizontalPadding,
                                18,
                                layout.horizontalPadding,
                                14,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final chip = PremiumPillChip(
                                    label: '${quotes.length} entries',
                                    compact: true,
                                    icon: Icons.auto_stories_rounded,
                                  );

                                  if (constraints.maxWidth < 320) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Top quotes',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: FlowSpace.xs),
                                        chip,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Top quotes',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      chip,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              layout.horizontalPadding,
                              0,
                              layout.horizontalPadding,
                              layout.dockBodyInset + 48,
                            ),
                            sliver: SliverList.separated(
                              itemCount: quotes.length,
                              itemBuilder: (context, index) {
                                final quote = quotes[index];
                                return _AuthorQuoteCard(
                                  quote: quote,
                                  service: service,
                                  onTap: () => context.push(
                                    '/viewer/author/${Uri.encodeComponent(authorKey)}?quoteId=${quote.id}',
                                  ),
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Failed to load: $error')),
          ),
        ],
      ),
    );
  }
}

class _AuthorHero extends StatelessWidget {
  const _AuthorHero({
    required this.authorName,
    required this.quoteCount,
    this.descriptor,
  });

  final String authorName;
  final int quoteCount;
  final String? descriptor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (colors?.surface ?? Colors.black).withValues(alpha: 0.9),
            (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -48,
            left: -12,
            right: -12,
            child: IgnorePointer(
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      (colors?.accent ?? Colors.white).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = constraints.maxHeight;
              final isTight = heroHeight < 320;
              final isVeryTight = heroHeight < 300;
              final detail = descriptor?.trim();
              final hasDetail = detail != null && detail.isNotEmpty;
              final portraitSize = isVeryTight
                  ? layout.fluid(
                      min: hasDetail ? 70 : 74,
                      max: hasDetail ? 86 : 90,
                    )
                  : isTight
                  ? layout.fluid(
                      min: hasDetail ? 80 : 84,
                      max: hasDetail ? 96 : 102,
                    )
                  : layout.fluid(
                      min: hasDetail ? 90 : 96,
                      max: hasDetail ? 114 : 122,
                    );
              final heroTitleSize = isVeryTight
                  ? layout.fluid(min: 28, max: 38)
                  : isTight
                  ? layout.fluid(min: 30, max: 42)
                  : layout.fluid(min: 32, max: 48);
              final topInset = isVeryTight
                  ? 72.0
                  : isTight
                  ? 82.0
                  : layout.fluid(min: 92, max: 108);
              final bottomInset = isTight ? 18.0 : 28.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.horizontalPadding,
                  topInset,
                  layout.horizontalPadding,
                  bottomInset,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AuthorPortraitCircle(
                      author: authorName,
                      size: portraitSize,
                      interactive: false,
                    ),
                    SizedBox(height: isTight ? 10 : FlowSpace.md),
                    AutoSizeText(
                      authorName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      minFontSize: isTight ? 20 : 24,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: heroTitleSize),
                    ),
                    if (hasDetail) ...[
                      SizedBox(height: isVeryTight ? 4 : 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: layout.isCompact ? 320 : 420,
                        ),
                        child: Text(
                          detail,
                          maxLines: isVeryTight ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.28,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                    SizedBox(height: hasDetail ? 6 : 6),
                    Text(
                      '$quoteCount curated quotes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors?.textSecondary.withValues(alpha: 0.84),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String? _authorDescriptor(String? summary) {
  final source = summary?.trim() ?? '';
  if (source.isEmpty) return null;

  var line = source
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .trim();
  if (line.isEmpty) return null;

  final sentenceMatch = RegExp(r'^(.+?[.!?])(?:\s|$)').firstMatch(line);
  if (sentenceMatch != null) {
    line = sentenceMatch.group(1) ?? line;
  }

  final roleMatch = RegExp(
    r'\b(?:was|is)\b\s+(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (roleMatch != null) {
    line = roleMatch.group(1) ?? line;
  }

  line = line
      .split(
        RegExp(
          r',| who | whose | best known | widely regarded | remembered | notable for | noted for ',
          caseSensitive: false,
        ),
      )
      .first
      .replaceFirst(RegExp(r'^(an?|the)\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .trim();

  if (line.isEmpty) return null;
  if (line.length <= 64) return line;

  final words = line.split(' ');
  final buffer = StringBuffer();
  for (final word in words) {
    final nextLength = buffer.isEmpty
        ? word.length
        : buffer.length + word.length + 1;
    if (nextLength > 64) break;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
  }
  final compact = buffer.toString().trim();
  return compact.isEmpty ? null : compact;
}

class _AuthorQuoteCard extends StatelessWidget {
  const _AuthorQuoteCard({
    required this.quote,
    required this.service,
    required this.onTap,
  });

  final QuoteModel quote;
  final QuoteService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = quote.revisedTags.isEmpty
        ? null
        : service.toTitleCase(quote.revisedTags.first);
    return QuotePriorityListTile(
      quote: quote,
      onTap: onTap,
      metaLabel: meta,
      showAuthorName: false,
    );
  }
}
