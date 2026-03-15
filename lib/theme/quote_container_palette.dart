import 'package:flutter/material.dart';

import '../features/v3_background/background_theme_provider.dart';
import 'design_tokens.dart';

@immutable
class QuoteContainerPalette {
  const QuoteContainerPalette({
    required this.fillTop,
    required this.fillBottom,
    required this.border,
    required this.glow,
    required this.quoteText,
    required this.authorText,
    required this.tagText,
    required this.chromeTint,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color glow;
  final Color quoteText;
  final Color authorText;
  final Color tagText;
  final Color chromeTint;
}

QuoteContainerPalette quoteContainerPaletteFor(AppBackgroundTheme theme) {
  final colors = flowColorsFor(theme);
  return QuoteContainerPalette(
    fillTop: colors.quoteFrame.withValues(alpha: 0.9),
    fillBottom: colors.surface.withValues(alpha: 0.82),
    border: colors.quoteFrameBorder.withValues(alpha: 0.88),
    glow: colors.quoteFrameGlow.withValues(alpha: 0.72),
    quoteText: colors.textPrimary,
    authorText: colors.accentSecondary.withValues(alpha: 0.94),
    tagText: colors.textSecondary.withValues(alpha: 0.92),
    chromeTint: colors.accent.withValues(alpha: 0.3),
  );
}
