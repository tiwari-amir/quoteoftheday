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
    final gradients = flow.gradients;
    final glass = flow.glass;

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: colors.accent,
      onPrimary: colors.background,
      secondary: colors.accentSecondary,
      onSecondary: colors.background,
      error: const Color(0xFFFF6C6C),
      onError: Colors.black,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      tertiary: gradients.accentEnd,
      onTertiary: colors.background,
      outline: colors.divider,
      outlineVariant: colors.divider.withValues(alpha: 0.62),
      shadow: Colors.black,
      scrim: const Color(0xF2020306),
      surfaceContainerHighest: colors.elevatedSurface,
    );

    final legacyTokens = AppThemeTokens(
      glassFill: colors.surface.withValues(alpha: 0.72),
      glassBorder: colors.divider.withValues(alpha: 0.92),
      glassShadow: Colors.black.withValues(alpha: glass.outerShadowOpacity),
      chipBase: colors.elevatedSurface.withValues(alpha: 0.86),
      chipSelected: colors.accent.withValues(alpha: 0.2),
      chipBorder: colors.divider.withValues(alpha: 0.86),
      chipGlow: colors.accent.withValues(alpha: 0.24),
      viewerAccent: colors.accent,
    );

    final textTheme = FlowTypography.buildTextTheme(backgroundTheme, colors);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      colorScheme: scheme,
      dividerColor: colors.divider,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[flow, legacyTokens],
      splashColor: colors.accent.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      disabledColor: colors.textSecondary.withValues(alpha: 0.42),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface.withValues(alpha: 0.78),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusXl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevatedSurface.withValues(alpha: 0.68),
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
          borderRadius: FlowRadii.radiusLg,
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.8),
            width: glass.hairlineWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FlowRadii.radiusLg,
          borderSide: BorderSide(
            color: colors.accent.withValues(alpha: 0.96),
            width: glass.hairlineWidth,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: FlowRadii.radiusLg,
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.68),
            width: glass.hairlineWidth,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
          overlayColor: WidgetStatePropertyAll(
            colors.accent.withValues(alpha: 0.08),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
        backgroundColor: colors.elevatedSurface.withValues(alpha: 0.96),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.24),
        selectionHandleColor: colors.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
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
          side: BorderSide(
            color: colors.divider.withValues(alpha: 0.92),
            width: glass.hairlineWidth,
          ),
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.sm,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface.withValues(alpha: 0.72),
        selectedColor: colors.accent.withValues(alpha: 0.18),
        disabledColor: colors.surface.withValues(alpha: 0.38),
        side: BorderSide(
          color: colors.divider.withValues(alpha: 0.8),
          width: glass.hairlineWidth,
        ),
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.pill(999)),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.sm,
          vertical: FlowSpace.xs,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider.withValues(alpha: 0.72),
        thickness: glass.hairlineWidth,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.divider.withValues(alpha: 0.34),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gradients.accentStart.withValues(alpha: 0.62);
          }
          return colors.divider.withValues(alpha: 0.56);
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentSecondary;
          }
          return colors.textPrimary.withValues(alpha: 0.92);
        }),
      ),
    );
  }
}
