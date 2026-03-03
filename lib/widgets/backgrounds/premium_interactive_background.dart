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
  final List<_StarStreak> _streaks = <_StarStreak>[];
  final List<_TouchRipple> _ripples = <_TouchRipple>[];
  final List<_FishSprite> _fish = <_FishSprite>[];
  final List<_CityStar> _cityStars = <_CityStar>[];
  final List<_OrbitAsteroid> _asteroids = <_OrbitAsteroid>[];
  final List<_ForestBug> _forestBugs = <_ForestBug>[];
  final List<_LeafShape> _leafShapes = <_LeafShape>[];

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
    _streaks.clear();
    _ripples.clear();
    _fish.clear();
    _cityStars.clear();
    _asteroids.clear();
    _forestBugs.clear();
    _leafShapes.clear();

    switch (widget.scene) {
      case PremiumSceneKind.ocean:
        _seedParticles(20, baseSize: 0.9);
        for (var i = 0; i < 5; i++) {
          _shafts.add(
            _LightShaft(
              x: random.nextDouble(),
              width: 0.12 + random.nextDouble() * 0.12,
              alpha: 0.05 + random.nextDouble() * 0.05,
              speed: 0.08 + random.nextDouble() * 0.1,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
        for (var i = 0; i < 7; i++) {
          final fromLeft = random.nextBool();
          _fish.add(
            _FishSprite(
              x: fromLeft
                  ? -0.2 - random.nextDouble() * 0.3
                  : 1.2 + random.nextDouble() * 0.2,
              y: 0.2 + random.nextDouble() * 0.55,
              speed: 0.03 + random.nextDouble() * 0.05,
              scale: 0.5 + random.nextDouble() * 0.9,
              alpha: 0.08 + random.nextDouble() * 0.08,
              phase: random.nextDouble() * math.pi * 2,
              direction: fromLeft ? 1 : -1,
            ),
          );
        }
      case PremiumSceneKind.space:
        _seedParticles(50, baseSize: 0.7);
        for (var i = 0; i < 11; i++) {
          _asteroids.add(
            _OrbitAsteroid(
              orbitRadius: 0.09 + random.nextDouble() * 0.09,
              angle: random.nextDouble() * math.pi * 2,
              speed: 0.07 + random.nextDouble() * 0.07,
              size: 1.5 + random.nextDouble() * 2.8,
              tilt: -0.4 + random.nextDouble() * 0.8,
            ),
          );
        }
      case PremiumSceneKind.rain:
        _seedParticles(16, baseSize: 1.2);
        for (var i = 0; i < 80; i++) {
          _rainDrops.add(
            _RainDrop(
              x: random.nextDouble(),
              y: random.nextDouble(),
              speed: 0.6 + random.nextDouble() * 1.6,
              length: 0.015 + random.nextDouble() * 0.03,
              alpha: 0.08 + random.nextDouble() * 0.16,
            ),
          );
        }
        for (var i = 0; i < 12; i++) {
          _bokeh.add(
            _BokehLight(
              x: random.nextDouble(),
              y: 0.38 + random.nextDouble() * 0.57,
              radius: 18 + random.nextDouble() * 40,
              alpha: 0.02 + random.nextDouble() * 0.06,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
        _seedSkyline(allowTower: false);
        _seedCityStars(18);
      case PremiumSceneKind.forest:
        _seedParticles(12, baseSize: 1.5);
        for (var i = 0; i < 5; i++) {
          _clouds.add(
            _CloudVeil(
              x: 0.08 + random.nextDouble() * 0.84,
              y: 0.2 + random.nextDouble() * 0.5,
              width: 0.26 + random.nextDouble() * 0.2,
              height: 0.13 + random.nextDouble() * 0.14,
              alpha: 0.03 + random.nextDouble() * 0.05,
              speed: 0.006 + random.nextDouble() * 0.01,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
        for (var i = 0; i < 14; i++) {
          _forestBugs.add(
            _ForestBug(
              x: random.nextDouble(),
              y: 0.18 + random.nextDouble() * 0.68,
              vx: (random.nextDouble() - 0.5) * 0.05,
              vy: (random.nextDouble() - 0.5) * 0.04,
              radius: 1.4 + random.nextDouble() * 1.8,
              glow: 0.1 + random.nextDouble() * 0.14,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
        for (var i = 0; i < 16; i++) {
          _leafShapes.add(
            _LeafShape(
              x: random.nextDouble(),
              y: random.nextDouble() * 0.35,
              scale: 0.06 + random.nextDouble() * 0.13,
              rotation: -0.9 + random.nextDouble() * 1.8,
              alpha: 0.06 + random.nextDouble() * 0.08,
            ),
          );
        }
      case PremiumSceneKind.sunset:
        _seedParticles(16, baseSize: 1.1);
        _seedSkyline(allowTower: true);
        _seedCityStars(9);
        for (var i = 0; i < 6; i++) {
          _clouds.add(
            _CloudVeil(
              x: 0.08 + random.nextDouble() * 0.84,
              y: 0.12 + random.nextDouble() * 0.26,
              width: 0.26 + random.nextDouble() * 0.28,
              height: 0.08 + random.nextDouble() * 0.08,
              alpha: 0.05 + random.nextDouble() * 0.07,
              speed: 0.006 + random.nextDouble() * 0.009,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
      case PremiumSceneKind.glow:
        _seedParticles(22, baseSize: 1.0);
        for (var i = 0; i < 14; i++) {
          final leftCluster = i.isEven;
          _leafShapes.add(
            _LeafShape(
              x: leftCluster
                  ? random.nextDouble() * 0.22
                  : 0.78 + random.nextDouble() * 0.22,
              y: random.nextDouble() * 0.62,
              scale: 0.08 + random.nextDouble() * 0.18,
              rotation: leftCluster
                  ? -1.0 + random.nextDouble() * 0.45
                  : 0.55 + random.nextDouble() * 0.45,
              alpha: 0.08 + random.nextDouble() * 0.1,
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

  void _seedCityStars(int count) {
    for (var i = 0; i < count; i++) {
      _cityStars.add(
        _CityStar(
          x: random.nextDouble(),
          y: 0.02 + random.nextDouble() * 0.3,
          radius: 0.5 + random.nextDouble() * 1.1,
          alpha: 0.04 + random.nextDouble() * 0.14,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void _seedSkyline({required bool allowTower}) {
    var x = 0.0;
    final towerIndex = allowTower ? random.nextInt(7) + 2 : -1;
    var i = 0;
    while (x < 1.02) {
      final width = 0.048 + random.nextDouble() * 0.07;
      final isTower = random.nextDouble() < 0.22;
      final height = isTower
          ? 0.22 + random.nextDouble() * 0.2
          : 0.14 + random.nextDouble() * 0.18;
      final crownHeight = isTower
          ? 0.018 + random.nextDouble() * 0.04
          : random.nextDouble() < 0.3
          ? 0.01 + random.nextDouble() * 0.02
          : 0.0;
      final crownInset = crownHeight > 0
          ? 0.1 + random.nextDouble() * 0.24
          : 0.0;
      final isStepped = random.nextDouble() < 0.28;
      final windows = <_WindowCell>[];
      final columns = math.max(1, (width / 0.014).floor());
      final rows = math.max(2, (height / 0.025).floor());
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          if (random.nextDouble() < 0.46) continue;
          windows.add(
            _WindowCell(
              nx: (col + 0.16) / columns,
              ny: (row + 0.24) / rows,
              widthFactor: 0.5 / columns,
              heightFactor: 0.48 / rows,
              alpha: 0.18 + random.nextDouble() * 0.5,
              phase: random.nextDouble() * math.pi * 2,
            ),
          );
        }
      }
      _skyline.add(
        _SkylineBlock(
          x: x,
          width: width,
          height: height,
          alpha: 0.42 + random.nextDouble() * 0.24,
          windows: windows,
          hasTowerLight: i == towerIndex,
          crownHeight: crownHeight,
          crownInset: crownInset,
          isStepped: isStepped,
        ),
      );
      x += width + 0.004 + random.nextDouble() * 0.012;
      i += 1;
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final motionX = (0.36 + widget.motionScale * 0.26);
    final motionY = (0.36 + widget.motionScale * 0.2);
    for (final particle in _particles) {
      particle.x += particle.vx * deltaSeconds * motionX;
      particle.y += particle.vy * deltaSeconds * motionY;
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

    if (widget.scene == PremiumSceneKind.ocean) {
      for (final fish in _fish) {
        fish.x += fish.speed * fish.direction * deltaSeconds;
        if (fish.direction > 0 && fish.x > 1.24) {
          fish.x = -0.24;
          fish.y = 0.18 + random.nextDouble() * 0.58;
        } else if (fish.direction < 0 && fish.x < -0.24) {
          fish.x = 1.24;
          fish.y = 0.18 + random.nextDouble() * 0.58;
        }
      }
    }

    for (final cloud in _clouds) {
      cloud.x += deltaSeconds * cloud.speed;
      if (cloud.x > 1.25) cloud.x = -0.18;
    }

    if (widget.scene == PremiumSceneKind.forest) {
      for (final bug in _forestBugs) {
        bug.x += bug.vx * deltaSeconds;
        bug.y += bug.vy * deltaSeconds;
        bug.x += math.sin(elapsedSeconds * 0.45 + bug.phase) * 0.0005;
        bug.y += math.cos(elapsedSeconds * 0.38 + bug.phase) * 0.0004;
        if (bug.x < -0.05) bug.x = 1.05;
        if (bug.x > 1.05) bug.x = -0.05;
        if (bug.y < 0.12) bug.y = 0.88;
        if (bug.y > 0.92) bug.y = 0.16;
      }
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
        streaks: _streaks,
        ripples: _ripples,
        fish: _fish,
        cityStars: _cityStars,
        asteroids: _asteroids,
        forestBugs: _forestBugs,
        leafShapes: _leafShapes,
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
    required this.streaks,
    required this.ripples,
    required this.fish,
    required this.cityStars,
    required this.asteroids,
    required this.forestBugs,
    required this.leafShapes,
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
  final List<_StarStreak> streaks;
  final List<_TouchRipple> ripples;
  final List<_FishSprite> fish;
  final List<_CityStar> cityStars;
  final List<_OrbitAsteroid> asteroids;
  final List<_ForestBug> forestBugs;
  final List<_LeafShape> leafShapes;
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

    final seabed = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.77,
        size.width * 0.4,
        size.height * 0.83,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.88,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      seabed,
      Paint()..color = const Color(0xFF020A0F).withValues(alpha: 0.66),
    );

    for (final fishSprite in fish) {
      final presence =
          (math.sin(elapsed * 0.45 + fishSprite.phase) + 1.0) * 0.5;
      if (presence < 0.18) continue;
      final alpha = fishSprite.alpha * (0.45 + presence * 0.55);
      final px = fishSprite.x * size.width + parallax.x * size.width * 0.018;
      final py =
          fishSprite.y * size.height +
          math.sin(elapsed * 0.7 + fishSprite.phase) * 2 +
          parallax.y * size.height * 0.012;
      final fishLength = 16 * fishSprite.scale;
      final fishHeight = 7 * fishSprite.scale;

      canvas.save();
      canvas.translate(px, py);
      if (fishSprite.direction < 0) {
        canvas.scale(-1, 1);
      }

      final bodyPath = Path()
        ..moveTo(-fishLength * 0.5, 0)
        ..quadraticBezierTo(
          -fishLength * 0.1,
          -fishHeight * 0.5,
          fishLength * 0.45,
          0,
        )
        ..quadraticBezierTo(
          -fishLength * 0.1,
          fishHeight * 0.5,
          -fishLength * 0.5,
          0,
        )
        ..close();
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = palette.particleNear.withValues(alpha: alpha * 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );

      final tail = Path()
        ..moveTo(-fishLength * 0.5, 0)
        ..lineTo(-fishLength * 0.74, -fishHeight * 0.4)
        ..lineTo(-fishLength * 0.74, fishHeight * 0.4)
        ..close();
      canvas.drawPath(
        tail,
        Paint()..color = palette.particleFar.withValues(alpha: alpha * 0.34),
      );
      canvas.restore();
    }
  }

  void _paintSpace(Canvas canvas, Size size, double elapsed) {
    final galaxyCenter = Offset(
      size.width * (0.68 + parallax.x * 0.04),
      size.height * (0.26 + parallax.y * 0.03),
    );

    for (var arm = 0; arm < 3; arm++) {
      for (var i = 0; i < 46; i++) {
        final t = i / 46;
        final angle =
            (t * math.pi * 6) + arm * (math.pi * 2 / 3) + elapsed * 0.035;
        final radius = t * size.width * 0.22;
        final x = galaxyCenter.dx + math.cos(angle) * radius;
        final y = galaxyCenter.dy + math.sin(angle) * radius * 0.58;
        final starAlpha = (1 - t) * 0.08 + 0.02;
        canvas.drawCircle(
          Offset(x, y),
          0.9 + (1 - t) * 1.4,
          Paint()
            ..color = palette.secondaryAccent.withValues(alpha: starAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
        );
      }
    }

    final coreGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.accent.withValues(alpha: 0.25),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: galaxyCenter, radius: size.width * 0.22),
          );
    canvas.drawCircle(galaxyCenter, size.width * 0.22, coreGlow);

    final planetCenter = Offset(
      size.width * (0.2 + parallax.x * 0.03),
      size.height * (0.22 + parallax.y * 0.03),
    );
    final planetRadius = (size.shortestSide * 0.11).clamp(40.0, 68.0);
    canvas.drawCircle(
      planetCenter,
      planetRadius,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.25, -0.2),
              radius: 1.0,
              colors: [
                const Color(0xFF6E7CA7).withValues(alpha: 0.9),
                const Color(0xFF2F3E63).withValues(alpha: 0.94),
                const Color(0xFF1A2136).withValues(alpha: 0.96),
              ],
              stops: const [0.0, 0.58, 1.0],
            ).createShader(
              Rect.fromCircle(center: planetCenter, radius: planetRadius),
            ),
    );

    final atmosphere = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = palette.particleNear.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    canvas.drawCircle(planetCenter, planetRadius + 1.2, atmosphere);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.secondaryAccent.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: planetCenter,
        width: planetRadius * 3.4,
        height: planetRadius * 1.5,
      ),
      orbitPaint,
    );

    for (final asteroid in asteroids) {
      final angle = asteroid.angle + elapsed * asteroid.speed;
      final orbitX = math.cos(angle) * asteroid.orbitRadius * size.width;
      final orbitY = math.sin(angle) * asteroid.orbitRadius * size.width * 0.42;
      final pos = Offset(planetCenter.dx + orbitX, planetCenter.dy + orbitY);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(asteroid.tilt + angle * 0.6);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: asteroid.size * 2.2,
          height: asteroid.size * 1.2,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = const Color(0xFF94A3C4).withValues(alpha: 0.6),
      );
      canvas.restore();
    }

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
      final paint = Paint()
        ..color = palette.particleNear.withValues(
          alpha: streak.alpha * (1 - progress),
        )
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintRain(Canvas canvas, Size size, double elapsed) {
    for (final star in cityStars) {
      final twinkle = 0.5 + 0.5 * math.sin(elapsed * 0.8 + star.phase);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        Paint()
          ..color = const Color(
            0xFFE2E9F2,
          ).withValues(alpha: star.alpha * twinkle * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

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

    final topHaze = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF9DB6C6).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topHaze);

    _paintCitySkyline(
      canvas,
      size,
      elapsed,
      isSunset: false,
      buildingColor: const Color(0xFF0A121A),
      windowColor: const Color(0xFFE8C879),
    );

    final lowFogRect = Rect.fromLTWH(
      0,
      size.height * 0.58,
      size.width,
      size.height * 0.45,
    );
    final lowFog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF91A8B6).withValues(alpha: 0.12),
          const Color(0xFF465868).withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.54, 1.0],
      ).createShader(lowFogRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(lowFogRect, lowFog);

    final rainPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final drop in rainDrops) {
      final x = drop.x * size.width + parallax.x * 8;
      final y = drop.y * size.height;
      rainPaint.color = palette.particleNear.withValues(alpha: drop.alpha);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 3, y + drop.length * size.height),
        rainPaint,
      );
    }

    _paintPlane(
      canvas,
      size,
      elapsed,
      tint: const Color(0xFFBFD2DF),
      altitude: 0.2,
      scale: 0.56,
      cycle: 36,
    );
  }

  void _paintForest(Canvas canvas, Size size, double elapsed) {
    for (final leaf in leafShapes) {
      final center = Offset(
        leaf.x * size.width + parallax.x * 8 * (1 - leaf.y),
        leaf.y * size.height + parallax.y * 5,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(leaf.rotation);
      final leafPath = Path()
        ..moveTo(0, -leaf.scale * size.width * 0.9)
        ..quadraticBezierTo(
          leaf.scale * size.width * 0.6,
          0,
          0,
          leaf.scale * size.width * 0.9,
        )
        ..quadraticBezierTo(
          -leaf.scale * size.width * 0.5,
          0,
          0,
          -leaf.scale * size.width * 0.9,
        )
        ..close();
      canvas.drawPath(
        leafPath,
        Paint()..color = const Color(0xFF213927).withValues(alpha: leaf.alpha),
      );
      canvas.restore();
    }

    final canopyPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.23)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.08,
        size.width * 0.58,
        size.height * 0.3,
        size.width,
        size.height * 0.17,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      canopyPath,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
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

    for (final bug in forestBugs) {
      final pulse = 0.45 + 0.55 * math.sin(elapsed * 1.6 + bug.phase);
      final alpha = bug.glow * pulse;
      final center = Offset(
        bug.x * size.width + parallax.x * 9,
        bug.y * size.height + parallax.y * 6,
      );
      canvas.drawCircle(
        center,
        bug.radius + pulse * 1.3,
        Paint()
          ..color = const Color(0xFFE6E98F).withValues(alpha: alpha * 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2),
      );
      canvas.drawCircle(
        center,
        bug.radius * 0.7,
        Paint()..color = const Color(0xFFD9E67E).withValues(alpha: alpha * 0.7),
      );
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

    for (final star in cityStars) {
      final twinkle = 0.3 + 0.7 * math.sin(elapsed * 0.6 + star.phase);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height * 0.8),
        star.radius * 0.8,
        Paint()
          ..color = const Color(
            0xFFFFEBD8,
          ).withValues(alpha: star.alpha * twinkle * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }

    for (final cloud in clouds) {
      final cx =
          cloud.x * size.width +
          math.sin(elapsed * 0.08 + cloud.phase) * 10 +
          parallax.x * 8;
      final cy =
          cloud.y * size.height +
          math.cos(elapsed * 0.06 + cloud.phase) * 4 +
          parallax.y * 4;
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

    _paintCitySkyline(
      canvas,
      size,
      elapsed,
      isSunset: true,
      buildingColor: const Color(0xFF1E1523),
      windowColor: const Color(0xFFFFD38A),
    );
    _paintPlane(
      canvas,
      size,
      elapsed + 9,
      tint: const Color(0xFFEED6C3),
      altitude: 0.17,
      scale: 0.5,
      cycle: 40,
    );
  }

  void _paintGlow(Canvas canvas, Size size, double elapsed) {
    final sunshine = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.0 + parallax.x * 0.03, -0.1 + parallax.y * 0.03),
        radius: 0.95,
        colors: [
          const Color(0xFFF4D4B0).withValues(alpha: 0.24),
          const Color(0xFFF0BDA4).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sunshine);

    for (final leaf in leafShapes) {
      final drift = math.sin(elapsed * 0.09 + leaf.y * 5.5) * 4.0;
      final center = Offset(
        leaf.x * size.width + parallax.x * 9 + drift,
        leaf.y * size.height + parallax.y * 5,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
        leaf.rotation + math.sin(elapsed * 0.12 + leaf.x * 8) * 0.04,
      );
      final leafPath = Path()
        ..moveTo(0, -leaf.scale * size.width * 0.92)
        ..quadraticBezierTo(
          leaf.scale * size.width * 0.56,
          0,
          0,
          leaf.scale * size.width * 0.92,
        )
        ..quadraticBezierTo(
          -leaf.scale * size.width * 0.52,
          0,
          0,
          -leaf.scale * size.width * 0.92,
        )
        ..close();
      canvas.drawPath(
        leafPath,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF8EAF86).withValues(alpha: leaf.alpha * 0.82),
                  const Color(0xFF4E6E57).withValues(alpha: leaf.alpha * 0.9),
                ],
              ).createShader(
                Rect.fromLTWH(
                  -leaf.scale * size.width * 0.7,
                  -leaf.scale * size.width,
                  leaf.scale * size.width * 1.4,
                  leaf.scale * size.width * 2,
                ),
              )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
      );
      final vein = Paint()
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE3F1CE).withValues(alpha: leaf.alpha * 0.35);
      canvas.drawLine(
        Offset(0, -leaf.scale * size.width * 0.66),
        Offset(0, leaf.scale * size.width * 0.66),
        vein,
      );
      canvas.restore();
    }

    final ambientBloom = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.05 + parallax.x * 0.04, 0.32 + parallax.y * 0.04),
        radius: 0.8,
        colors: [
          const Color(0xFFF7DFC0).withValues(alpha: 0.2),
          const Color(0xFFDDAF8D).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, ambientBloom);

    _paintDragonfly(canvas, size, elapsed);
  }

  void _paintCitySkyline(
    Canvas canvas,
    Size size,
    double elapsed, {
    required bool isSunset,
    required Color buildingColor,
    required Color windowColor,
  }) {
    if (skyline.isEmpty) return;

    // Far city layer for depth.
    for (final block in skyline) {
      final farRect = Rect.fromLTWH(
        (block.x * size.width) + size.width * 0.01,
        size.height * (1 - (block.height * 0.78)),
        block.width * size.width * 0.94,
        block.height * size.height * 0.78,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(farRect, const Radius.circular(1.4)),
        Paint()
          ..color = buildingColor.withValues(alpha: block.alpha * 0.36)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    for (final block in skyline) {
      final rect = Rect.fromLTWH(
        block.x * size.width,
        size.height * (1 - block.height),
        block.width * size.width,
        block.height * size.height,
      );
      final shell = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            buildingColor.withValues(alpha: block.alpha * 0.9),
            buildingColor.withValues(alpha: block.alpha),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
        shell,
      );

      if (block.crownHeight > 0) {
        final crownRect = Rect.fromLTWH(
          rect.left + rect.width * block.crownInset,
          rect.top - block.crownHeight * size.height,
          rect.width * (1 - block.crownInset * 2),
          block.crownHeight * size.height,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(crownRect, const Radius.circular(1.8)),
          Paint()
            ..color = buildingColor.withValues(alpha: block.alpha * 0.95)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
        );
      }

      if (block.isStepped) {
        final stepRect = Rect.fromLTWH(
          rect.left + rect.width * 0.13,
          rect.top + rect.height * 0.08,
          rect.width * 0.74,
          rect.height * 0.14,
        );
        canvas.drawRect(
          stepRect,
          Paint()..color = Colors.black.withValues(alpha: 0.08),
        );
      }

      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + 1,
          rect.top + 1,
          rect.width * 0.1,
          rect.height,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: isSunset ? 0.045 : 0.03),
      );

      for (final window in block.windows) {
        final flicker = 0.82 + 0.18 * math.sin(elapsed * 1.2 + window.phase);
        final windowRect = Rect.fromLTWH(
          rect.left + rect.width * window.nx,
          rect.top + rect.height * window.ny,
          rect.width * window.widthFactor,
          rect.height * window.heightFactor,
        );
        canvas.drawRect(
          windowRect,
          Paint()
            ..color = windowColor.withValues(
              alpha: window.alpha * flicker * 0.5,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
        );
      }

      if (isSunset && block.hasTowerLight) {
        final blink = 0.35 + 0.65 * math.sin(elapsed * 4.5);
        final lightCenter = Offset(rect.center.dx, rect.top + 2.5);
        canvas.drawCircle(
          lightCenter,
          1.8,
          Paint()
            ..color = const Color(0xFFFF4A4A).withValues(alpha: 0.45 * blink)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
        );
      }
    }
  }

  void _paintPlane(
    Canvas canvas,
    Size size,
    double elapsed, {
    required Color tint,
    double altitude = 0.18,
    double scale = 0.56,
    double cycle = 36,
  }) {
    final visible = cycle * 0.52;
    final phase = elapsed % cycle;
    if (phase > visible) return;
    final p = Curves.easeInOutSine.transform(phase / visible);
    final x = (lerpDouble(-0.18, 1.12, p) ?? 0.0) * size.width + parallax.x * 6;
    final y = size.height * (altitude + math.sin(p * math.pi * 1.2) * 0.018);
    final bodyLength = 22.0 * scale;
    final wingSpan = 13.0 * scale;
    final tail = Offset(x - bodyLength * 0.52, y + bodyLength * 0.06);
    final nose = Offset(x + bodyLength * 0.52, y);
    final wingTop = Offset(x - bodyLength * 0.05, y - wingSpan * 0.36);
    final wingBottom = Offset(x - bodyLength * 0.02, y + wingSpan * 0.3);

    final bodyPaint = Paint()
      ..color = tint.withValues(alpha: 0.38)
      ..strokeWidth = 0.9 * scale.clamp(0.45, 0.8)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7);
    canvas.drawLine(tail, nose, bodyPaint);
    canvas.drawLine(Offset(x - 1.5, y), wingTop, bodyPaint);
    canvas.drawLine(Offset(x - 1.5, y), wingBottom, bodyPaint);

    final blink = 0.5 + 0.5 * math.sin(elapsed * 6.4);
    canvas.drawCircle(
      Offset(x + bodyLength * 0.38, y - 0.7 * scale),
      0.9 * scale,
      Paint()
        ..color = const Color(0xFFFFCE96).withValues(alpha: 0.4 + blink * 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.drawCircle(
      Offset(x - bodyLength * 0.32, y + 0.3 * scale),
      0.9 * scale,
      Paint()
        ..color = const Color(0xFFFF4B4B).withValues(alpha: 0.24 + blink * 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );

    canvas.drawLine(
      Offset(x - bodyLength * 0.62, y + 0.8 * scale),
      Offset(x - bodyLength * 1.18, y + 1.6 * scale),
      Paint()
        ..color = tint.withValues(alpha: 0.1)
        ..strokeWidth = 0.6 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintDragonfly(Canvas canvas, Size size, double elapsed) {
    final wanderX =
        0.58 +
        0.16 * math.sin(elapsed * 0.17 + 0.6) +
        0.08 * math.sin(elapsed * 0.31 + 1.9) +
        0.04 * math.sin(elapsed * 0.52 + 3.2);
    final wanderY =
        0.35 +
        0.07 * math.sin(elapsed * 0.21 + 0.8) +
        0.03 * math.sin(elapsed * 0.43 + 2.5);
    final x = size.width * wanderX;
    final y = size.height * wanderY;
    final heading = math.sin(elapsed * 0.2 + 0.4) * 0.08;
    final bodyTilt = math.sin(elapsed * 0.35 + 1.2) * 0.03;
    final wingFlap = math.sin(elapsed * 18.0);
    final wingSpread = 0.58 + 0.42 * wingFlap.abs();
    final wingAlpha = 0.16 + wingSpread * 0.07;

    canvas.save();
    canvas.translate(x + parallax.x * 6, y + parallax.y * 3);
    canvas.rotate(heading + bodyTilt);

    final body = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4C5B70).withValues(alpha: 0.78);
    canvas.drawLine(const Offset(-7.2, 0), const Offset(6.6, 0), body);
    canvas.drawCircle(
      const Offset(7.4, 0),
      1.1,
      Paint()..color = const Color(0xFF5C6C84).withValues(alpha: 0.78),
    );

    final wingPaint = Paint()
      ..color = const Color(0xFFE8F5FF).withValues(alpha: wingAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    final wingLength = 7.6 + wingSpread * 1.8;
    final wingHeight = 3.0 + wingSpread * 0.8;
    canvas.save();
    canvas.translate(-0.8, -1.2);
    canvas.rotate(-0.55 * wingSpread);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-1.8, 0),
        width: wingLength,
        height: wingHeight,
      ),
      wingPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(-0.8, 1.2);
    canvas.rotate(0.55 * wingSpread);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-1.6, 0),
        width: wingLength,
        height: wingHeight,
      ),
      wingPaint,
    );
    canvas.restore();

    final wingRearPaint = Paint()
      ..color = const Color(0xFFE3F0FF).withValues(alpha: wingAlpha * 0.84)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.9);
    canvas.save();
    canvas.translate(-3.1, -1.0);
    canvas.rotate(-0.4 * wingSpread);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-1.4, 0),
        width: wingLength * 0.72,
        height: wingHeight * 0.85,
      ),
      wingRearPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(-3.1, 1.0);
    canvas.rotate(0.4 * wingSpread);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-1.4, 0),
        width: wingLength * 0.72,
        height: wingHeight * 0.85,
      ),
      wingRearPaint,
    );
    canvas.restore();

    canvas.restore();
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
    required this.windows,
    required this.hasTowerLight,
    required this.crownHeight,
    required this.crownInset,
    required this.isStepped,
  });

  final double x;
  final double width;
  final double height;
  final double alpha;
  final List<_WindowCell> windows;
  final bool hasTowerLight;
  final double crownHeight;
  final double crownInset;
  final bool isStepped;
}

class _WindowCell {
  const _WindowCell({
    required this.nx,
    required this.ny,
    required this.widthFactor,
    required this.heightFactor,
    required this.alpha,
    required this.phase,
  });

  final double nx;
  final double ny;
  final double widthFactor;
  final double heightFactor;
  final double alpha;
  final double phase;
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

class _FishSprite {
  _FishSprite({
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.alpha,
    required this.phase,
    required this.direction,
  });

  double x;
  double y;
  final double speed;
  final double scale;
  final double alpha;
  final double phase;
  final int direction;
}

class _CityStar {
  const _CityStar({
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

class _OrbitAsteroid {
  const _OrbitAsteroid({
    required this.orbitRadius,
    required this.angle,
    required this.speed,
    required this.size,
    required this.tilt,
  });

  final double orbitRadius;
  final double angle;
  final double speed;
  final double size;
  final double tilt;
}

class _ForestBug {
  _ForestBug({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.glow,
    required this.phase,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;
  final double glow;
  final double phase;
}

class _LeafShape {
  const _LeafShape({
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
    required this.alpha,
  });

  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double alpha;
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
