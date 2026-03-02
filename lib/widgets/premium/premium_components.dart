import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

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
    final colors = flow?.colors;
    final shadows = flow?.shadows;
    final borderRadius = BorderRadius.circular(radius);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color:
            colors?.surface.withValues(alpha: 0.9) ??
            Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color:
              colors?.divider.withValues(alpha: 0.8) ??
              Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: switch (elevation) {
          <= 1 => shadows?.level1,
          2 => shadows?.level2,
          _ => shadows?.level3,
        },
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blurSigma > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    return content;
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
    final textTheme = Theme.of(context).textTheme;

    final wordCount = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    final quoteSize = switch (wordCount) {
      <= 14 => 36.0,
      <= 24 => 32.0,
      <= 36 => 28.0,
      <= 52 => 24.0,
      _ => 21.0,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: FlowRadii.radiusXl,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors?.quoteFrame.withValues(alpha: 0.96) ??
                  Colors.white.withValues(alpha: 0.08),
              colors?.surface.withValues(alpha: 0.72) ??
                  Colors.black.withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(
            color:
                colors?.quoteFrameBorder.withValues(alpha: 0.86) ??
                Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  colors?.quoteFrameGlow.withValues(alpha: 0.24) ??
                  Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
            ...?flow?.shadows.level2,
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.xl,
            FlowSpace.xl,
            FlowSpace.xl,
            FlowSpace.lg,
          ),
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
                    color: colors?.textSecondary.withValues(alpha: 0.95),
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: FlowSpace.xs),
              ],
              if (showOpeningQuote)
                Text(
                  '"',
                  style: textTheme.headlineLarge?.copyWith(
                    color: colors?.textSecondary.withValues(alpha: 0.35),
                    height: 0.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                quote,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: FlowTypography.quoteStyle(
                  color: colors?.textPrimary ?? Colors.white,
                  fontSize: quoteSize,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: FlowSpace.lg),
              Container(
                height: 1,
                width: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      colors?.divider.withValues(alpha: 0.95) ??
                          Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FlowSpace.sm),
              Text(
                '- $author',
                style: textTheme.titleMedium?.copyWith(
                  color: colors?.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.25,
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? FlowSpace.sm : FlowSpace.md,
            vertical: compact ? FlowSpace.xs : FlowSpace.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? colors?.accent.withValues(alpha: 0.2)
                : colors?.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors?.divider ?? Colors.white24),
            boxShadow: flow?.shadows.level1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 16 : 18,
                color: active
                    ? colors?.accent
                    : colors?.textPrimary.withValues(alpha: 0.92),
              ),
              if (label != null) ...[
                const SizedBox(width: FlowSpace.xs),
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors?.textPrimary.withValues(alpha: 0.9),
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

class PremiumPillChip extends StatelessWidget {
  const PremiumPillChip({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? colors?.accent.withValues(alpha: 0.22)
                : colors?.surface.withValues(alpha: 0.84),
            border: Border.all(
              color: selected
                  ? colors?.accent.withValues(alpha: 0.92) ?? Colors.white54
                  : colors?.divider ?? Colors.white24,
            ),
          ),
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
                  size: 15,
                  color: colors?.textPrimary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: FlowSpace.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors?.textPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: FlowSpace.xxs),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors?.textSecondary,
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
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FlowRadii.radiusMd,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.md,
            vertical: FlowSpace.md,
          ),
          decoration: BoxDecoration(
            borderRadius: FlowRadii.radiusMd,
            color: colors?.surface.withValues(alpha: 0.82),
            border: Border.all(color: colors?.divider ?? Colors.white24),
          ),
          child: Row(
            children: [
              ..._optionalWithSpacing(leading),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors?.textPrimary,
                      ),
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
        ),
      ),
    );
  }
}
