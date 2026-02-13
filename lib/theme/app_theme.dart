import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color accent = Color(0xFF7ED6BE);
  static const Color bg = Color(0xFF07130F);
  static const Color card = Color(0xFF10211B);

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        secondary: const Color(0xFF9EE1CF),
        tertiary: const Color(0xFFD3B382),
        surface: card,
      ),
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
          color: Colors.white.withValues(alpha: 0.74),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF11241D).withValues(alpha: 0.78),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF12241D).withValues(alpha: 0.78),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF0C1B16).withValues(alpha: 0.92),
        selectedItemColor: accent,
        unselectedItemColor: Colors.white.withValues(alpha: 0.72),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF173229).withValues(alpha: 0.72),
        selectedColor: accent.withValues(alpha: 0.22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }
}
