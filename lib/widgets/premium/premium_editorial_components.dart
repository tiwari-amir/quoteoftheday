import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../glass_card.dart';
import '../scale_tap.dart';
import 'premium_components.dart';

class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.actionLabel,
    this.onActionTap,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors?.accentSecondary.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                ],
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors?.textSecondary.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            PremiumIconPillButton(
              icon: Icons.arrow_forward_rounded,
              label: actionLabel,
              compact: true,
              onTap: onActionTap!,
            ),
        ],
      ),
    );
  }
}

class EditorialStatPill extends StatelessWidget {
  const EditorialStatPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;

    return PremiumGlassCard(
      borderRadius: 999,
      elevation: 1,
      tone: PremiumGlassTone.subtle,
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.md,
        vertical: FlowSpace.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: colors?.accentSecondary.withValues(alpha: 0.92),
            ),
            const SizedBox(width: FlowSpace.xs),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors?.textPrimary),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class EditorialActionTile extends StatelessWidget {
  const EditorialActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.width,
    this.height = 144,
    this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final double? width;
  final double height;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final layout = FlowLayoutInfo.of(context);
    final effectiveHeight = layout.isCompact ? height - 16 : height;

    Widget card = SizedBox(
      width: width,
      height: effectiveHeight,
      child: PremiumGlassCard(
        borderRadius: 32,
        elevation: 2,
        tone: PremiumGlassTone.standard,
        padding: EdgeInsets.all(layout.isCompact ? FlowSpace.md : FlowSpace.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactLayout =
                constraints.maxWidth < 150 || constraints.maxHeight < 130;

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (gradients?.accentStart ?? colors?.accent ?? Colors.white)
                        .withValues(alpha: 0.16),
                    (colors?.surface ?? Colors.black).withValues(alpha: 0.18),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  isCompactLayout ? FlowSpace.xs : FlowSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        icon,
                        color: colors?.accentSecondary.withValues(alpha: 0.92),
                        size: isCompactLayout ? 18 : 20,
                      ),
                    ),
                    SizedBox(height: isCompactLayout ? 6 : FlowSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: isCompactLayout ? 14 : null,
                                ),
                          ),
                          const SizedBox(height: FlowSpace.xs),
                          Text(
                            subtitle,
                            maxLines: isCompactLayout ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: isCompactLayout ? 11 : null,
                                  color: colors?.textSecondary.withValues(
                                    alpha: 0.94,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (footer != null) ...[
                      SizedBox(
                        height: isCompactLayout ? FlowSpace.sm : FlowSpace.md,
                      ),
                      Flexible(fit: FlexFit.loose, child: footer!),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (onTap != null) {
      card = ScaleTap(onTap: onTap!, child: card);
    }

    return card;
  }
}

class EditorialQuoteTile extends StatelessWidget {
  const EditorialQuoteTile({
    super.key,
    required this.quote,
    required this.author,
    this.eyebrow,
    this.footer,
    this.onTap,
    this.minHeight = 220,
  });

  final String quote;
  final String author;
  final String? eyebrow;
  final Widget? footer;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final layout = FlowLayoutInfo.of(context);
    final wordCount = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    final quoteSize = switch (wordCount) {
      <= 14 => 30.0,
      <= 24 => 26.0,
      <= 42 => 22.0,
      _ => 19.0,
    };
    final effectiveQuoteSize = layout.isCompact ? quoteSize - 1.5 : quoteSize;
    final effectiveMinHeight = layout.isCompact ? minHeight - 20 : minHeight;

    Widget child = ConstrainedBox(
      constraints: BoxConstraints(minHeight: effectiveMinHeight),
      child: PremiumGlassCard(
        borderRadius: 34,
        elevation: 2,
        tone: PremiumGlassTone.vivid,
        padding: EdgeInsets.all(layout.isCompact ? FlowSpace.lg : FlowSpace.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boundedHeight = constraints.hasBoundedHeight;
            final tightLayout =
                layout.isCompact ||
                (boundedHeight && constraints.maxHeight < 190);
            final inset = tightLayout ? FlowSpace.sm : FlowSpace.md;
            final quoteWidget = Text(
              quote,
              maxLines: tightLayout ? 3 : 5,
              overflow: TextOverflow.ellipsis,
              style: FlowTypography.quoteStyle(
                context: context,
                color: colors?.textPrimary ?? Colors.white,
                fontSize: tightLayout
                    ? effectiveQuoteSize - 1
                    : effectiveQuoteSize,
              ),
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (gradients?.accentStart ?? Colors.white).withValues(
                      alpha: 0.16,
                    ),
                    (colors?.surface ?? Colors.black).withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: boundedHeight
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors?.accentSecondary.withValues(
                                alpha: 0.92,
                              ),
                              fontSize: tightLayout ? 11 : null,
                            ),
                      ),
                      SizedBox(height: tightLayout ? 6 : FlowSpace.sm),
                    ],
                    if (boundedHeight)
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: quoteWidget,
                        ),
                      )
                    else
                      quoteWidget,
                    SizedBox(height: tightLayout ? FlowSpace.sm : FlowSpace.lg),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: tightLayout ? 15 : null,
                        color: colors?.accentSecondary.withValues(alpha: 0.98),
                      ),
                    ),
                    if (footer != null) ...[
                      SizedBox(
                        height: tightLayout ? FlowSpace.xs : FlowSpace.md,
                      ),
                      footer!,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (onTap != null) {
      child = ScaleTap(onTap: onTap!, child: child);
    }

    return child;
  }
}
