import 'package:flutter/material.dart';

import 'backgrounds/premium_interactive_background.dart';
import 'backgrounds/theme_background.dart';

/// Backward-compatible entry point for the Ocean Floor scene.
///
/// Existing app code calls:
/// - [AnimatedGradientBackground.emitGlobalRipple]
/// - [AnimatedGradientBackground.globalRippleStream]
///
/// Those calls now route through [ThemeTouchBus].
class AnimatedGradientBackground extends OceanPremiumBackground {
  const AnimatedGradientBackground({
    super.key,
    super.seed = 0,
    super.motionScale = 1.0,
  });

  static Stream<Offset> get globalRippleStream => ThemeTouchBus.stream;

  static void emitGlobalPointerDown(Offset globalPosition) {
    ThemeTouchBus.emitDown(globalPosition);
  }

  static void emitGlobalPointerMove(Offset globalPosition) {
    ThemeTouchBus.emitMove(globalPosition);
  }

  static void emitGlobalPointerUp(Offset globalPosition) {
    ThemeTouchBus.emitUp(globalPosition);
  }

  static void emitGlobalRipple(Offset globalPosition) {
    emitGlobalPointerDown(globalPosition);
  }
}
