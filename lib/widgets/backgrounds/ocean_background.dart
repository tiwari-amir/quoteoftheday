import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_background.dart';
import 'theme_color_definitions.dart';

class OceanBackground extends ThemeBackground {
  const OceanBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends ThemeBackgroundState<OceanBackground> {
  static const int _particleCount = 30;
  static const int _silhouetteCount = 3;

  final List<_DriftParticle> _particles = <_DriftParticle>[];
  final List<_FishSilhouette> _silhouettes = <_FishSilhouette>[];
  final List<_TapRipple> _ripples = <_TapRipple>[];

  @override
  Duration get animationDuration => const Duration(seconds: 28);

  @override
  void initializeScene() {
    _particles.clear();
    _silhouettes.clear();
    for (var i = 0; i < _particleCount; i++) {
      _particles.add(
        _DriftParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          driftX: (random.nextDouble() - 0.5) * 0.006,
          driftY: -(0.002 + random.nextDouble() * 0.004),
          radius: 0.6 + random.nextDouble() * 1.8,
          depth: random.nextDouble(),
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    for (var i = 0; i < _silhouetteCount; i++) {
      _silhouettes.add(
        _FishSilhouette(
          x: -0.2 + random.nextDouble() * 1.2,
          y: 0.25 + random.nextDouble() * 0.55,
          length: 80 + random.nextDouble() * 70,
          height: 16 + random.nextDouble() * 12,
          speed: 0.004 + random.nextDouble() * 0.006,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.45 + widget.motionScale * 0.18).clamp(0.3, 0.8);

    for (final particle in _particles) {
      final sineDrift =
          math.sin(elapsedSeconds * 0.17 + particle.phase) * 0.00008;
      particle.x += (particle.driftX + sineDrift) * deltaSeconds * driftScale;
      particle.y += particle.driftY * deltaSeconds * driftScale;

      if (particle.x < -0.05) particle.x = 1.05;
      if (particle.x > 1.05) particle.x = -0.05;
      if (particle.y < -0.05) particle.y = 1.05;
    }

    for (final silhouette in _silhouettes) {
      silhouette.x += silhouette.speed * deltaSeconds * driftScale;
      if (silhouette.x > 1.25) {
        silhouette.x = -0.25;
      }
    }

    _ripples.removeWhere(
      (ripple) => elapsedSeconds - ripple.startSeconds > ripple.life,
    );
  }

  @override
  void onSceneTap(Offset localPosition) {
    final now = (controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    if (_ripples.length > 5) {
      _ripples.removeAt(0);
    }
    _ripples.add(
      _TapRipple(center: localPosition, startSeconds: now, life: 2.4),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _OceanPainter(
        animation: repaint,
        particles: _particles,
        silhouettes: _silhouettes,
        ripples: _ripples,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _OceanPainter extends CustomPainter {
  _OceanPainter({
    required this.animation,
    required this.particles,
    required this.silhouettes,
    required this.ripples,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_DriftParticle> particles;
  final List<_FishSilhouette> silhouettes;
  final List<_TapRipple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.ocean;
    final t = animation.value;
    final elapsed = t * 28.0;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, palette.baseBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final topGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.9),
        radius: 1.2,
        colors: [palette.hazeA, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topGlow);

    for (var i = 0; i < 5; i++) {
      final shift = math.sin(elapsed * 0.11 + i * 0.8) * 0.035;
      final centerX = (i + 0.6) / 5 + shift;
      final rect = Rect.fromLTWH(
        size.width * (centerX - 0.1),
        0,
        size.width * 0.22,
        size.height,
      );
      final ray = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.accent.withValues(alpha: 0.12), Colors.transparent],
        ).createShader(rect);
      canvas.save();
      canvas.translate(size.width * centerX, 0);
      canvas.rotate(-0.06 + i * 0.03);
      canvas.translate(-size.width * centerX, 0);
      canvas.drawRect(rect, ray);
      canvas.restore();
    }

    for (final particle in particles) {
      final px = particle.x * size.width;
      final py = particle.y * size.height;
      final alpha = (0.05 + particle.depth * 0.11).clamp(0.04, 0.16);
      final blur = 1.2 + particle.depth * 2.2;
      final radius = particle.radius * (0.85 + particle.depth * 0.45);
      final paint = Paint()
        ..color = const Color(0xFFD8FFF5).withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawCircle(Offset(px, py), radius, paint);
    }

    for (final silhouette in silhouettes) {
      final cx = silhouette.x * size.width;
      final cy =
          (silhouette.y + math.sin(elapsed * 0.08 + silhouette.phase) * 0.01) *
          size.height;
      final path = Path()
        ..moveTo(cx + silhouette.length * 0.5, cy)
        ..quadraticBezierTo(
          cx + silhouette.length * 0.15,
          cy - silhouette.height * 0.55,
          cx - silhouette.length * 0.42,
          cy - silhouette.height * 0.22,
        )
        ..quadraticBezierTo(
          cx - silhouette.length * 0.57,
          cy,
          cx - silhouette.length * 0.42,
          cy + silhouette.height * 0.22,
        )
        ..quadraticBezierTo(
          cx + silhouette.length * 0.15,
          cy + silhouette.height * 0.55,
          cx + silhouette.length * 0.5,
          cy,
        )
        ..close();
      final paint = Paint()
        ..color = const Color(0xAA0C1A1B).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawPath(path, paint);
    }

    for (final ripple in ripples) {
      final age = (elapsed - ripple.startSeconds).clamp(0.0, ripple.life);
      final progress = age / ripple.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 16 + progress * 180;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFD5FFF6).withValues(alpha: alpha * 0.18);
      final bloom = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xCC9FDAD2).withValues(alpha: alpha * 0.09),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: ripple.center, radius: radius + 24),
            );
      canvas.drawCircle(ripple.center, radius + 24, bloom);
      canvas.drawCircle(ripple.center, radius, ring);
    }

    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x11000000), Color(0x55000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _OceanPainter oldDelegate) => false;
}

class _DriftParticle {
  _DriftParticle({
    required this.x,
    required this.y,
    required this.driftX,
    required this.driftY,
    required this.radius,
    required this.depth,
    required this.phase,
  });

  double x;
  double y;
  final double driftX;
  final double driftY;
  final double radius;
  final double depth;
  final double phase;
}

class _FishSilhouette {
  _FishSilhouette({
    required this.x,
    required this.y,
    required this.length,
    required this.height,
    required this.speed,
    required this.phase,
  });

  double x;
  final double y;
  final double length;
  final double height;
  final double speed;
  final double phase;
}

class _TapRipple {
  const _TapRipple({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}
