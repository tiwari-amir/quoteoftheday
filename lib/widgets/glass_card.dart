import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

enum PremiumGlassTone { subtle, standard, vivid }

class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.blurSigma,
    this.tone = PremiumGlassTone.standard,
    this.elevation = 2,
    this.showAccentGlow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? blurSigma;
  final PremiumGlassTone tone;
  final int elevation;
  final bool showAccentGlow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flow = theme.extension<FlowThemeTokens>();
    final legacy = theme.extension<AppThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final glass = flow?.glass;
    final shadows = flow?.shadows;

    final fill = legacy?.glassFill ?? Colors.white.withValues(alpha: 0.12);
    final accent = colors?.accent ?? Colors.white;
    final accentSecondary = colors?.accentSecondary ?? accent;
    final sigma = blurSigma ?? glass?.denseBlurSigma ?? 30;
    final radius = BorderRadius.circular(borderRadius);

    final alphaMultiplier = switch (tone) {
      PremiumGlassTone.subtle => 0.76,
      PremiumGlassTone.standard => 1.0,
      PremiumGlassTone.vivid => 1.16,
    };

    final elevationShadows = switch (elevation) {
      <= 1 => shadows?.level1 ?? const <BoxShadow>[],
      2 => shadows?.level2 ?? const <BoxShadow>[],
      _ => shadows?.level3 ?? const <BoxShadow>[],
    };

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: const Alignment(-0.95, -1),
              end: const Alignment(0.92, 1),
              colors: [
                (gradients?.chromeStart ?? fill).withValues(
                  alpha: 0.18 * alphaMultiplier,
                ),
                (colors?.elevatedSurface ?? fill).withValues(
                  alpha: 0.94 * alphaMultiplier,
                ),
                (gradients?.chromeEnd ?? colors?.surface ?? fill).withValues(
                  alpha: 0.88 * alphaMultiplier,
                ),
              ],
              stops: const [0.0, 0.36, 1.0],
            ),
            boxShadow: <BoxShadow>[
              ...elevationShadows,
              if (showAccentGlow)
                BoxShadow(
                  color: accent.withValues(alpha: 0.14 * alphaMultiplier),
                  blurRadius: 52,
                  spreadRadius: -18,
                  offset: const Offset(0, 16),
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.08 * alphaMultiplier),
                          Colors.transparent,
                          accentSecondary.withValues(
                            alpha: 0.05 * alphaMultiplier,
                          ),
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 68,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(
                            alpha:
                                (glass?.innerHighlightOpacity ?? 0.2) *
                                alphaMultiplier,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: IgnorePointer(
                  child: Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(
                            alpha:
                                (glass?.innerHighlightOpacity ?? 0.2) *
                                alphaMultiplier,
                          ),
                          accent.withValues(alpha: 0.14 * alphaMultiplier),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 14,
                child: IgnorePointer(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          accent.withValues(alpha: 0.22 * alphaMultiplier),
                          accentSecondary.withValues(
                            alpha: 0.18 * alphaMultiplier,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    this.blur = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      borderRadius: borderRadius,
      blurSigma: blur,
      padding: padding,
      child: child,
    );
  }
}
