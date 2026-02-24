import 'package:flutter/material.dart';

import 'backgrounds/ocean_background.dart';
import 'backgrounds/theme_background.dart';

/// Backward-compatible entry point for the Ocean Floor scene.
///
/// Existing app code calls:
/// - [AnimatedGradientBackground.emitGlobalRipple]
/// - [AnimatedGradientBackground.globalRippleStream]
///
/// Those calls now route through [ThemeTouchBus].
class AnimatedGradientBackground extends OceanBackground {
  const AnimatedGradientBackground({
    super.key,
    super.seed = 0,
    super.motionScale = 1.0,
  });

  static Stream<Offset> get globalRippleStream => ThemeTouchBus.stream;

  static void emitGlobalRipple(Offset globalPosition) {
    ThemeTouchBus.emit(globalPosition);
  }
}
