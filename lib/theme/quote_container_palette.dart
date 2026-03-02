import 'package:flutter/material.dart';

import '../features/v3_background/background_theme_provider.dart';

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
  return switch (theme) {
    AppBackgroundTheme.oceanFloor => const QuoteContainerPalette(
      fillTop: Color(0xB2153A3E),
      fillBottom: Color(0xB10A1E22),
      border: Color(0x6BB3ECE0),
      glow: Color(0x4879D9CB),
      quoteText: Color(0xFFF2FFFC),
      authorText: Color(0xE0D8FBF4),
      tagText: Color(0xB4BCE5DD),
      chromeTint: Color(0xA24FBEB0),
    ),
    AppBackgroundTheme.spaceGalaxies => const QuoteContainerPalette(
      fillTop: Color(0xB21D2643),
      fillBottom: Color(0xB10D1228),
      border: Color(0x6BA9C3FF),
      glow: Color(0x487596F7),
      quoteText: Color(0xFFF5F8FF),
      authorText: Color(0xE0DEE7FF),
      tagText: Color(0xB4BDC8E8),
      chromeTint: Color(0xA26985D8),
    ),
    AppBackgroundTheme.rainyCity => const QuoteContainerPalette(
      fillTop: Color(0xB2162C3B),
      fillBottom: Color(0xB10C1722),
      border: Color(0x6B9DD5E8),
      glow: Color(0x4878BFDB),
      quoteText: Color(0xFFF2FAFF),
      authorText: Color(0xE0D3EAF4),
      tagText: Color(0xB4B7D0DD),
      chromeTint: Color(0xA255A8C8),
    ),
    AppBackgroundTheme.deepForest => const QuoteContainerPalette(
      fillTop: Color(0xB2163124),
      fillBottom: Color(0xB10A1C13),
      border: Color(0x6BAFE8B8),
      glow: Color(0x487ACF8F),
      quoteText: Color(0xFFF3FFF7),
      authorText: Color(0xE0D8F5DF),
      tagText: Color(0xB4BEDBC7),
      chromeTint: Color(0xA25CA774),
    ),
    AppBackgroundTheme.sunsetCity => const QuoteContainerPalette(
      fillTop: Color(0xB23E2A3B),
      fillBottom: Color(0xB11D1729),
      border: Color(0x6BFFD2AC),
      glow: Color(0x48F5B08C),
      quoteText: Color(0xFFFFF8F1),
      authorText: Color(0xE0FFE7D5),
      tagText: Color(0xB4F0CCBF),
      chromeTint: Color(0xA2D48A9B),
    ),
    AppBackgroundTheme.quoteflowGlow => const QuoteContainerPalette(
      fillTop: Color(0xB2402846),
      fillBottom: Color(0xB11F162E),
      border: Color(0x6BFFD4B3),
      glow: Color(0x48E79AB7),
      quoteText: Color(0xFFFFF6EC),
      authorText: Color(0xE0FFE2CC),
      tagText: Color(0xB4EBC4D8),
      chromeTint: Color(0xA2C27CB1),
    ),
  };
}
