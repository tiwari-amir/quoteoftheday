import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../glass_card.dart';
import '../scale_tap.dart';

List<Widget> _optional(Widget? child) =>
    child == null ? const <Widget>[] : <Widget>[child];

List<Widget> _optionalWithSpacing(Widget? child) => child == null
    ? const <Widget>[]
    : <Widget>[child, const SizedBox(width: FlowSpace.sm)];

class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FlowSpace.lg),
    this.radius = FlowRadii.lg,
    this.elevation = 2,
    this.blurSigma = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final int elevation;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    return PremiumGlassCard(
      borderRadius: radius,
      blurSigma: blurSigma > 0 ? blurSigma : flow?.glass.blurSigma,
      elevation: elevation,
      padding: padding,
      tone: switch (elevation) {
        <= 1 => PremiumGlassTone.subtle,
        2 => PremiumGlassTone.standard,
        _ => PremiumGlassTone.vivid,
      },
      child: child,
    );
  }
}

class QuoteSurface extends StatelessWidget {
  const QuoteSurface({
    super.key,
    required this.quote,
    required this.author,
    this.eyebrow,
    this.maxWidth = 760,
    this.showOpeningQuote = true,
    this.footer,
    this.centered = true,
  });

  final String quote;
  final String author;
  final String? eyebrow;
  final double maxWidth;
  final bool showOpeningQuote;
  final Widget? footer;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final textTheme = Theme.of(context).textTheme;
    final layout = FlowLayoutInfo.of(context);

