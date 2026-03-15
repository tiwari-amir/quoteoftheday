import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_model.dart';
import '../providers/liked_quotes_provider.dart';
import '../providers/saved_quotes_provider.dart';
import '../theme/design_tokens.dart';
import '../theme/flow_responsive.dart';
import 'author_portrait_circle.dart';

class QuotePriorityListTile extends ConsumerWidget {
  const QuotePriorityListTile({
    super.key,
    required this.quote,
    required this.onTap,
    this.metaLabel,
    this.showAuthorName = true,
  });

  final QuoteModel quote;
  final VoidCallback onTap;
  final String? metaLabel;
  final bool showAuthorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    final isLiked = ref.watch(
      likedQuoteIdsProvider.select((ids) => ids.contains(quote.id)),
    );
    final isSaved = ref.watch(
      savedQuoteIdsProvider.select((ids) => ids.contains(quote.id)),
    );

    final secondaryParts = <String>[];
    final author = quote.author.trim();
    if (showAuthorName && author.isNotEmpty) {
      secondaryParts.add(author);
    }
    final extra = metaLabel?.trim() ?? '';
    if (extra.isNotEmpty) {
      secondaryParts.add(extra);
    }
    final secondaryLine = secondaryParts
        .where((part) => part.isNotEmpty)
        .join(' - ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            layout.isCompact ? 10 : 12,
            0,
            layout.isCompact ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AuthorPortraitCircle(
                  author: quote.author,
                  size: layout.isCompact ? 36 : 40,
                  interactive: false,
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.quote,
                        maxLines: layout.isCompact ? 6 : 7,
                        overflow: TextOverflow.ellipsis,
                        style: FlowTypography.quoteStyle(
                          context: context,
                          color: colors?.textPrimary ?? Colors.white,
                          fontSize: layout.fluid(min: 16.6, max: 18.8),
                        ).copyWith(height: 1.46, fontWeight: FontWeight.w500),
                      ),
                      if (secondaryLine.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          secondaryLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.76,
                                ),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.12,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: FlowSpace.xs),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuoteRowActionButton(
                      tooltip: isLiked ? 'Liked' : 'Like quote',
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked
                          ? colors?.accent ?? Colors.white
                          : colors?.textSecondary ?? Colors.white70,
                      onPressed: () => ref
                          .read(likedQuoteIdsProvider.notifier)
                          .toggle(quote.id),
                    ),
                    const SizedBox(height: 2),
                    _QuoteRowActionButton(
                      tooltip: isSaved ? 'Saved' : 'Save quote',
                      icon: isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: isSaved
                          ? colors?.accent ?? Colors.white
                          : colors?.textSecondary ?? Colors.white70,
                      onPressed: () => unawaited(
                        ref
                            .read(savedQuoteIdsProvider.notifier)
                            .toggle(quote.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteRowActionButton extends StatelessWidget {
  const _QuoteRowActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        splashRadius: 15,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: color),
      ),
    );
  }
}
