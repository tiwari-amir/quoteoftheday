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
  final List<_GlowSparkle> _sparkles = <_GlowSparkle>[];
  final List<_RadialBloom> _blooms = <_RadialBloom>[];

  @override
  Duration get animationDuration => const Duration(seconds: 32);

  @override
  void initializeScene() {
    _sparkles.clear();
    for (var i = 0; i < 12; i++) {
      _sparkles.add(
        _GlowSparkle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          driftX: (random.nextDouble() - 0.5) * 0.003,
          driftY: (random.nextDouble() - 0.5) * 0.0024,
          radius: 0.6 + random.nextDouble() * 1.4,
          alpha: 0.06 + random.nextDouble() * 0.12,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.45 + widget.motionScale * 0.14).clamp(0.24, 0.66);
    for (final sparkle in _sparkles) {
      sparkle.x += sparkle.driftX * deltaSeconds * driftScale;
      sparkle.y += sparkle.driftY * deltaSeconds * driftScale;
      sparkle.y += math.sin(elapsedSeconds * 0.09 + sparkle.phase) * 0.00005;
      if (sparkle.x < -0.04) sparkle.x = 1.04;
      if (sparkle.x > 1.04) sparkle.x = -0.04;
      if (sparkle.y < -0.04) sparkle.y = 1.04;
      if (sparkle.y > 1.04) sparkle.y = -0.04;
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
      _RadialBloom(center: localPosition, startSeconds: now, life: 2.4),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _QuoteFlowGlowPainter(
        animation: repaint,
        sparkles: _sparkles,
        blooms: _blooms,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _QuoteFlowGlowPainter extends CustomPainter {
  _QuoteFlowGlowPainter({
    required this.animation,
    required this.sparkles,
    required this.blooms,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_GlowSparkle> sparkles;
  final List<_RadialBloom> blooms;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.glow;
    final elapsed = animation.value * 32.0;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, const Color(0xFF4E3554), palette.baseBottom],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final horizon = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, 0.28 + math.sin(elapsed * 0.05) * 0.02),
        radius: 0.82,
        colors: [palette.hazeA, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, horizon);

    _paintWaveBand(
      canvas,
      size,
      y: 0.62 + math.sin(elapsed * 0.08) * 0.01,
      amplitude: 18,
      phase: 0.2,
      color: const Color(0x66F3C89F),
    );
    _paintWaveBand(
      canvas,
      size,
      y: 0.72 + math.sin(elapsed * 0.07 + 1.3) * 0.012,
      amplitude: 22,
      phase: 1.1,
      color: const Color(0x55DF9AB2),
    );
    _paintWaveBand(
      canvas,
      size,
      y: 0.8 + math.sin(elapsed * 0.06 + 2.2) * 0.01,
      amplitude: 20,
      phase: 2.2,
      color: const Color(0x44836AA9),
    );

    for (final sparkle in sparkles) {
      final px = sparkle.x * size.width;
      final py = sparkle.y * size.height;
      final twinkle = 0.65 + 0.35 * math.sin(elapsed * 0.9 + sparkle.phase);
      final paint = Paint()
        ..color = const Color(
          0xFFFFF1D6,
        ).withValues(alpha: (sparkle.alpha * twinkle).clamp(0.02, 0.18))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawCircle(Offset(px, py), sparkle.radius, paint);
    }

    for (final bloom in blooms) {
      final age = (elapsed - bloom.startSeconds).clamp(0.0, bloom.life);
      final progress = age / bloom.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 20 + progress * 150;
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFE0B8).withValues(alpha: alpha * 0.24),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: bloom.center, radius: radius + 20),
            );
      canvas.drawCircle(bloom.center, radius + 20, paint);
    }

    final glaze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x10000000), Color(0x4A000000)],
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

class _GlowSparkle {
  _GlowSparkle({
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
