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
  static const int _particleCount = 38;
  static const int _columnCount = 5;
  static const int _causticCount = 4;

  final List<_SiltParticle> _particles = <_SiltParticle>[];
  final List<_LightColumn> _columns = <_LightColumn>[];
  final List<_CausticBand> _caustics = <_CausticBand>[];
  final List<_TapRipple> _ripples = <_TapRipple>[];

  @override
  Duration get animationDuration => const Duration(seconds: 28);

  @override
  void initializeScene() {
    _particles.clear();
    _columns.clear();
    _caustics.clear();

    for (var i = 0; i < _particleCount; i++) {
      _particles.add(
        _SiltParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          driftX: (random.nextDouble() - 0.5) * 0.0045,
          driftY: -(0.0012 + random.nextDouble() * 0.0028),
          radius: 0.5 + random.nextDouble() * 1.6,
          alpha: 0.05 + random.nextDouble() * 0.12,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    for (var i = 0; i < _columnCount; i++) {
      _columns.add(
        _LightColumn(
          x: 0.08 + (i / (_columnCount - 1)) * 0.84,
          width: 0.16 + random.nextDouble() * 0.12,
          alpha: 0.05 + random.nextDouble() * 0.07,
          phase: random.nextDouble() * math.pi * 2,
          tilt: -0.07 + random.nextDouble() * 0.14,
        ),
      );
    }

    for (var i = 0; i < _causticCount; i++) {
      _caustics.add(
        _CausticBand(
          y: 0.24 + i * 0.13 + random.nextDouble() * 0.04,
          amplitude: 10 + random.nextDouble() * 12,
          speed: 0.17 + random.nextDouble() * 0.18,
          phase: random.nextDouble() * math.pi * 2,
          alpha: 0.035 + random.nextDouble() * 0.035,
        ),
      );
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.46 + widget.motionScale * 0.18).clamp(0.3, 0.82);

    for (final particle in _particles) {
      final sineDrift =
          math.sin(elapsedSeconds * 0.13 + particle.phase) * 0.00006;
      particle.x += (particle.driftX + sineDrift) * deltaSeconds * driftScale;
      particle.y += particle.driftY * deltaSeconds * driftScale;

      if (particle.x < -0.05) particle.x = 1.05;
      if (particle.x > 1.05) particle.x = -0.05;
      if (particle.y < -0.05) particle.y = 1.05;
    }

    for (final caustic in _caustics) {
      caustic.phase += deltaSeconds * caustic.speed * 0.45;
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
        columns: _columns,
        caustics: _caustics,
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
    required this.columns,
    required this.caustics,
    required this.ripples,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_SiltParticle> particles;
  final List<_LightColumn> columns;
  final List<_CausticBand> caustics;
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
        colors: [palette.baseTop, const Color(0xFF08151A), palette.baseBottom],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final topGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.0, -0.86 + math.sin(elapsed * 0.07) * 0.02),
        radius: 1.2,
        colors: [palette.hazeA, palette.hazeB, Colors.transparent],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topGlow);

    for (final column in columns) {
      final shift = math.sin(elapsed * 0.08 + column.phase) * 0.04;
      final centerX = (column.x + shift).clamp(-0.2, 1.2);
      final rect = Rect.fromLTWH(
        size.width * (centerX - column.width * 0.5),
        0,
        size.width * column.width,
        size.height,
      );
      final ray = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.accent.withValues(alpha: column.alpha),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.save();
      canvas.translate(size.width * centerX, 0);
      canvas.rotate(column.tilt);
      canvas.translate(-size.width * centerX, 0);
      canvas.drawRect(rect, ray);
      canvas.restore();
    }

    for (final band in caustics) {
      _paintCausticBand(
        canvas,
        size,
        elapsed: elapsed,
        y: band.y,
        amplitude: band.amplitude,
        phase: band.phase,
        alpha: band.alpha,
      );
    }

    final seabed = Path()
      ..moveTo(0, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.26,
        size.height * 0.76,
        size.width * 0.58,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.86,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      seabed,
      Paint()..color = const Color(0xAA061013).withValues(alpha: 0.7),
    );

    for (final particle in particles) {
      final px = particle.x * size.width;
      final py = particle.y * size.height;
      final twinkle = 0.75 + 0.25 * math.sin(elapsed * 0.7 + particle.phase);
      final alpha = (particle.alpha * twinkle).clamp(0.03, 0.18);
      final radius = particle.radius * (0.9 + twinkle * 0.2);
      final paint = Paint()
        ..color = const Color(0xFFCFEDE6).withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          0.8 + particle.radius * 0.8,
        );
      canvas.drawCircle(Offset(px, py), radius, paint);
    }

    for (final ripple in ripples) {
      final age = (elapsed - ripple.startSeconds).clamp(0.0, ripple.life);
      final progress = age / ripple.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 18 + progress * 185;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..color = const Color(0xFFCCE6E2).withValues(alpha: alpha * 0.24);
      final bloom = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xCC89C9BF).withValues(alpha: alpha * 0.11),
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

  void _paintCausticBand(
    Canvas canvas,
    Size size, {
    required double elapsed,
    required double y,
    required double amplitude,
    required double phase,
    required double alpha,
  }) {
    final path = Path();
    final baseY = size.height * y;
    const segments = 9;
    path.moveTo(0, baseY);
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = size.width * t;
      final wobble =
          math.sin((t * math.pi * 2.3) + phase + elapsed * 0.35) * amplitude;
      path.lineTo(x, baseY + wobble);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFD9FFF8).withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OceanPainter oldDelegate) => false;
}

class _SiltParticle {
  _SiltParticle({
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

class _LightColumn {
  const _LightColumn({
    required this.x,
    required this.width,
    required this.alpha,
    required this.phase,
    required this.tilt,
  });

  final double x;
  final double width;
  final double alpha;
  final double phase;
  final double tilt;
}

class _CausticBand {
  _CausticBand({
    required this.y,
    required this.amplitude,
    required this.speed,
    required this.phase,
    required this.alpha,
  });

  final double y;
  final double amplitude;
  final double speed;
  double phase;
  final double alpha;
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
