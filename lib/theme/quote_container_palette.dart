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
      fillTop: Color(0xB1103238),
      fillBottom: Color(0xB106181F),
      border: Color(0x6BA5DACE),
      glow: Color(0x486BC8B8),
      quoteText: Color(0xFFF2FBF9),
      authorText: Color(0xE0D2ECE5),
      tagText: Color(0xB4ABCFC8),
      chromeTint: Color(0xA248A99B),
    ),
    AppBackgroundTheme.spaceGalaxies => const QuoteContainerPalette(
      fillTop: Color(0xB217223A),
      fillBottom: Color(0xB10A1020),
      border: Color(0x6BA8BCE0),
      glow: Color(0x486F86D0),
      quoteText: Color(0xFFF2F5FD),
      authorText: Color(0xE0D8DEEF),
      tagText: Color(0xB4B6BFD8),
      chromeTint: Color(0xA25F76B6),
    ),
    AppBackgroundTheme.rainyCity => const QuoteContainerPalette(
      fillTop: Color(0xB1142935),
      fillBottom: Color(0xB109151E),
      border: Color(0x6B9FC4D0),
      glow: Color(0x4874AEBE),
      quoteText: Color(0xFFF0F7FB),
      authorText: Color(0xE0D2E2E9),
      tagText: Color(0xB4B2C2CD),
      chromeTint: Color(0xA25695AE),
    ),
    AppBackgroundTheme.deepForest => const QuoteContainerPalette(
      fillTop: Color(0xB1132C20),
      fillBottom: Color(0xB1081911),
      border: Color(0x6BACD0B3),
      glow: Color(0x486FB487),
      quoteText: Color(0xFFF3FBF6),
      authorText: Color(0xE0D4E9DC),
      tagText: Color(0xB4B1C6B9),
      chromeTint: Color(0xA2579069),
    ),
    AppBackgroundTheme.sunsetCity => const QuoteContainerPalette(
      fillTop: Color(0xB2372634),
      fillBottom: Color(0xB1191422),
      border: Color(0x6BE4C3A7),
      glow: Color(0x48D69C86),
      quoteText: Color(0xFFFFF6EE),
      authorText: Color(0xE0F1DECF),
      tagText: Color(0xB4D8C0B8),
      chromeTint: Color(0xA2B8838D),
    ),
    AppBackgroundTheme.quoteflowGlow => const QuoteContainerPalette(
      fillTop: Color(0xB1342238),
      fillBottom: Color(0xB1171124),
      border: Color(0x6BE7C8AC),
      glow: Color(0x48D3A08B),
      quoteText: Color(0xFFFFF6EE),
      authorText: Color(0xE0F2DFCF),
      tagText: Color(0xB4D6C2C8),
      chromeTint: Color(0xA2B6828E),
    ),
  };
}
