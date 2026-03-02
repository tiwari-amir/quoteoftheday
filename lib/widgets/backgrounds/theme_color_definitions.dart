import 'package:flutter/material.dart';

@immutable
class ThemeColorSet {
  const ThemeColorSet({
    required this.baseTop,
    required this.baseBottom,
    required this.hazeA,
    required this.hazeB,
    required this.accent,
  });

  final Color baseTop;
  final Color baseBottom;
  final Color hazeA;
  final Color hazeB;
  final Color accent;
}

/// Restrained, cinematic palettes for all motion environments.
abstract final class ThemeColorDefinitions {
  static const ocean = ThemeColorSet(
    baseTop: Color(0xFF0A2328),
    baseBottom: Color(0xFF050C10),
    hazeA: Color(0x224DAEA5),
    hazeB: Color(0x18316F73),
    accent: Color(0x6694D9D0),
  );

  static const space = ThemeColorSet(
    baseTop: Color(0xFF070D1A),
    baseBottom: Color(0xFF02040A),
    hazeA: Color(0x20253D76),
    hazeB: Color(0x16202A4D),
    accent: Color(0x66D7DEEA),
  );

  static const rain = ThemeColorSet(
    baseTop: Color(0xFF0C1A24),
    baseBottom: Color(0xFF050A10),
    hazeA: Color(0x1C6A8EA0),
    hazeB: Color(0x141F2D39),
    accent: Color(0x66A7C6CF),
  );

  static const forest = ThemeColorSet(
    baseTop: Color(0xFF07140F),
    baseBottom: Color(0xFF030905),
    hazeA: Color(0x1B395640),
    hazeB: Color(0x12131F17),
    accent: Color(0x6698B589),
  );

  static const sunset = ThemeColorSet(
    baseTop: Color(0xFF4A3248),
    baseBottom: Color(0xFF1B1521),
    hazeA: Color(0x2CC58B90),
    hazeB: Color(0x1E6A4F65),
    accent: Color(0x66F2C3A2),
  );

  static const glow = ThemeColorSet(
    baseTop: Color(0xFF120A1D),
    baseBottom: Color(0xFF1B1224),
    hazeA: Color(0x33F5B783),
    hazeB: Color(0x22D28CB2),
    accent: Color(0x66FFE1B9),
  );
}
