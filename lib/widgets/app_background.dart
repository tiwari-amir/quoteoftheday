import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/v3_background/background_theme_provider.dart';
import 'animated_gradient_background.dart';
import 'backgrounds/forest_background.dart';
import 'backgrounds/rain_background.dart';
import 'backgrounds/space_background.dart';
import 'backgrounds/sunset_background.dart';
import 'quoteflow_glow_background.dart';

class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, this.seed = 0, this.motionScale = 1.0});

  final int seed;
  final double motionScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appBackgroundThemeProvider);
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => AnimatedGradientBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.spaceGalaxies => SpaceBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.rainyCity => RainBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.deepForest => ForestBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.sunsetCity => SunsetBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.quoteflowGlow => QuoteFlowGlowBackground(
        seed: seed,
        motionScale: motionScale,
      ),
    };
  }
}
