import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/v3_background/background_theme_provider.dart';

abstract final class FlowSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class FlowRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;

  static BorderRadius get radiusSm => BorderRadius.circular(sm);
  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
  static BorderRadius get radiusXl => BorderRadius.circular(xl);
  static BorderRadius pill(double value) => BorderRadius.circular(value);
}

abstract final class FlowDurations {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration regular = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutCubic;
}

@immutable
class FlowShadowSet {
  const FlowShadowSet({
    required this.level1,
    required this.level2,
    required this.level3,
  });

  final List<BoxShadow> level1;
  final List<BoxShadow> level2;
  final List<BoxShadow> level3;
}

@immutable
class FlowColorTokens {
  const FlowColorTokens({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.divider,
    required this.quoteFrame,
    required this.quoteFrameBorder,
    required this.quoteFrameGlow,
    required this.interactionRipple,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color divider;
  final Color quoteFrame;
  final Color quoteFrameBorder;
  final Color quoteFrameGlow;
  final Color interactionRipple;

  FlowColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? divider,
    Color? quoteFrame,
    Color? quoteFrameBorder,
    Color? quoteFrameGlow,
    Color? interactionRipple,
  }) {
    return FlowColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      quoteFrame: quoteFrame ?? this.quoteFrame,
      quoteFrameBorder: quoteFrameBorder ?? this.quoteFrameBorder,
      quoteFrameGlow: quoteFrameGlow ?? this.quoteFrameGlow,
      interactionRipple: interactionRipple ?? this.interactionRipple,
    );
  }

  static FlowColorTokens lerp(FlowColorTokens a, FlowColorTokens b, double t) {
    return FlowColorTokens(
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      surface: Color.lerp(a.surface, b.surface, t) ?? a.surface,
      elevatedSurface:
          Color.lerp(a.elevatedSurface, b.elevatedSurface, t) ??
          a.elevatedSurface,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t) ?? a.textPrimary,
      textSecondary:
          Color.lerp(a.textSecondary, b.textSecondary, t) ?? a.textSecondary,
      accent: Color.lerp(a.accent, b.accent, t) ?? a.accent,
      divider: Color.lerp(a.divider, b.divider, t) ?? a.divider,
      quoteFrame: Color.lerp(a.quoteFrame, b.quoteFrame, t) ?? a.quoteFrame,
      quoteFrameBorder:
          Color.lerp(a.quoteFrameBorder, b.quoteFrameBorder, t) ??
          a.quoteFrameBorder,
      quoteFrameGlow:
          Color.lerp(a.quoteFrameGlow, b.quoteFrameGlow, t) ?? a.quoteFrameGlow,
      interactionRipple:
          Color.lerp(a.interactionRipple, b.interactionRipple, t) ??
          a.interactionRipple,
    );
  }
}

@immutable
class FlowThemeTokens extends ThemeExtension<FlowThemeTokens> {
  const FlowThemeTokens({required this.colors, required this.shadowColor});

  final FlowColorTokens colors;
  final Color shadowColor;

