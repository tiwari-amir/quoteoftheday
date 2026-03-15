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
  static const double lg = 22;
  static const double xl = 30;

  static BorderRadius get radiusSm => BorderRadius.circular(sm);
  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
  static BorderRadius get radiusXl => BorderRadius.circular(xl);
  static BorderRadius pill(double value) => BorderRadius.circular(value);
}

abstract final class FlowDurations {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration regular = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 380);

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
    required this.accentSecondary,
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
  final Color accentSecondary;
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
    Color? accentSecondary,
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
      accentSecondary: accentSecondary ?? this.accentSecondary,
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
      accentSecondary:
          Color.lerp(a.accentSecondary, b.accentSecondary, t) ??
          a.accentSecondary,
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
class FlowGradientTokens {
  const FlowGradientTokens({
    required this.accentStart,
    required this.accentEnd,
    required this.atmosphereTop,
    required this.atmosphereBottom,
    required this.atmosphereHighlight,
    required this.chromeStart,
    required this.chromeEnd,
  });

  final Color accentStart;
  final Color accentEnd;
  final Color atmosphereTop;
  final Color atmosphereBottom;
  final Color atmosphereHighlight;
  final Color chromeStart;
  final Color chromeEnd;

  FlowGradientTokens copyWith({
    Color? accentStart,
    Color? accentEnd,
    Color? atmosphereTop,
    Color? atmosphereBottom,
    Color? atmosphereHighlight,
    Color? chromeStart,
    Color? chromeEnd,
  }) {
    return FlowGradientTokens(
      accentStart: accentStart ?? this.accentStart,
      accentEnd: accentEnd ?? this.accentEnd,
      atmosphereTop: atmosphereTop ?? this.atmosphereTop,
      atmosphereBottom: atmosphereBottom ?? this.atmosphereBottom,
      atmosphereHighlight: atmosphereHighlight ?? this.atmosphereHighlight,
      chromeStart: chromeStart ?? this.chromeStart,
      chromeEnd: chromeEnd ?? this.chromeEnd,
    );
  }

  static FlowGradientTokens lerp(
    FlowGradientTokens a,
    FlowGradientTokens b,
    double t,
  ) {
    return FlowGradientTokens(
      accentStart: Color.lerp(a.accentStart, b.accentStart, t) ?? a.accentStart,
      accentEnd: Color.lerp(a.accentEnd, b.accentEnd, t) ?? a.accentEnd,
      atmosphereTop:
          Color.lerp(a.atmosphereTop, b.atmosphereTop, t) ?? a.atmosphereTop,
      atmosphereBottom:
          Color.lerp(a.atmosphereBottom, b.atmosphereBottom, t) ??
          a.atmosphereBottom,
      atmosphereHighlight:
          Color.lerp(a.atmosphereHighlight, b.atmosphereHighlight, t) ??
          a.atmosphereHighlight,
      chromeStart: Color.lerp(a.chromeStart, b.chromeStart, t) ?? a.chromeStart,
      chromeEnd: Color.lerp(a.chromeEnd, b.chromeEnd, t) ?? a.chromeEnd,
    );
  }
}

@immutable
class FlowGlassSpec {
  const FlowGlassSpec({
    required this.blurSigma,
    required this.denseBlurSigma,
    required this.hairlineWidth,
    required this.outerShadowOpacity,
    required this.innerHighlightOpacity,
  });

  final double blurSigma;
  final double denseBlurSigma;
  final double hairlineWidth;
  final double outerShadowOpacity;
  final double innerHighlightOpacity;

  FlowGlassSpec copyWith({
    double? blurSigma,
    double? denseBlurSigma,
    double? hairlineWidth,
    double? outerShadowOpacity,
    double? innerHighlightOpacity,
  }) {
    return FlowGlassSpec(
      blurSigma: blurSigma ?? this.blurSigma,
      denseBlurSigma: denseBlurSigma ?? this.denseBlurSigma,
      hairlineWidth: hairlineWidth ?? this.hairlineWidth,
      outerShadowOpacity: outerShadowOpacity ?? this.outerShadowOpacity,
      innerHighlightOpacity:
          innerHighlightOpacity ?? this.innerHighlightOpacity,
    );
  }

