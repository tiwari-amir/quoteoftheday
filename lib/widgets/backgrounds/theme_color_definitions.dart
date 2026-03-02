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
    baseTop: Color(0xFF081E24),
    baseBottom: Color(0xFF03090E),
    hazeA: Color(0x223F9B94),
    hazeB: Color(0x172A5E64),
    accent: Color(0x6685C8BC),
  );

  static const space = ThemeColorSet(
    baseTop: Color(0xFF050A14),
    baseBottom: Color(0xFF010308),
    hazeA: Color(0x201E3364),
    hazeB: Color(0x161C2642),
    accent: Color(0x66BBCFE2),
  );

  static const rain = ThemeColorSet(
    baseTop: Color(0xFF091721),
    baseBottom: Color(0xFF03080E),
    hazeA: Color(0x1C5F8192),
    hazeB: Color(0x141A2732),
    accent: Color(0x669AB9C4),
  );

  static const forest = ThemeColorSet(
    baseTop: Color(0xFF05110C),
    baseBottom: Color(0xFF010703),
    hazeA: Color(0x1A304A37),
    hazeB: Color(0x12101813),
    accent: Color(0x6687A680),
  );

  static const sunset = ThemeColorSet(
    baseTop: Color(0xFF3C2C3E),
    baseBottom: Color(0xFF14111B),
    hazeA: Color(0x2CAD828A),
    hazeB: Color(0x1E5F4C60),
    accent: Color(0x66DFB79D),
  );

  static const glow = ThemeColorSet(
    baseTop: Color(0xFF100918),
    baseBottom: Color(0xFF160E1F),
    hazeA: Color(0x33E0AF87),
    hazeB: Color(0x22B38AA7),
    accent: Color(0x66F0D3B8),
  );
}
