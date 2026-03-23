import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/performance_profile_provider.dart';
import 'app_background.dart';

class EditorialBackground extends ConsumerWidget {
  const EditorialBackground({
    super.key,
    this.seed = 77,
    this.motionScale = 1.0,
  });

  final int seed;
  final double motionScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appPerformanceProfileProvider);
    if (!profile.allowDecorativeBackgroundPainter) {
      return const _LiteEditorialBackground();
    }
    return AppBackground(seed: seed, motionScale: motionScale);
  }
}

class _LiteEditorialBackground extends StatelessWidget {
  const _LiteEditorialBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF081018),
              const Color(0xFF0B131B),
              const Color(0xFF090E14),
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.18),
                  radius: 1.08,
                  colors: [
                    const Color(0xFFD6A55C).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
