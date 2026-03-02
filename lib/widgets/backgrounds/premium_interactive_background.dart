import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme_background.dart';

enum PremiumSceneKind { ocean, space, rain, forest, sunset, glow }

@immutable
class PremiumScenePalette {
  const PremiumScenePalette({
    required this.baseTop,
    required this.baseMid,
    required this.baseBottom,
    required this.accent,
    required this.secondaryAccent,
    required this.particleNear,
    required this.particleFar,
    required this.signature,
    required this.interactionRipple,
    required this.overlayTop,
    required this.overlayBottom,
  });

  final Color baseTop;
  final Color baseMid;
  final Color baseBottom;
  final Color accent;
  final Color secondaryAccent;
  final Color particleNear;
  final Color particleFar;
  final Color signature;
  final Color interactionRipple;
  final Color overlayTop;
  final Color overlayBottom;
}

abstract final class PremiumScenePalettes {
  static const ocean = PremiumScenePalette(
    baseTop: Color(0xFF04161A),
    baseMid: Color(0xFF07242B),
    baseBottom: Color(0xFF030A0F),
    accent: Color(0xFF79C9BC),
    secondaryAccent: Color(0xFF5DA9B0),
    particleNear: Color(0xFFD8F6EE),
    particleFar: Color(0xFF78B7AC),
    signature: Color(0x554DB5A7),
    interactionRipple: Color(0x66A3E0D2),
    overlayTop: Color(0x0A000000),
    overlayBottom: Color(0x8C000000),
  );

  static const space = PremiumScenePalette(
    baseTop: Color(0xFF02060F),
    baseMid: Color(0xFF090F1E),
    baseBottom: Color(0xFF02040A),
    accent: Color(0xFFAFC4F3),
    secondaryAccent: Color(0xFF7C8FBC),
    particleNear: Color(0xFFE7EDFF),
    particleFar: Color(0xFF8799C4),
    signature: Color(0x4A506CB6),
    interactionRipple: Color(0x66BFD2FF),
    overlayTop: Color(0x09000000),
    overlayBottom: Color(0x88000000),
  );

  static const rain = PremiumScenePalette(
    baseTop: Color(0xFF050C13),
    baseMid: Color(0xFF0B1A24),
    baseBottom: Color(0xFF03070C),
    accent: Color(0xFF9DBECE),
    secondaryAccent: Color(0xFF7F97A8),
    particleNear: Color(0xFFD8E6EC),
    particleFar: Color(0xFF7D95A4),
    signature: Color(0x4A7E8FA1),
    interactionRipple: Color(0x66AEC8D8),
    overlayTop: Color(0x0A000000),
    overlayBottom: Color(0x92000000),
  );

  static const forest = PremiumScenePalette(
    baseTop: Color(0xFF040F0A),
    baseMid: Color(0xFF0A1D14),
    baseBottom: Color(0xFF030804),
    accent: Color(0xFFA5D6AE),
    secondaryAccent: Color(0xFF7AA585),
    particleNear: Color(0xFFE0F1DE),
    particleFar: Color(0xFF80A785),
    signature: Color(0x4A6E9A70),
    interactionRipple: Color(0x66BEE2BF),
    overlayTop: Color(0x08000000),
    overlayBottom: Color(0x96000000),
  );

  static const sunset = PremiumScenePalette(
    baseTop: Color(0xFF311E30),
    baseMid: Color(0xFF5A3142),
    baseBottom: Color(0xFF180F19),
    accent: Color(0xFFEAB08A),
    secondaryAccent: Color(0xFFD78877),
    particleNear: Color(0xFFF5E3D5),
    particleFar: Color(0xFFBC8D8E),
    signature: Color(0x55D79784),
    interactionRipple: Color(0x66F2C3A6),
    overlayTop: Color(0x06000000),
    overlayBottom: Color(0x88000000),
  );

