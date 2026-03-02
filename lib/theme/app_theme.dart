import 'package:flutter/material.dart';

import '../features/v3_background/background_theme_provider.dart';
import 'design_tokens.dart';

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

class AppTheme {
  static ThemeData darkThemeFor(AppBackgroundTheme backgroundTheme) {
    final flow = flowTokensFor(backgroundTheme);
    final colors = flow.colors;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          surface: colors.surface,
          primary: colors.accent,
          secondary: colors.accent.withValues(alpha: 0.88),
          tertiary: colors.accent.withValues(alpha: 0.78),
          onSurface: colors.textPrimary,
          onPrimary: colors.background,
          outline: colors.divider,
          outlineVariant: colors.divider.withValues(alpha: 0.55),
          shadow: Colors.black,
          scrim: const Color(0xFF030406),
        );

    final legacyTokens = AppThemeTokens(
      glassFill: colors.surface.withValues(alpha: 0.62),
      glassBorder: colors.divider.withValues(alpha: 0.7),
      glassShadow: Colors.black.withValues(alpha: 0.3),
      chipBase: colors.elevatedSurface.withValues(alpha: 0.74),
      chipSelected: colors.accent.withValues(alpha: 0.2),
      chipBorder: colors.divider,
      chipGlow: colors.accent.withValues(alpha: 0.26),
      viewerAccent: colors.accent,
    );

    final textTheme = FlowTypography.buildTextTheme(colors);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      colorScheme: scheme,
      dividerColor: colors.divider,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[flow, legacyTokens],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colors.surface.withValues(alpha: 0.7),
        foregroundColor: colors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: colors.surface.withValues(alpha: 0.92),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevatedSurface.withValues(alpha: 0.9),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary.withValues(alpha: 0.92),
        ),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.lg,
          vertical: FlowSpace.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FlowRadii.radiusMd,
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FlowRadii.radiusMd,
          borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.86)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          hoverColor: colors.accent.withValues(alpha: 0.12),
          highlightColor: colors.accent.withValues(alpha: 0.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusMd),
        backgroundColor: colors.elevatedSurface.withValues(alpha: 0.96),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.32),
        selectionHandleColor: colors.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.background,
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusMd),
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.sm,
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.divider.withValues(alpha: 0.95)),
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusMd),
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.sm,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface.withValues(alpha: 0.82),
        selectedColor: colors.accent.withValues(alpha: 0.24),
        disabledColor: colors.surface.withValues(alpha: 0.48),
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.pill(999)),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.sm,
          vertical: FlowSpace.xs,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
    );
  }
}
