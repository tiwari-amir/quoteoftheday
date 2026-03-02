import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_background.dart';
import 'theme_color_definitions.dart';

class ForestBackground extends ThemeBackground {
  const ForestBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<ForestBackground> createState() => _ForestBackgroundState();
}

class _ForestBackgroundState extends ThemeBackgroundState<ForestBackground> {
  final List<_ForestOrb> _orbs = <_ForestOrb>[];
  final List<_GlowPulse> _tapGlows = <_GlowPulse>[];

  @override
  Duration get animationDuration => const Duration(seconds: 30);

  @override
  void initializeScene() {
    _orbs.clear();
    for (var i = 0; i < 14; i++) {
      _orbs.add(
        _ForestOrb(
          x: random.nextDouble(),
          y: 0.12 + random.nextDouble() * 0.8,
          driftX: (random.nextDouble() - 0.5) * 0.004,
          driftY: (random.nextDouble() - 0.5) * 0.003,
          radius: 8 + random.nextDouble() * 16,
          intensity: 0.18 + random.nextDouble() * 0.22,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.45 + widget.motionScale * 0.16).clamp(0.25, 0.7);
    for (final orb in _orbs) {
      orb.x += orb.driftX * deltaSeconds * driftScale;
      orb.y += orb.driftY * deltaSeconds * driftScale;
      orb.x += math.sin(elapsedSeconds * 0.12 + orb.phase) * 0.00005;
      orb.y += math.cos(elapsedSeconds * 0.1 + orb.phase) * 0.00005;

      if (orb.x < -0.05) orb.x = 1.05;
      if (orb.x > 1.05) orb.x = -0.05;
      if (orb.y < 0.05) orb.y = 0.95;
      if (orb.y > 0.95) orb.y = 0.05;
    }

    _tapGlows.removeWhere(
      (glow) => elapsedSeconds - glow.startSeconds > glow.life,
    );
  }

  @override
  void onSceneTap(Offset localPosition) {
    final now = (controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    if (_tapGlows.length > 4) {
      _tapGlows.removeAt(0);
    }
    _tapGlows.add(
      _GlowPulse(center: localPosition, startSeconds: now, life: 2.6),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _ForestPainter(
        animation: repaint,
        orbs: _orbs,
        tapGlows: _tapGlows,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ForestPainter extends CustomPainter {
  _ForestPainter({
    required this.animation,
    required this.orbs,
    required this.tapGlows,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_ForestOrb> orbs;
  final List<_GlowPulse> tapGlows;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.forest;
    final elapsed = animation.value * 30.0;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, palette.baseBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final canopy = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xAA000000), Color(0x22000000), Color(0x00000000)],
        stops: [0.0, 0.36, 0.82],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, canopy);

    final atmosphere = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.28 + math.sin(elapsed * 0.06) * 0.06, 0.2),
        radius: 1.1,
        colors: [palette.hazeA, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, atmosphere);

    final fogRect = Rect.fromLTWH(
      0,
      size.height * (0.58 + math.sin(elapsed * 0.08) * 0.015),
      size.width,
      size.height * 0.4,
    );
    final fog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.hazeB, Colors.transparent],
      ).createShader(fogRect);
    canvas.drawRect(fogRect, fog);

    for (final orb in orbs) {
      final px = orb.x * size.width;
      final py = orb.y * size.height;
      final pulse = 0.78 + 0.22 * math.sin(elapsed * 0.9 + orb.phase);
      final radius = orb.radius * pulse;
      final alpha = orb.intensity * pulse;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFC9DF9E).withValues(alpha: alpha * 0.42),
            const Color(0x669BB273).withValues(alpha: alpha * 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: radius));
      canvas.drawCircle(Offset(px, py), radius, paint);
    }

    for (final glow in tapGlows) {
      final age = (elapsed - glow.startSeconds).clamp(0.0, glow.life);
      final progress = age / glow.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 22 + progress * 150;
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFC3D89C).withValues(alpha: alpha * 0.2),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: glow.center, radius: radius + 24),
            );
      canvas.drawCircle(glow.center, radius + 24, paint);
    }

    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x1A000000), Color(0x77000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _ForestPainter oldDelegate) => false;
}

class _ForestOrb {
  _ForestOrb({
    required this.x,
    required this.y,
    required this.driftX,
    required this.driftY,
    required this.radius,
    required this.intensity,
    required this.phase,
  });

  double x;
  double y;
  final double driftX;
  final double driftY;
  final double radius;
  final double intensity;
  final double phase;
}

class _GlowPulse {
  const _GlowPulse({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}