  static const glow = PremiumScenePalette(
    baseTop: Color(0xFF1A0F24),
    baseMid: Color(0xFF35203A),
    baseBottom: Color(0xFF1A121D),
    accent: Color(0xFFF0C09F),
    secondaryAccent: Color(0xFFCB96A7),
    particleNear: Color(0xFFF9EBDD),
    particleFar: Color(0xFFC797AB),
    signature: Color(0x59E4A287),
    interactionRipple: Color(0x70F4CCB2),
    overlayTop: Color(0x08000000),
    overlayBottom: Color(0x8A000000),
  );
}

class PremiumInteractiveBackground extends ThemeBackground {
  const PremiumInteractiveBackground({
    super.key,
    required this.scene,
    required this.palette,
    required super.seed,
    required super.motionScale,
    this.loopDuration = const Duration(seconds: 24),
  });

  final PremiumSceneKind scene;
  final PremiumScenePalette palette;
  final Duration loopDuration;

  @override
  State<PremiumInteractiveBackground> createState() =>
      _PremiumInteractiveBackgroundState();
}

class _PremiumInteractiveBackgroundState
    extends ThemeBackgroundState<PremiumInteractiveBackground> {
  static const double _rippleLife = 0.34;

  final List<_AmbientParticle> _particles = <_AmbientParticle>[];
  final List<_LightShaft> _shafts = <_LightShaft>[];
  final List<_RainDrop> _rainDrops = <_RainDrop>[];
  final List<_BokehLight> _bokeh = <_BokehLight>[];
  final List<_SkylineBlock> _skyline = <_SkylineBlock>[];
  final List<_CloudVeil> _clouds = <_CloudVeil>[];
  final List<_WaveBand> _waves = <_WaveBand>[];
  final List<_StarStreak> _streaks = <_StarStreak>[];
  final List<_TouchRipple> _ripples = <_TouchRipple>[];

  @override
  Duration get animationDuration => widget.loopDuration;

  @override
  void initializeScene() {
    _particles.clear();
    _shafts.clear();
    _rainDrops.clear();
    _bokeh.clear();
    _skyline.clear();
    _clouds.clear();
    _waves.clear();
    _streaks.clear();
    _ripples.clear();

    switch (widget.scene) {
      case PremiumSceneKind.ocean:
        _seedParticles(30, baseSize: 0.9);
        for (var i = 0; i < 6; i++) {
          _shafts.add(
            _LightShaft(
              x: random.nextDouble(),
              width: 0.09 + random.nextDouble() * 0.1,
              alpha: 0.04 + random.nextDouble() * 0.07,
              speed: 0.09 + random.nextDouble() * 0.12,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
      case PremiumSceneKind.space:
        _seedParticles(44, baseSize: 0.7);
      case PremiumSceneKind.rain:
        _seedParticles(16, baseSize: 1.4);
        for (var i = 0; i < 76; i++) {
          _rainDrops.add(
            _RainDrop(
              x: random.nextDouble(),
              y: random.nextDouble(),
              speed: 0.6 + random.nextDouble() * 1.5,
              length: 0.015 + random.nextDouble() * 0.03,
              alpha: 0.08 + random.nextDouble() * 0.2,
            ),
          );
        }
        for (var i = 0; i < 11; i++) {
          _bokeh.add(
            _BokehLight(
              x: random.nextDouble(),
              y: 0.42 + random.nextDouble() * 0.55,
              radius: 20 + random.nextDouble() * 44,
              alpha: 0.03 + random.nextDouble() * 0.07,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
        _seedSkyline();
      case PremiumSceneKind.forest:
        _seedParticles(12, baseSize: 1.8);
        for (var i = 0; i < 4; i++) {
          _clouds.add(
            _CloudVeil(
              x: 0.16 + random.nextDouble() * 0.7,
              y: 0.22 + random.nextDouble() * 0.48,
              width: 0.24 + random.nextDouble() * 0.22,
              height: 0.12 + random.nextDouble() * 0.12,
              alpha: 0.03 + random.nextDouble() * 0.05,
              speed: 0.007 + random.nextDouble() * 0.012,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
      case PremiumSceneKind.sunset:
        _seedParticles(16, baseSize: 1.2);
        _seedSkyline();
        for (var i = 0; i < 5; i++) {
          _clouds.add(
            _CloudVeil(
              x: 0.12 + random.nextDouble() * 0.76,
              y: 0.16 + random.nextDouble() * 0.24,
              width: 0.28 + random.nextDouble() * 0.34,
              height: 0.08 + random.nextDouble() * 0.08,
              alpha: 0.06 + random.nextDouble() * 0.08,
              speed: 0.006 + random.nextDouble() * 0.01,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
      case PremiumSceneKind.glow:
        _seedParticles(20, baseSize: 1.0);
        for (var i = 0; i < 6; i++) {
          _waves.add(
            _WaveBand(
              y: 0.3 + i * 0.09,
              amplitude: 6 + random.nextDouble() * 9,
              wavelength: 220 + random.nextDouble() * 200,
              speed: 0.45 + random.nextDouble() * 0.35,
              thickness: 1.3 + random.nextDouble() * 1.7,
              alpha: 0.08 + random.nextDouble() * 0.09,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
    }
  }

  void _seedParticles(int count, {required double baseSize}) {
    for (var i = 0; i < count; i++) {
      final depth = random.nextDouble();
      _particles.add(
        _AmbientParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          vx: (random.nextDouble() - 0.5) * (0.001 + depth * 0.0022),
          vy: (random.nextDouble() - 0.5) * (0.0008 + depth * 0.0018),
          depth: depth,
          size: baseSize + depth * 2.2,
          alpha: 0.03 + depth * 0.13,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void _seedSkyline() {
    var x = 0.0;
    while (x < 1.0) {
      final width = 0.035 + random.nextDouble() * 0.06;
      _skyline.add(
        _SkylineBlock(
          x: x,
          width: width,
          height: 0.09 + random.nextDouble() * 0.22,
          alpha: 0.5 + random.nextDouble() * 0.3,
        ),
      );
      x += width + 0.004 + random.nextDouble() * 0.01;
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    for (final particle in _particles) {
      particle.x +=
          particle.vx * deltaSeconds * (0.36 + widget.motionScale * 0.26);
      particle.y +=
          particle.vy * deltaSeconds * (0.36 + widget.motionScale * 0.2);
      particle.vx += math.sin(elapsedSeconds * 0.13 + particle.phase) * 0.00003;
      particle.vy += math.cos(elapsedSeconds * 0.1 + particle.phase) * 0.00002;
      final damping = (1 - 0.16 * deltaSeconds).clamp(0.9, 1.0);
      particle.vx *= damping;
      particle.vy *= damping;

      if (particle.x < -0.08) particle.x = 1.08;
      if (particle.x > 1.08) particle.x = -0.08;
      if (particle.y < -0.08) particle.y = 1.08;
      if (particle.y > 1.08) particle.y = -0.08;
    }

    if (widget.scene == PremiumSceneKind.rain) {
      for (final drop in _rainDrops) {
        drop.y += deltaSeconds * drop.speed * 0.52;
        drop.x += deltaSeconds * 0.02;
        if (drop.y > 1.08) {
          drop.y = -0.05;
          drop.x = random.nextDouble();
        }
        if (drop.x > 1.05) drop.x = -0.05;
      }
    }

    for (final cloud in _clouds) {
      cloud.x += deltaSeconds * cloud.speed;
      if (cloud.x > 1.25) cloud.x = -0.18;
    }

    if (widget.scene == PremiumSceneKind.space) {
      for (final streak in _streaks) {
        streak.progress += deltaSeconds * streak.speed;
      }
      _streaks.removeWhere((streak) => streak.progress >= 1);
      if (_streaks.length < 3 && random.nextDouble() < deltaSeconds * 0.08) {
        _streaks.add(
          _StarStreak(
            x: 0.12 + random.nextDouble() * 0.76,
            y: 0.08 + random.nextDouble() * 0.5,
            length: 0.12 + random.nextDouble() * 0.15,
            speed: 0.2 + random.nextDouble() * 0.35,
            alpha: 0.2 + random.nextDouble() * 0.24,
          ),
        );
      }
    }

    _ripples.removeWhere((r) => elapsedSeconds - r.startTime > r.lifeSeconds);
  }

  @override
  void onScenePointer(BackgroundInteraction interaction) {
    if (interaction.phase != ThemePointerPhase.down) return;

    if (_ripples.length > 7) {
      _ripples.removeAt(0);
    }
    _ripples.add(
      _TouchRipple(
        center: interaction.localPosition,
        startTime: interaction.elapsedSeconds,
        lifeSeconds: _rippleLife,
      ),
    );

    final nx = interaction.normalizedPosition.dx;
    final ny = interaction.normalizedPosition.dy;
    for (final particle in _particles) {
      final dx = particle.x - nx;
      final dy = particle.y - ny;
      final distSq = dx * dx + dy * dy;
      if (distSq <= 0 || distSq > 0.04) continue;
      final dist = math.sqrt(distSq);
      final falloff = (0.2 - dist) / 0.2;
      final impulse = 0.0024 * falloff;
      particle.vx += (dx / (dist + 0.0001)) * impulse;
      particle.vy += (dy / (dist + 0.0001)) * impulse;
    }
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _PremiumInteractivePainter(
        animation: repaint,
        scene: widget.scene,
        palette: widget.palette,
        particles: _particles,
        shafts: _shafts,
        rainDrops: _rainDrops,
        bokeh: _bokeh,
        skyline: _skyline,
        clouds: _clouds,
        waves: _waves,
        streaks: _streaks,
        ripples: _ripples,
        parallax: parallaxAlignment,
        loopSeconds: widget.loopDuration.inMilliseconds / 1000,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PremiumInteractivePainter extends CustomPainter {
  _PremiumInteractivePainter({
    required this.animation,
    required this.scene,
    required this.palette,
    required this.particles,
    required this.shafts,
    required this.rainDrops,
    required this.bokeh,
    required this.skyline,
    required this.clouds,
    required this.waves,
    required this.streaks,
    required this.ripples,
    required this.parallax,
    required this.loopSeconds,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final PremiumSceneKind scene;
  final PremiumScenePalette palette;
  final List<_AmbientParticle> particles;
  final List<_LightShaft> shafts;
  final List<_RainDrop> rainDrops;
  final List<_BokehLight> bokeh;
  final List<_SkylineBlock> skyline;
  final List<_CloudVeil> clouds;
  final List<_WaveBand> waves;
  final List<_StarStreak> streaks;
  final List<_TouchRipple> ripples;
  final Alignment parallax;
  final double loopSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = animation.value * loopSeconds;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, palette.baseMid, palette.baseBottom],
        stops: const [0, 0.58, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    _paintCoreAtmosphere(canvas, size, elapsed);

    switch (scene) {
      case PremiumSceneKind.ocean:
        _paintOcean(canvas, size, elapsed);
      case PremiumSceneKind.space:
        _paintSpace(canvas, size, elapsed);
      case PremiumSceneKind.rain:
        _paintRain(canvas, size, elapsed);
      case PremiumSceneKind.forest:
        _paintForest(canvas, size, elapsed);
      case PremiumSceneKind.sunset:
        _paintSunset(canvas, size, elapsed);
      case PremiumSceneKind.glow:
        _paintGlow(canvas, size, elapsed);
    }

    _paintParticles(canvas, size, elapsed);
    _paintRipples(canvas, size, elapsed);

    final overlay = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.overlayTop, Colors.transparent, palette.overlayBottom],
        stops: const [0, 0.46, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, overlay);
  }

  void _paintCoreAtmosphere(Canvas canvas, Size size, double elapsed) {
    final glowA = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.32 + math.sin(elapsed * 0.05) * 0.05 + parallax.x * 0.08,
          -0.26 + parallax.y * 0.06,
        ),
        radius: 1.2,
        colors: [palette.signature, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glowA);

    final glowB = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          0.5 + math.cos(elapsed * 0.04 + 1.3) * 0.05 + parallax.x * 0.06,
          0.28 + parallax.y * 0.05,
        ),
        radius: 1.08,
        colors: [
          palette.secondaryAccent.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glowB);
  }

  void _paintOcean(Canvas canvas, Size size, double elapsed) {
    for (final shaft in shafts) {
      final centerX =
          (shaft.x + math.sin(elapsed * shaft.speed + shaft.phase) * 0.04) *
              size.width +
          parallax.x * 20;
      final rect = Rect.fromLTWH(
        centerX - shaft.width * size.width * 0.5,
        -size.height * 0.2,
        shaft.width * size.width,
        size.height * 1.5,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.accent.withValues(alpha: shaft.alpha),
            Colors.transparent,
          ],
          stops: const [0, 1],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawRect(rect, paint);
    }

    final caustics = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0
      ..color = palette.accent.withValues(alpha: 0.08);

    for (var i = 0; i < 10; i++) {
      final y = size.height * (0.08 + i * 0.08);
      final path = Path()..moveTo(-12, y);
      for (double x = -12; x <= size.width + 12; x += 14) {
        final wave = math.sin((x * 0.024) + (elapsed * 0.7) + i) * 5;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, caustics);
    }
  }

  void _paintSpace(Canvas canvas, Size size, double elapsed) {
    final nebula = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.24 + parallax.x * 0.06, -0.36 + parallax.y * 0.05),
        radius: 0.9,
        colors: [
          palette.secondaryAccent.withValues(alpha: 0.24),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, nebula);

    for (final streak in streaks) {
      final progress = streak.progress.clamp(0.0, 1.0);
      final start = Offset(
        (streak.x + progress * 0.26) * size.width + parallax.x * 8,
        (streak.y + progress * 0.18) * size.height,
      );
      final end = Offset(
        start.dx - streak.length * size.width,
        start.dy - streak.length * size.height * 0.6,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy);
      final paint = Paint()
        ..color = palette.particleNear.withValues(
          alpha: streak.alpha * (1 - progress),
        )
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      canvas.drawPath(path, paint);
    }

    final v = math.sin(elapsed * 0.1) * 0.04;
    final haze = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.36 + v, -0.12),
        radius: 1.08,
        colors: [palette.accent.withValues(alpha: 0.1), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, haze);
  }

  void _paintRain(Canvas canvas, Size size, double elapsed) {
    _paintSkyline(canvas, size, palette.accent.withValues(alpha: 0.18));

    for (final light in bokeh) {
      final cx =
          light.x * size.width +
          math.sin(elapsed * 0.2 + light.phase) * 6 +
          parallax.x * 10;
      final cy =
          light.y * size.height + math.cos(elapsed * 0.14 + light.phase) * 3;
      final rect = Rect.fromCircle(
        center: Offset(cx, cy),
        radius: light.radius,
      );
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.secondaryAccent.withValues(alpha: light.alpha),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(Offset(cx, cy), light.radius, paint);
    }

    final rainPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = palette.particleNear.withValues(alpha: 0.2);
    for (final drop in rainDrops) {
      final x = drop.x * size.width + parallax.x * 8;
      final y = drop.y * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 3, y + drop.length * size.height),
        rainPaint..color = palette.particleNear.withValues(alpha: drop.alpha),
      );
    }
  }

  void _paintForest(Canvas canvas, Size size, double elapsed) {
    final canopyPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.25)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.1,
        size.width * 0.58,
        size.height * 0.32,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      canopyPath,
      Paint()..color = Colors.black.withValues(alpha: 0.23),
    );

    for (final cloud in clouds) {
      final cx =
          cloud.x * size.width +
          math.sin(elapsed * 0.1 + cloud.phase) * 10 +
          parallax.x * 12;
      final cy =
          cloud.y * size.height +
          math.cos(elapsed * 0.08 + cloud.phase) * 5 +
          parallax.y * 7;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: cloud.width * size.width,
        height: cloud.height * size.height,
      );
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.secondaryAccent.withValues(alpha: cloud.alpha),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawOval(rect, paint);
    }
  }

  void _paintSunset(Canvas canvas, Size size, double elapsed) {
    final horizon = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, 0.35 + parallax.y * 0.03),
        radius: 0.58,
        colors: [palette.accent.withValues(alpha: 0.34), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, horizon);

    for (final cloud in clouds) {
      final cx =
          cloud.x * size.width +
          math.sin(elapsed * 0.08 + cloud.phase) * 10 +
          parallax.x * 8;
      final cy =
          cloud.y * size.height + math.cos(elapsed * 0.06 + cloud.phase) * 4;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: cloud.width * size.width,
        height: cloud.height * size.height,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            palette.particleNear.withValues(alpha: cloud.alpha),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(44)),
        paint,
      );
    }

    _paintSkyline(canvas, size, Colors.black.withValues(alpha: 0.32));
  }

  void _paintGlow(Canvas canvas, Size size, double elapsed) {
    final bloom = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, -0.25 + parallax.y * 0.05),
        radius: 0.88,
        colors: [palette.accent.withValues(alpha: 0.3), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bloom);

    for (final wave in waves) {
      final y = wave.y * size.height;
      final path = Path()..moveTo(-24, y);
      for (double x = -24; x <= size.width + 24; x += 10) {
        final waveValue =
            math.sin(
              (x / wave.wavelength) * math.pi * 2 +
                  elapsed * wave.speed +
                  wave.phase,
            ) *
            wave.amplitude;
        path.lineTo(x + parallax.x * 12, y + waveValue + parallax.y * 7);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wave.thickness
        ..strokeCap = StrokeCap.round
        ..color = palette.particleNear.withValues(alpha: wave.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.4);
      canvas.drawPath(path, paint);
    }
  }

  void _paintSkyline(Canvas canvas, Size size, Color color) {
    if (skyline.isEmpty) return;
    final paint = Paint()..color = color;
    for (final block in skyline) {
      final rect = Rect.fromLTWH(
        block.x * size.width,
        size.height * (1 - block.height),
        block.width * size.width,
        block.height * size.height,
      );
      canvas.drawRect(
        rect,
        paint..color = color.withValues(alpha: block.alpha),
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size, double elapsed) {
    for (final particle in particles) {
      final twinkle = 0.7 + 0.3 * math.sin(elapsed * 0.9 + particle.phase);
      final color = Color.lerp(
        palette.particleFar,
        palette.particleNear,
        particle.depth,
      )!;
      final px =
          particle.x * size.width +
          parallax.x * size.width * 0.04 * (0.35 + particle.depth * 0.8);
      final py =
          particle.y * size.height +
          parallax.y * size.height * 0.03 * (0.35 + particle.depth * 0.8);
      canvas.drawCircle(
        Offset(px, py),
        particle.size,
        Paint()
          ..color = color.withValues(
            alpha: (particle.alpha * twinkle).clamp(0.015, 0.24),
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            0.9 + particle.depth * 1.8,
          ),
      );
    }
  }

  void _paintRipples(Canvas canvas, Size size, double elapsed) {
    for (final ripple in ripples) {
      final age = elapsed - ripple.startTime;
      if (age < 0) continue;
      final progress = (age / ripple.lifeSeconds).clamp(0.0, 1.0);
      final eased = _easeOutCubic(progress);
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = lerpDouble(18, 196, eased) ?? 18;

      final bloomRect = Rect.fromCircle(
        center: ripple.center,
        radius: radius + 34,
      );
      final bloom = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.interactionRipple.withValues(alpha: alpha * 0.24),
            Colors.transparent,
          ],
        ).createShader(bloomRect);
      canvas.drawCircle(ripple.center, radius + 34, bloom);

      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = palette.interactionRipple.withValues(alpha: alpha * 0.42);
      canvas.drawCircle(ripple.center, radius, ring);
      canvas.drawCircle(ripple.center, radius * 0.62, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumInteractivePainter oldDelegate) => false;
}

double _easeOutCubic(double t) {
  final clamped = t.clamp(0.0, 1.0);
  final p = 1 - clamped;
  return 1 - p * p * p;
}

class _AmbientParticle {
  _AmbientParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.depth,
    required this.size,
    required this.alpha,
    required this.phase,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double depth;
  final double size;
  final double alpha;
  final double phase;
}

class _LightShaft {
  const _LightShaft({
    required this.x,
    required this.width,
    required this.alpha,
    required this.speed,
    required this.phase,
  });

  final double x;
  final double width;
  final double alpha;
  final double speed;
  final double phase;
}

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.alpha,
  });

  double x;
  double y;
  final double speed;
  final double length;
  final double alpha;
}

class _BokehLight {
  const _BokehLight({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double phase;
}

class _SkylineBlock {
  const _SkylineBlock({
    required this.x,
    required this.width,
    required this.height,
    required this.alpha,
  });

  final double x;
  final double width;
  final double height;
  final double alpha;
}

class _CloudVeil {
  _CloudVeil({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.alpha,
    required this.speed,
    required this.phase,
  });

  double x;
  final double y;
  final double width;
  final double height;
  final double alpha;
  final double speed;
  final double phase;
}

class _WaveBand {
  const _WaveBand({
    required this.y,
    required this.amplitude,
    required this.wavelength,
    required this.speed,
    required this.thickness,
    required this.alpha,
    required this.phase,
  });

  final double y;
  final double amplitude;
  final double wavelength;
  final double speed;
  final double thickness;
  final double alpha;
  final double phase;
}

class _StarStreak {
  _StarStreak({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.alpha,
  });

  final double x;
  final double y;
  final double length;
  final double speed;
  final double alpha;
  double progress = 0;
}

class _TouchRipple {
  const _TouchRipple({
    required this.center,
    required this.startTime,
    required this.lifeSeconds,
  });

  final Offset center;
  final double startTime;
  final double lifeSeconds;
}

class OceanPremiumBackground extends PremiumInteractiveBackground {
  const OceanPremiumBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.ocean,
         palette: PremiumScenePalettes.ocean,
         loopDuration: const Duration(seconds: 26),
       );
}

class SpacePremiumBackground extends PremiumInteractiveBackground {
  const SpacePremiumBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.space,
         palette: PremiumScenePalettes.space,
         loopDuration: const Duration(seconds: 28),
       );
}

class RainPremiumBackground extends PremiumInteractiveBackground {
  const RainPremiumBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.rain,
         palette: PremiumScenePalettes.rain,
         loopDuration: const Duration(seconds: 18),
       );
}

class ForestPremiumBackground extends PremiumInteractiveBackground {
  const ForestPremiumBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.forest,
         palette: PremiumScenePalettes.forest,
         loopDuration: const Duration(seconds: 24),
       );
}

class SunsetPremiumBackground extends PremiumInteractiveBackground {
  const SunsetPremiumBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.sunset,
         palette: PremiumScenePalettes.sunset,
         loopDuration: const Duration(seconds: 22),
       );
}

class QuoteFlowFlagshipBackground extends PremiumInteractiveBackground {
  const QuoteFlowFlagshipBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  }) : super(
         scene: PremiumSceneKind.glow,
         palette: PremiumScenePalettes.glow,
         loopDuration: const Duration(seconds: 24),
       );
}