    final wordCount = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    final quoteSize = switch (wordCount) {
      <= 14 => 38.0,
      <= 24 => 34.0,
      <= 36 => 30.0,
      <= 52 => 26.0,
      _ => 22.0,
    };
    final effectiveQuoteSize = layout.isCompact ? quoteSize - 2 : quoteSize;
    final cardPadding = layout.isCompact
        ? const EdgeInsets.fromLTRB(
            FlowSpace.lg,
            FlowSpace.xl,
            FlowSpace.lg,
            FlowSpace.lg,
          )
        : const EdgeInsets.fromLTRB(
            FlowSpace.xxl,
            FlowSpace.xxl,
            FlowSpace.xxl,
            FlowSpace.xl,
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: PremiumGlassCard(
        borderRadius: 34,
        elevation: 3,
        tone: PremiumGlassTone.vivid,
        padding: cardPadding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (colors?.quoteFrame ?? Colors.white).withValues(alpha: 0.82),
                (colors?.surface ?? Colors.black).withValues(alpha: 0.28),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors?.accent.withValues(alpha: 0.9),
                      letterSpacing: 0.84,
                    ),
                  ),
                  const SizedBox(height: FlowSpace.xs),
                ],
                if (showOpeningQuote)
                  Text(
                    '"',
                    style: textTheme.headlineLarge?.copyWith(
                      color: gradients?.accentStart.withValues(alpha: 0.52),
                      height: 0.68,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: FlowSpace.xs),
                Text(
                  quote,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style:
                      FlowTypography.quoteStyle(
                        context: context,
                        color: colors?.textPrimary ?? Colors.white,
                        fontSize: effectiveQuoteSize,
                        weight: FontWeight.w500,
                      ).copyWith(
                        height: wordCount > 42 ? 1.48 : null,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 34,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: FlowSpace.xl),
                Container(
                  height: 1,
                  width: 188,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        gradients?.accentStart.withValues(alpha: 0.92) ??
                            Colors.white.withValues(alpha: 0.18),
                        gradients?.accentEnd.withValues(alpha: 0.72) ??
                            Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: FlowSpace.md),
                Text(
                  author,
                  style: textTheme.titleLarge?.copyWith(
                    color: colors?.accentSecondary.withValues(alpha: 0.96),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.14,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: FlowSpace.md),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumIconPillButton extends StatelessWidget {
  const PremiumIconPillButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.compact = false,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final layout = FlowLayoutInfo.of(context);
    final reduced = layout.isCompact;
    final height = compact ? (reduced ? 36.0 : 40.0) : (reduced ? 42.0 : 46.0);

    return ScaleTap(
      onTap: onTap,
      child: Semantics(
        button: true,
        child: AnimatedContainer(
          duration: FlowDurations.regular,
          curve: FlowDurations.curve,
          constraints: BoxConstraints(minHeight: height),
          padding: EdgeInsets.symmetric(
            horizontal: compact
                ? (reduced ? FlowSpace.xs : FlowSpace.sm)
                : (reduced ? FlowSpace.sm : FlowSpace.md),
            vertical: compact
                ? (reduced ? 7 : 8)
                : (reduced ? 9 : FlowSpace.sm),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            gradient: LinearGradient(
              begin: const Alignment(-1, -1),
              end: const Alignment(1, 1),
              colors: active
                  ? <Color>[
                      gradients?.accentStart.withValues(alpha: 0.4) ??
                          Colors.white.withValues(alpha: 0.24),
                      gradients?.accentEnd.withValues(alpha: 0.22) ??
                          Colors.white.withValues(alpha: 0.12),
                    ]
                  : <Color>[
                      (colors?.elevatedSurface ?? Colors.black).withValues(
                        alpha: 0.92,
                      ),
                      (colors?.surface ?? Colors.black).withValues(alpha: 0.84),
                    ],
            ),
            boxShadow: <BoxShadow>[
              ...?flow?.shadows.level1,
              if (active)
                BoxShadow(
                  color: (colors?.accent ?? Colors.white).withValues(
                    alpha: 0.24,
                  ),
                  blurRadius: 28,
                  spreadRadius: -10,
                ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: FlowDurations.regular,
                  curve: FlowDurations.curve,
                  width: active ? 3 : 0,
                  height: compact ? 18 : 22,
                  margin: EdgeInsets.only(right: active ? FlowSpace.xs : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        gradients?.accentStart ?? Colors.white,
                        gradients?.accentEnd ?? Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: active ? 0.26 : 0,
                        ),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  icon,
                  size: compact ? (reduced ? 15 : 16) : (reduced ? 17 : 18),
                  color: active
                      ? colors?.accentSecondary
                      : (colors?.textPrimary ?? Colors.white).withValues(
                          alpha: 0.94,
                        ),
                ),
                if (label != null) ...[
                  const SizedBox(width: FlowSpace.xs),
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: reduced ? 12 : null,
                      color: (colors?.textPrimary ?? Colors.white).withValues(
                        alpha: 0.92,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumPillChip extends StatelessWidget {
  const PremiumPillChip({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;

    Widget content = AnimatedContainer(
      duration: FlowDurations.regular,
      curve: FlowDurations.curve,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : FlowSpace.md,
        vertical: compact ? 6 : FlowSpace.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: selected
              ? <Color>[
                  gradients?.accentStart.withValues(alpha: 0.34) ??
                      Colors.white.withValues(alpha: 0.2),
                  gradients?.accentEnd.withValues(alpha: 0.18) ??
                      Colors.white.withValues(alpha: 0.1),
                ]
              : <Color>[
                  (colors?.elevatedSurface ?? Colors.black).withValues(
                    alpha: 0.88,
                  ),
                  (colors?.surface ?? Colors.black).withValues(alpha: 0.8),
                ],
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: (colors?.accent ?? Colors.white).withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 26,
                  spreadRadius: -10,
                ),
              ]
            : flow?.shadows.level1,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: FlowDurations.regular,
              curve: FlowDurations.curve,
              width: selected ? 3 : 0,
              height: compact ? 14 : 18,
              margin: EdgeInsets.only(right: selected ? FlowSpace.xs : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    gradients?.accentStart ?? Colors.white,
                    gradients?.accentEnd ?? Colors.white,
                  ],
                ),
              ),
            ),
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 12.5 : 15,
                color: selected
                    ? colors?.accentSecondary
                    : (colors?.textSecondary ?? Colors.white70).withValues(
                        alpha: 0.9,
                      ),
              ),
              SizedBox(width: compact ? 6 : FlowSpace.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? colors?.accentSecondary.withValues(alpha: 0.98)
                    : colors?.textPrimary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : null,
                letterSpacing: compact ? 0.24 : 0.42,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return ScaleTap(onTap: onTap!, child: content);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: FlowSpace.xs),
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
        ..._optional(trailing),
      ],
    );
  }
}

class PremiumSettingsTile extends StatelessWidget {
  const PremiumSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;

    final tile = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.md,
        vertical: FlowSpace.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            (colors?.elevatedSurface ?? Colors.black).withValues(alpha: 0.9),
            (colors?.surface ?? Colors.black).withValues(alpha: 0.82),
          ],
        ),
        boxShadow: flow?.shadows.level1,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: subtitle == null ? 24 : 34,
            margin: const EdgeInsets.only(right: FlowSpace.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors?.accent ?? Colors.white,
                  colors?.accentSecondary ?? Colors.white,
                ],
              ),
            ),
          ),
          ..._optionalWithSpacing(leading),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colors?.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: FlowSpace.xxs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors?.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ..._optional(trailing),
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return ScaleTap(onTap: onTap!, child: tile);
  }
}
