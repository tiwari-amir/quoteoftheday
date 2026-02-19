import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/v3_background/background_theme_provider.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.glassFill,
    required this.glassBorder,
    required this.glassShadow,
    required this.chipBase,
    required this.chipSelected,
    required this.chipBorder,
    required this.chipGlow,
    required this.viewerAccent,
  });

  final Color glassFill;
  final Color glassBorder;
  final Color glassShadow;
  final Color chipBase;
  final Color chipSelected;
  final Color chipBorder;
  final Color chipGlow;
  final Color viewerAccent;

  @override
  AppThemeTokens copyWith({
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Color? chipBase,
    Color? chipSelected,
    Color? chipBorder,
    Color? chipGlow,
    Color? viewerAccent,
  }) {
    return AppThemeTokens(
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      chipBase: chipBase ?? this.chipBase,
      chipSelected: chipSelected ?? this.chipSelected,
      chipBorder: chipBorder ?? this.chipBorder,
      chipGlow: chipGlow ?? this.chipGlow,
      viewerAccent: viewerAccent ?? this.viewerAccent,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t) ?? glassShadow,
      chipBase: Color.lerp(chipBase, other.chipBase, t) ?? chipBase,
      chipSelected:
          Color.lerp(chipSelected, other.chipSelected, t) ?? chipSelected,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t) ?? chipBorder,
      chipGlow: Color.lerp(chipGlow, other.chipGlow, t) ?? chipGlow,
      viewerAccent:
          Color.lerp(viewerAccent, other.viewerAccent, t) ?? viewerAccent,
    );
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.scaffold,
    required this.surface,
    required this.navBar,
    required this.inputFill,
    required this.viewerAccent,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color scaffold;
  final Color surface;
  final Color navBar;
  final Color inputFill;
  final Color viewerAccent;
}

class AppTheme {
  static ThemeData darkThemeFor(AppBackgroundTheme backgroundTheme) {
    final palette = _paletteFor(backgroundTheme);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: palette.primary,
          secondary: palette.secondary,
          tertiary: palette.tertiary,
          surface: palette.surface,
          onPrimary: _onColorFor(palette.primary),
          onSecondary: _onColorFor(palette.secondary),
          onTertiary: _onColorFor(palette.tertiary),
          onSurface: Colors.white.withValues(alpha: 0.96),
          outline: palette.secondary.withValues(alpha: 0.35),
          shadow: Colors.black,
          scrim: const Color(0xFF010203),
        );

    final tokens = AppThemeTokens(
      glassFill: scheme.surface.withValues(alpha: 0.55),
      glassBorder: Colors.white.withValues(alpha: 0.18),
      glassShadow: Colors.black.withValues(alpha: 0.3),
      chipBase: scheme.surface.withValues(alpha: 0.7),
      chipSelected: scheme.primary.withValues(alpha: 0.24),
      chipBorder: scheme.secondary.withValues(alpha: 0.44),
      chipGlow: scheme.primary.withValues(alpha: 0.33),
      viewerAccent: palette.viewerAccent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.scaffold,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );

    return base.copyWith(
      textTheme: GoogleFonts.nunitoSansTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.lora(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.lora(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.nunitoSans(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.92),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.nunitoSans(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.76),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withValues(alpha: 0.76),
        elevation: 2,
        shadowColor: tokens.glassShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface.withValues(alpha: 0.46),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.92),
          foregroundColor: _onColorFor(scheme.primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: scheme.secondary.withValues(alpha: 0.42)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBar.withValues(alpha: 0.94),
        selectedItemColor: scheme.primary,
        unselectedItemColor: Colors.white.withValues(alpha: 0.72),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.chipBase,
        selectedColor: tokens.chipSelected,
        side: BorderSide(color: tokens.chipBorder.withValues(alpha: 0.42)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static _ThemePalette _paletteFor(AppBackgroundTheme theme) {
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => const _ThemePalette(
        primary: Color(0xFF7ED6BE),
        secondary: Color(0xFF9EE1CF),
        tertiary: Color(0xFFD3B382),
        scaffold: Color(0xFF07130F),
        surface: Color(0xFF11241D),
        navBar: Color(0xFF0C1B16),
        inputFill: Color(0xC712241D),
        viewerAccent: Color(0xFF79C7B6),
      ),
      AppBackgroundTheme.spaceGalaxies => const _ThemePalette(
        primary: Color(0xFF8DB1FF),
        secondary: Color(0xFFB4C6FF),
        tertiary: Color(0xFF8EE5FF),
        scaffold: Color(0xFF070B17),
        surface: Color(0xFF151D36),
        navBar: Color(0xFF0D142B),
        inputFill: Color(0xC7151D36),
        viewerAccent: Color(0xFF97BAFF),
      ),
      AppBackgroundTheme.rainyCity => const _ThemePalette(
        primary: Color(0xFF78C6E3),
        secondary: Color(0xFFA2D8EC),
        tertiary: Color(0xFFB9CFE0),
        scaffold: Color(0xFF08131C),
        surface: Color(0xFF112331),
        navBar: Color(0xFF0D1A27),
        inputFill: Color(0xC6112331),
        viewerAccent: Color(0xFF8ED3EA),
      ),
      AppBackgroundTheme.deepForest => const _ThemePalette(
        primary: Color(0xFF8DDEA5),
        secondary: Color(0xFFB0E9C0),
        tertiary: Color(0xFFCEE4A5),
        scaffold: Color(0xFF06140C),
        surface: Color(0xFF11241A),
        navBar: Color(0xFF0B1A12),
        inputFill: Color(0xC611241A),
        viewerAccent: Color(0xFF97E2AF),
      ),
      AppBackgroundTheme.sunsetCity => const _ThemePalette(
        primary: Color(0xFFFFB67A),
        secondary: Color(0xFFFF9EAD),
        tertiary: Color(0xFFFFD69F),
        scaffold: Color(0xFF1A111B),
        surface: Color(0xFF332131),
        navBar: Color(0xFF241824),
        inputFill: Color(0xC7332131),
        viewerAccent: Color(0xFFFFC58E),
      ),
    };
  }

  static Color _onColorFor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