  FlowShadowSet get shadows {
    return FlowShadowSet(
      level1: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      level2: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      level3: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.3),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  @override
  FlowThemeTokens copyWith({FlowColorTokens? colors, Color? shadowColor}) {
    return FlowThemeTokens(
      colors: colors ?? this.colors,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  FlowThemeTokens lerp(ThemeExtension<FlowThemeTokens>? other, double t) {
    if (other is! FlowThemeTokens) return this;
    return FlowThemeTokens(
      colors: FlowColorTokens.lerp(colors, other.colors, t),
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t) ?? shadowColor,
    );
  }
}

abstract final class FlowTypography {
  static TextTheme buildTextTheme(FlowColorTokens colors) {
    final baseSans = GoogleFonts.dmSansTextTheme();
    return baseSans.copyWith(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.12,
        color: colors.textPrimary,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.16,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: colors.textPrimary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: colors.textPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: colors.textSecondary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: colors.textSecondary,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.1,
        color: colors.textPrimary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
        height: 1.1,
        color: colors.textSecondary,
      ),
    );
  }

  static TextStyle quoteStyle({
    required Color color,
    required double fontSize,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.sourceSerif4(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1.38,
      color: color,
      letterSpacing: 0.12,
    );
  }
}

FlowColorTokens flowColorsFor(AppBackgroundTheme theme) {
  return switch (theme) {
    AppBackgroundTheme.oceanFloor => const FlowColorTokens(
      background: Color(0xFF041014),
      surface: Color(0xCC0A1D24),
      elevatedSurface: Color(0xD1152A33),
      textPrimary: Color(0xFFF2FCF9),
      textSecondary: Color(0xB9C8DFD7),
      accent: Color(0xFF8FD2C3),
      divider: Color(0x3A9FCABD),
      quoteFrame: Color(0xA50D2730),
      quoteFrameBorder: Color(0x6EA7D8CB),
      quoteFrameGlow: Color(0x386FC7B7),
      interactionRipple: Color(0x66A5DBCF),
    ),
    AppBackgroundTheme.spaceGalaxies => const FlowColorTokens(
      background: Color(0xFF04070F),
      surface: Color(0xCC101728),
      elevatedSurface: Color(0xD1172137),
      textPrimary: Color(0xFFF2F5FF),
      textSecondary: Color(0xB8C2CCE7),
      accent: Color(0xFFAEC2F2),
      divider: Color(0x3E98A9D6),
      quoteFrame: Color(0xA5111B30),
      quoteFrameBorder: Color(0x6EA1B4E2),
      quoteFrameGlow: Color(0x385D79D2),
      interactionRipple: Color(0x66AFC6FF),
    ),
    AppBackgroundTheme.rainyCity => const FlowColorTokens(
      background: Color(0xFF050A10),
      surface: Color(0xCC101B24),
      elevatedSurface: Color(0xD1162430),
      textPrimary: Color(0xFFF1F6FA),
      textSecondary: Color(0xB8C2D0DA),
      accent: Color(0xFF9FC8DA),
      divider: Color(0x3F95AFC1),
      quoteFrame: Color(0xA5112029),
      quoteFrameBorder: Color(0x6EA1BECC),
      quoteFrameGlow: Color(0x38557E99),
      interactionRipple: Color(0x66AED0E0),
    ),
    AppBackgroundTheme.deepForest => const FlowColorTokens(
      background: Color(0xFF040A07),
      surface: Color(0xCC0F1C15),
      elevatedSurface: Color(0xD114271D),
      textPrimary: Color(0xFFF2FAF3),
      textSecondary: Color(0xB8C4D9C6),
      accent: Color(0xFFA7D2AF),
      divider: Color(0x3F95B79D),
      quoteFrame: Color(0xA511241A),
      quoteFrameBorder: Color(0x6EA7CDB0),
      quoteFrameGlow: Color(0x386A9E78),
      interactionRipple: Color(0x66B6D9BD),
    ),
    AppBackgroundTheme.sunsetCity => const FlowColorTokens(
      background: Color(0xFF140E16),
      surface: Color(0xCC2A1E2B),
      elevatedSurface: Color(0xD1372638),
      textPrimary: Color(0xFFFFF4EA),
      textSecondary: Color(0xC5DEC8BA),
      accent: Color(0xFFE8B08E),
      divider: Color(0x49D3AC9A),
      quoteFrame: Color(0xA6332231),
      quoteFrameBorder: Color(0x76E4C1AA),
      quoteFrameGlow: Color(0x41D49785),
      interactionRipple: Color(0x6EEBB79A),
    ),
    AppBackgroundTheme.quoteflowGlow => const FlowColorTokens(
      background: Color(0xFF100914),
      surface: Color(0xCC22182A),
      elevatedSurface: Color(0xD12E2037),
      textPrimary: Color(0xFFFFF2E8),
      textSecondary: Color(0xC5D9C5C6),
      accent: Color(0xFFE8B99A),
      divider: Color(0x49C99FB1),
      quoteFrame: Color(0xA72C1E32),
      quoteFrameBorder: Color(0x76E7C3AB),
      quoteFrameGlow: Color(0x41D59C8E),
      interactionRipple: Color(0x6EEBC2A2),
    ),
  };
}

FlowThemeTokens flowTokensFor(AppBackgroundTheme theme) {
  final colors = flowColorsFor(theme);
  return FlowThemeTokens(colors: colors, shadowColor: Colors.black);
}

double lerpValue(double a, double b, double t) => lerpDouble(a, b, t) ?? a;
