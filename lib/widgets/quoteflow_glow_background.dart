import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'backgrounds/theme_background.dart';
import 'backgrounds/theme_color_definitions.dart';

class QuoteFlowGlowBackground extends ThemeBackground {
  const QuoteFlowGlowBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<QuoteFlowGlowBackground> createState() =>
      _QuoteFlowGlowBackgroundState();
}

class _QuoteFlowGlowBackgroundState
    extends ThemeBackgroundState<QuoteFlowGlowBackground> {
  final List<_GlowDust> _dust = <_GlowDust>[];
  final List<_LightVeil> _veils = <_LightVeil>[];
  final List<_RadialBloom> _blooms = <_RadialBloom>[];

  @override
  Duration get animationDuration => const Duration(seconds: 34);

  @override
  void initializeScene() {
    _dust.clear();
    _veils.clear();

    for (var i = 0; i < 18; i++) {
      _dust.add(
        _GlowDust(
          x: random.nextDouble(),
          y: random.nextDouble(),
          driftX: (random.nextDouble() - 0.5) * 0.0028,
          driftY: (random.nextDouble() - 0.5) * 0.0019,
          radius: 0.7 + random.nextDouble() * 1.5,
          alpha: 0.04 + random.nextDouble() * 0.12,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    for (var i = 0; i < 3; i++) {
      _veils.add(
        _LightVeil(
          x: 0.22 + i * 0.3 + random.nextDouble() * 0.04,
          y: 0.36 + random.nextDouble() * 0.12,
          width: 0.28 + random.nextDouble() * 0.16,
          height: 0.2 + random.nextDouble() * 0.12,
          alpha: 0.07 + random.nextDouble() * 0.06,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.4 + widget.motionScale * 0.15).clamp(0.25, 0.64);
    for (final dust in _dust) {
      dust.x += dust.driftX * deltaSeconds * driftScale;
      dust.y += dust.driftY * deltaSeconds * driftScale;
      dust.y += math.sin(elapsedSeconds * 0.08 + dust.phase) * 0.00005;
      if (dust.x < -0.04) dust.x = 1.04;
      if (dust.x > 1.04) dust.x = -0.04;
      if (dust.y < -0.04) dust.y = 1.04;
      if (dust.y > 1.04) dust.y = -0.04;
    }

    _blooms.removeWhere(
      (bloom) => elapsedSeconds - bloom.startSeconds > bloom.life,
    );
  }

  @override
  void onSceneTap(Offset localPosition) {
    final now = (controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    if (_blooms.length > 4) {
      _blooms.removeAt(0);
    }
    _blooms.add(
      _RadialBloom(center: localPosition, startSeconds: now, life: 2.3),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _QuoteFlowGlowPainter(
        animation: repaint,
        dust: _dust,
        veils: _veils,
        blooms: _blooms,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _QuoteFlowGlowPainter extends CustomPainter {
  _QuoteFlowGlowPainter({
    required this.animation,
    required this.dust,
    required this.veils,
    required this.blooms,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_GlowDust> dust;
  final List<_LightVeil> veils;
  final List<_RadialBloom> blooms;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.glow;
    final elapsed = animation.value * 34.0;

    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF120A1D),
          Color(0xFF241432),
          Color(0xFF45233F),
          Color(0xFF794A4B),
        ],
        stops: <double>[0.0, 0.42, 0.74, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final dawnGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.0, 0.3 + math.sin(elapsed * 0.05) * 0.015),
        radius: 0.86,
        colors: <Color>[
          palette.hazeA.withValues(alpha: 0.42),
          palette.hazeB.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.56, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, dawnGlow);

    for (final veil in veils) {
      final cx =
          (veil.x + math.sin(elapsed * 0.06 + veil.phase) * 0.02) * size.width;
      final cy =
          (veil.y + math.cos(elapsed * 0.05 + veil.phase) * 0.014) *
          size.height;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: veil.width * size.width,
        height: veil.height * size.height,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = const Color(0xFFFFD6B8).withValues(alpha: veil.alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    _paintWaveBand(
      canvas,
      size,
      y: 0.62 + math.sin(elapsed * 0.08) * 0.008,
      amplitude: 16,
      phase: 0.2,
      color: const Color(0x5CF5C8A5),
    );
    _paintWaveBand(
      canvas,
      size,
      y: 0.72 + math.sin(elapsed * 0.07 + 1.3) * 0.01,
      amplitude: 20,
      phase: 1.15,
      color: const Color(0x4DD89DB6),
    );
    _paintWaveBand(
      canvas,
      size,
      y: 0.8 + math.sin(elapsed * 0.06 + 2.3) * 0.01,
      amplitude: 17,
      phase: 2.1,
      color: const Color(0x36765D8E),
    );

    for (final particle in dust) {
      final px = particle.x * size.width;
      final py = particle.y * size.height;
      final twinkle = 0.65 + 0.35 * math.sin(elapsed * 0.85 + particle.phase);
      final alpha = (particle.alpha * twinkle).clamp(0.02, 0.18);
      canvas.drawCircle(
        Offset(px, py),
        particle.radius,
        Paint()
          ..color = const Color(0xFFFFEEDB).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    for (final bloom in blooms) {
      final age = (elapsed - bloom.startSeconds).clamp(0.0, bloom.life);
      final progress = age / bloom.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 20 + progress * 150;
      canvas.drawCircle(
        bloom.center,
        radius + 22,
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  const Color(0xFFFFE0BE).withValues(alpha: alpha * 0.24),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(center: bloom.center, radius: radius + 22),
              ),
      );
    }

    final glaze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0x09000000), Color(0x4B000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  void _paintWaveBand(
    Canvas canvas,
    Size size, {
    required double y,
    required double amplitude,
    required double phase,
    required Color color,
  }) {
    final path = Path();
    final yBase = size.height * y;
    path.moveTo(0, yBase);

    const segments = 8;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = size.width * t;
      final offset = math.sin(t * math.pi * 2 + phase) * amplitude;
      path.lineTo(x, yBase + offset);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QuoteFlowGlowPainter oldDelegate) => false;
}

class _GlowDust {
  _GlowDust({
    required this.x,
    required this.y,
    required this.driftX,
    required this.driftY,
    required this.radius,
    required this.alpha,
    required this.phase,
  });

  double x;
  double y;
  final double driftX;
  final double driftY;
  final double radius;
  final double alpha;
  final double phase;
}

class _LightVeil {
  const _LightVeil({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.alpha,
    required this.phase,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double alpha;
  final double phase;
}

class _RadialBloom {
  const _RadialBloom({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}
