import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/v3_background/background_theme_provider.dart';
import 'backgrounds/premium_interactive_background.dart';

class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, this.seed = 0, this.motionScale = 1.0});

  final int seed;
  final double motionScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appBackgroundThemeProvider);
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => OceanPremiumBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.spaceGalaxies => SpacePremiumBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.rainyCity => RainPremiumBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.deepForest => ForestPremiumBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.sunsetCity => SunsetPremiumBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.quoteflowGlow => QuoteFlowFlagshipBackground(
        seed: seed,
        motionScale: motionScale,
      ),
    };
  }
}