  static FlowGlassSpec lerp(FlowGlassSpec a, FlowGlassSpec b, double t) {
    return FlowGlassSpec(
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t) ?? a.blurSigma,
      denseBlurSigma:
          lerpDouble(a.denseBlurSigma, b.denseBlurSigma, t) ?? a.denseBlurSigma,
      hairlineWidth:
          lerpDouble(a.hairlineWidth, b.hairlineWidth, t) ?? a.hairlineWidth,
      outerShadowOpacity:
          lerpDouble(a.outerShadowOpacity, b.outerShadowOpacity, t) ??
          a.outerShadowOpacity,
      innerHighlightOpacity:
          lerpDouble(a.innerHighlightOpacity, b.innerHighlightOpacity, t) ??
          a.innerHighlightOpacity,
    );
  }
}

@immutable
class FlowThemeTokens extends ThemeExtension<FlowThemeTokens> {
  const FlowThemeTokens({
    required this.mood,
    required this.colors,
    required this.gradients,
    required this.glass,
    required this.shadowColor,
  });

  final AppBackgroundTheme mood;
  final FlowColorTokens colors;
  final FlowGradientTokens gradients;
  final FlowGlassSpec glass;
  final Color shadowColor;

  FlowShadowSet get shadows {
    return FlowShadowSet(
      level1: [
        BoxShadow(
          color: shadowColor.withValues(alpha: glass.outerShadowOpacity * 0.6),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.05),
          blurRadius: 24,
          spreadRadius: -10,
        ),
      ],
      level2: [
        BoxShadow(
          color: shadowColor.withValues(alpha: glass.outerShadowOpacity * 0.82),
          blurRadius: 36,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.08),
          blurRadius: 40,
          spreadRadius: -14,
        ),
      ],
      level3: [
        BoxShadow(
          color: shadowColor.withValues(alpha: glass.outerShadowOpacity),
          blurRadius: 56,
          offset: const Offset(0, 28),
        ),
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.12),
          blurRadius: 60,
          spreadRadius: -18,
        ),
      ],
    );
  }

  @override
  FlowThemeTokens copyWith({
    AppBackgroundTheme? mood,
    FlowColorTokens? colors,
    FlowGradientTokens? gradients,
    FlowGlassSpec? glass,
    Color? shadowColor,
  }) {
    return FlowThemeTokens(
      mood: mood ?? this.mood,
      colors: colors ?? this.colors,
      gradients: gradients ?? this.gradients,
      glass: glass ?? this.glass,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  FlowThemeTokens lerp(ThemeExtension<FlowThemeTokens>? other, double t) {
    if (other is! FlowThemeTokens) return this;
    return FlowThemeTokens(
      mood: t < 0.5 ? mood : other.mood,
      colors: FlowColorTokens.lerp(colors, other.colors, t),
      gradients: FlowGradientTokens.lerp(gradients, other.gradients, t),
      glass: FlowGlassSpec.lerp(glass, other.glass, t),
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t) ?? shadowColor,
    );
  }
}

class _MoodTypographySpec {
  const _MoodTypographySpec({
    required this.displayFont,
    required this.bodyFont,
    required this.labelFont,
    required this.quoteFont,
    this.quoteLetterSpacing = 0.04,
    this.quoteHeight = 1.4,
  });

  final String displayFont;
  final String bodyFont;
  final String labelFont;
  final String quoteFont;
  final double quoteLetterSpacing;
  final double quoteHeight;
}

class _MoodSpec {
  const _MoodSpec({
    required this.colors,
    required this.gradients,
    required this.glass,
    required this.typography,
  });

  final FlowColorTokens colors;
  final FlowGradientTokens gradients;
  final FlowGlassSpec glass;
  final _MoodTypographySpec typography;
}

abstract final class FlowTypography {
  static TextTheme buildTextTheme(
    AppBackgroundTheme mood,
    FlowColorTokens colors,
  ) {
    final spec = _specFor(mood).typography;

    return TextTheme(
      headlineLarge: _font(
        spec.displayFont,
        size: 46,
        weight: FontWeight.w600,
        height: 0.98,
        color: colors.textPrimary,
        letterSpacing: -1.15,
      ),
      headlineMedium: _font(
        spec.displayFont,
        size: 36,
        weight: FontWeight.w600,
        height: 1.0,
        color: colors.textPrimary,
        letterSpacing: -0.75,
      ),
      titleLarge: _font(
        spec.displayFont,
        size: 28,
        weight: FontWeight.w600,
        height: 1.04,
        color: colors.textPrimary,
        letterSpacing: -0.38,
      ),
      titleMedium: _font(
        spec.bodyFont,
        size: 18,
        weight: FontWeight.w700,
        height: 1.22,
        color: colors.textPrimary,
      ),
      titleSmall: _font(
        spec.bodyFont,
        size: 15,
        weight: FontWeight.w700,
        height: 1.18,
        color: colors.textPrimary,
      ),
      bodyLarge: _font(
        spec.bodyFont,
        size: 16,
        weight: FontWeight.w500,
        height: 1.6,
        color: colors.textPrimary,
      ),
      bodyMedium: _font(
        spec.bodyFont,
        size: 14.5,
        weight: FontWeight.w500,
        height: 1.58,
        color: colors.textSecondary,
      ),
      bodySmall: _font(
        spec.bodyFont,
        size: 12.5,
        weight: FontWeight.w500,
        height: 1.5,
        color: colors.textSecondary,
      ),
      labelLarge: _font(
        spec.labelFont,
        size: 12.5,
        weight: FontWeight.w700,
        height: 1.0,
        color: colors.textPrimary,
        letterSpacing: 0.56,
      ),
      labelMedium: _font(
        spec.labelFont,
        size: 11,
        weight: FontWeight.w700,
        height: 1.0,
        color: colors.textSecondary,
        letterSpacing: 0.76,
      ),
      labelSmall: _font(
        spec.labelFont,
        size: 10,
        weight: FontWeight.w700,
        height: 1.0,
        color: colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  static TextStyle quoteStyle({
    required BuildContext context,
    required Color color,
    required double fontSize,
    FontWeight weight = FontWeight.w500,
  }) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final spec = _specFor(
      flow?.mood ?? AppBackgroundTheme.spaceGalaxies,
    ).typography;
    return _font(
      spec.quoteFont,
      size: fontSize,
      weight: weight,
      height: spec.quoteHeight,
      color: color,
      letterSpacing: spec.quoteLetterSpacing,
    );
  }

  static TextStyle _font(
    String name, {
    required double size,
    required FontWeight weight,
    required double height,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.getFont(
      name,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

FlowColorTokens flowColorsFor(AppBackgroundTheme theme) =>
    _specFor(theme).colors;

FlowThemeTokens flowTokensFor(AppBackgroundTheme theme) {
  final spec = _specFor(theme);
  return FlowThemeTokens(
    mood: theme,
    colors: spec.colors,
    gradients: spec.gradients,
    glass: spec.glass,
    shadowColor: Colors.black,
  );
}

double lerpValue(double a, double b, double t) => lerpDouble(a, b, t) ?? a;

_MoodSpec _specFor(AppBackgroundTheme theme) {
  return switch (theme) {
    AppBackgroundTheme.oceanFloor => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF040A12),
        surface: Color(0xCC132130),
        elevatedSurface: Color(0xD91A2B3D),
        textPrimary: Color(0xFFF5FAFF),
        textSecondary: Color(0xC8C6D4E0),
        accent: Color(0xFFD8E9FF),
        accentSecondary: Color(0xFF97D7FF),
        divider: Color(0x4F89A8C0),
        quoteFrame: Color(0xB3172534),
        quoteFrameBorder: Color(0x80D7E7F9),
        quoteFrameGlow: Color(0x3AA6CCF0),
        interactionRipple: Color(0x66B8D9F5),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFFE8F3FF),
        accentEnd: Color(0xFF97D7FF),
        atmosphereTop: Color(0xFF08111C),
        atmosphereBottom: Color(0xFF02050A),
        atmosphereHighlight: Color(0xFF24445F),
        chromeStart: Color(0x99FFFFFF),
        chromeEnd: Color(0x140C1826),
      ),
      glass: FlowGlassSpec(
        blurSigma: 28,
        denseBlurSigma: 34,
        hairlineWidth: 0.55,
        outerShadowOpacity: 0.38,
        innerHighlightOpacity: 0.22,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'Bodoni Moda',
        bodyFont: 'Urbanist',
        labelFont: 'Urbanist',
        quoteFont: 'Bodoni Moda',
        quoteLetterSpacing: 0.03,
        quoteHeight: 1.36,
      ),
    ),
    AppBackgroundTheme.spaceGalaxies => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF020406),
        surface: Color(0xCC0B1014),
        elevatedSurface: Color(0xD9141B21),
        textPrimary: Color(0xFFF6FBF7),
        textSecondary: Color(0xC4C8BBA5),
        accent: Color(0xFFD0A45B),
        accentSecondary: Color(0xFFF0D4A1),
        divider: Color(0x4A746755),
        quoteFrame: Color(0xB10E1418),
        quoteFrameBorder: Color(0x80D3B07A),
        quoteFrameGlow: Color(0x2CD0A45B),
        interactionRipple: Color(0x66D9B26E),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFFD4AB66),
        accentEnd: Color(0xFFF1DAB1),
        atmosphereTop: Color(0xFF091016),
        atmosphereBottom: Color(0xFF020304),
        atmosphereHighlight: Color(0xFF322316),
        chromeStart: Color(0x88FFFFFF),
        chromeEnd: Color(0x140A110D),
      ),
      glass: FlowGlassSpec(
        blurSigma: 30,
        denseBlurSigma: 36,
        hairlineWidth: 0.5,
        outerShadowOpacity: 0.44,
        innerHighlightOpacity: 0.2,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'Cormorant Garamond',
        bodyFont: 'Sora',
        labelFont: 'Sora',
        quoteFont: 'Cormorant Garamond',
        quoteLetterSpacing: 0.05,
        quoteHeight: 1.34,
      ),
    ),
    AppBackgroundTheme.rainyCity => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF05080D),
        surface: Color(0xCC141A22),
        elevatedSurface: Color(0xD9212833),
        textPrimary: Color(0xFFF7F2EA),
        textSecondary: Color(0xC8CFC0AF),
        accent: Color(0xFFE5C58D),
        accentSecondary: Color(0xFFF2DEB7),
        divider: Color(0x4D8B8374),
        quoteFrame: Color(0xB118202A),
        quoteFrameBorder: Color(0x80D5B983),
        quoteFrameGlow: Color(0x2ED9B36E),
        interactionRipple: Color(0x66E5C58D),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFFE2BF82),
        accentEnd: Color(0xFFF2E1BF),
        atmosphereTop: Color(0xFF101620),
        atmosphereBottom: Color(0xFF040609),
        atmosphereHighlight: Color(0xFF2E3946),
        chromeStart: Color(0x85FFFFFF),
        chromeEnd: Color(0x16120F09),
      ),
      glass: FlowGlassSpec(
        blurSigma: 24,
        denseBlurSigma: 30,
        hairlineWidth: 0.55,
        outerShadowOpacity: 0.42,
        innerHighlightOpacity: 0.18,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'Playfair Display',
        bodyFont: 'Instrument Sans',
        labelFont: 'Instrument Sans',
        quoteFont: 'Source Serif 4',
        quoteLetterSpacing: 0.07,
        quoteHeight: 1.42,
      ),
    ),
    AppBackgroundTheme.deepForest => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF040806),
        surface: Color(0xCC101814),
        elevatedSurface: Color(0xD918231E),
        textPrimary: Color(0xFFF4F8F3),
        textSecondary: Color(0xC6C1D0C2),
        accent: Color(0xFF9FD4B0),
        accentSecondary: Color(0xFFD6EEDC),
        divider: Color(0x4B708A78),
        quoteFrame: Color(0xB1121D17),
        quoteFrameBorder: Color(0x809CD1AE),
        quoteFrameGlow: Color(0x2D7FD194),
        interactionRipple: Color(0x669FD4B0),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFF93CDA5),
        accentEnd: Color(0xFFD6EEDC),
        atmosphereTop: Color(0xFF0B140F),
        atmosphereBottom: Color(0xFF030604),
        atmosphereHighlight: Color(0xFF183126),
        chromeStart: Color(0x84FFFFFF),
        chromeEnd: Color(0x140B120D),
      ),
      glass: FlowGlassSpec(
        blurSigma: 22,
        denseBlurSigma: 28,
        hairlineWidth: 0.55,
        outerShadowOpacity: 0.34,
        innerHighlightOpacity: 0.17,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'Crimson Pro',
        bodyFont: 'Manrope',
        labelFont: 'Manrope',
        quoteFont: 'Crimson Pro',
        quoteLetterSpacing: 0.04,
        quoteHeight: 1.43,
      ),
    ),
    AppBackgroundTheme.sunsetCity => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF160B08),
        surface: Color(0xCC24120E),
        elevatedSurface: Color(0xD9321A13),
        textPrimary: Color(0xFFFFF3E8),
        textSecondary: Color(0xC8E5CAB8),
        accent: Color(0xFFFF9B47),
        accentSecondary: Color(0xFFFFD27B),
        divider: Color(0x50A56D52),
        quoteFrame: Color(0xB121120D),
        quoteFrameBorder: Color(0x80FFB363),
        quoteFrameGlow: Color(0x38FF9A43),
        interactionRipple: Color(0x66FFA450),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFFFF8F3A),
        accentEnd: Color(0xFFFFD56B),
        atmosphereTop: Color(0xFF3B150C),
        atmosphereBottom: Color(0xFF120705),
        atmosphereHighlight: Color(0xFF6E321A),
        chromeStart: Color(0x80FFF8F1),
        chromeEnd: Color(0x18A14517),
      ),
      glass: FlowGlassSpec(
        blurSigma: 26,
        denseBlurSigma: 32,
        hairlineWidth: 0.55,
        outerShadowOpacity: 0.38,
        innerHighlightOpacity: 0.2,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'DM Serif Display',
        bodyFont: 'Plus Jakarta Sans',
        labelFont: 'Plus Jakarta Sans',
        quoteFont: 'Literata',
        quoteLetterSpacing: 0.03,
        quoteHeight: 1.4,
      ),
    ),
    AppBackgroundTheme.quoteflowGlow => const _MoodSpec(
      colors: FlowColorTokens(
        background: Color(0xFF020B10),
        surface: Color(0xCC0A1822),
        elevatedSurface: Color(0xD9122230),
        textPrimary: Color(0xFFF1FBFF),
        textSecondary: Color(0xC0B8CDD7),
        accent: Color(0xFF63F5FF),
        accentSecondary: Color(0xFF95FFB8),
        divider: Color(0x4B548C98),
        quoteFrame: Color(0xB10E1D28),
        quoteFrameBorder: Color(0x8074EBF3),
        quoteFrameGlow: Color(0x3263F5FF),
        interactionRipple: Color(0x6663F5FF),
      ),
      gradients: FlowGradientTokens(
        accentStart: Color(0xFF5BEFFF),
        accentEnd: Color(0xFF98FFB7),
        atmosphereTop: Color(0xFF071720),
        atmosphereBottom: Color(0xFF02070B),
        atmosphereHighlight: Color(0xFF143E45),
        chromeStart: Color(0x96EFFFFF),
        chromeEnd: Color(0x160A151F),
      ),
      glass: FlowGlassSpec(
        blurSigma: 32,
        denseBlurSigma: 38,
        hairlineWidth: 0.5,
        outerShadowOpacity: 0.46,
        innerHighlightOpacity: 0.24,
      ),
      typography: _MoodTypographySpec(
        displayFont: 'Space Grotesk',
        bodyFont: 'IBM Plex Sans',
        labelFont: 'IBM Plex Sans',
        quoteFont: 'Space Grotesk',
        quoteLetterSpacing: -0.01,
        quoteHeight: 1.34,
      ),
    ),
  };
}
