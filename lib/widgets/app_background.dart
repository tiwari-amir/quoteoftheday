import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/v3_background/background_theme_provider.dart';
import 'animated_gradient_background.dart';

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
      AppBackgroundTheme.spaceGalaxies => _SpaceGalaxiesBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.rainyCity => _RainyCityBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.deepForest => _DeepForestBackground(
        seed: seed,
        motionScale: motionScale,
      ),
      AppBackgroundTheme.sunsetCity => _SunsetCityBackground(
        seed: seed,
        motionScale: motionScale,
      ),
    };
  }
}

mixin _GlobalTouchSceneMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Offset>? _touchSub;

  @protected
  void onLocalTouch(Offset localPosition);

  @override
  void initState() {
    super.initState();
    _touchSub = AnimatedGradientBackground.globalRippleStream.listen(
      _onGlobalTouch,
    );
  }

  void _onGlobalTouch(Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }
    onLocalTouch(local);
  }

  @override
  void dispose() {
    _touchSub?.cancel();
    super.dispose();
  }
}

class _SpaceGalaxiesBackground extends StatefulWidget {
  const _SpaceGalaxiesBackground({
    required this.seed,
    required this.motionScale,
  });

  final int seed;
  final double motionScale;

  @override
  State<_SpaceGalaxiesBackground> createState() =>
      _SpaceGalaxiesBackgroundState();
}

class _SpaceGalaxiesBackgroundState extends State<_SpaceGalaxiesBackground>
    with SingleTickerProviderStateMixin, _GlobalTouchSceneMixin {
  static const _starCount = 110;

  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_SpaceStar> _stars;
  final List<_ScenePulse> _pulses = <_ScenePulse>[];
  final List<_WarpWell> _warpWells = <_WarpWell>[];
  Size _size = Size.zero;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(1117 + widget.seed);
    _stars = List<_SpaceStar>.generate(_starCount, (index) {
      return _SpaceStar(
        pos: Offset(_random.nextDouble(), _random.nextDouble()),
        drift: 0.2 + _random.nextDouble() * 1.2,
        radius: 0.7 + _random.nextDouble() * 2.0,
        phase: _random.nextDouble() * math.pi * 2,
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    for (final star in _stars) {
      var x = star.pos.dx + dt * star.drift * 0.015 * widget.motionScale;
      var y = star.pos.dy + dt * star.drift * 0.005;

      if (_size.width > 0 && _size.height > 0 && _warpWells.isNotEmpty) {
        var starPosPx = Offset(x * _size.width, y * _size.height);
        for (final well in _warpWells) {
          final age = (now - well.startSeconds).clamp(0.0, well.life);
          final fade = (1 - age / well.life).clamp(0.0, 1.0) * well.strength;
          if (fade <= 0.001) continue;
          final toWell = well.center - starPosPx;
          final d = toWell.distance;
          if (d < 1 || d > 260) continue;
          final dir = toWell / d;
          final tangent = Offset(-dir.dy, dir.dx);
          final influence = (1 - d / 260).clamp(0.0, 1.0) * fade;
          starPosPx +=
              tangent * (24 * influence * dt * widget.motionScale) +
              dir * (14 * influence * dt * widget.motionScale);
        }
        x = starPosPx.dx / _size.width;
        y = starPosPx.dy / _size.height;
      }

      star.pos = Offset((x + 1) % 1, (y + 1) % 1);
    }

    _pulses.removeWhere((pulse) => now - pulse.startSeconds > 1.9);
    _warpWells.removeWhere((well) => now - well.startSeconds > well.life);
    if (mounted) setState(() {});
  }

  @override
  void onLocalTouch(Offset localPosition) {
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    _pulses.add(
      _ScenePulse(center: localPosition, startSeconds: now, strength: 1.0),
    );
    _warpWells.add(
      _WarpWell(
        center: localPosition,
        startSeconds: now,
        life: 1.6,
        strength: 0.9 + _random.nextDouble() * 0.45,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final t =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
        return CustomPaint(
          painter: _SpaceGalaxiesPainter(
            stars: _stars,
            pulses: _pulses,
            warpWells: _warpWells,
            timeSeconds: t,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _SpaceGalaxiesPainter extends CustomPainter {
  const _SpaceGalaxiesPainter({
    required this.stars,
    required this.pulses,
    required this.warpWells,
    required this.timeSeconds,
  });

  final List<_SpaceStar> stars;
  final List<_ScenePulse> pulses;
  final List<_WarpWell> warpWells;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF030712), Color(0xFF041629), Color(0xFF02040B)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final nebulaA = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.68 + math.sin(timeSeconds * 0.1) * 0.08,
          -0.35 + math.cos(timeSeconds * 0.13) * 0.04,
        ),
        radius: 1.0,
        colors: [
          const Color(0xFF26B4FF).withValues(alpha: 0.26),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    final nebulaB = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          0.72 + math.sin(timeSeconds * 0.09) * 0.06,
          0.45 + math.cos(timeSeconds * 0.12) * 0.05,
        ),
        radius: 0.95,
        colors: [
          const Color(0xFF4A7DFF).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, nebulaA);
    canvas.drawRect(Offset.zero & size, nebulaB);

    for (final star in stars) {
      final p = Offset(star.pos.dx * size.width, star.pos.dy * size.height);
      final twinkle =
          0.34 + 0.66 * (0.5 + 0.5 * math.sin(timeSeconds * 3.8 + star.phase));
      final paint = Paint()
        ..color = const Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.22 + twinkle * 0.56);
      canvas.drawCircle(p, star.radius, paint);
    }

    for (var i = 0; i < 3; i++) {
      final progress = (timeSeconds * 0.055 + i * 0.31) % 1.0;
      final sx = -size.width * 0.25 + progress * size.width * 1.5;
      final sy = size.height * (0.13 + i * 0.22);
      final ex = sx - 60;
      final ey = sy - 24;
      final comet = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.0),
            const Color(0xFFFFFFFF).withValues(alpha: 0.7),
          ],
        ).createShader(Rect.fromPoints(Offset(ex, ey), Offset(sx, sy)));
      canvas.drawLine(Offset(ex, ey), Offset(sx, sy), comet);
    }

    for (final pulse in pulses) {
      final age = (timeSeconds - pulse.startSeconds).clamp(0.0, 1.9);
      final radius = age * 210;
      final alpha = (1 - age / 1.9).clamp(0.0, 1.0);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 + pulse.strength * 1.2
        ..color = const Color(0xFF8BCBFF).withValues(alpha: alpha * 0.44);
      final glow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF8BCBFF).withValues(alpha: alpha * 0.22),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: pulse.center, radius: radius + 34),
            );
      canvas.drawCircle(pulse.center, radius, ring);
      canvas.drawCircle(pulse.center, radius + 34, glow);
    }

    for (final well in warpWells) {
      final age = (timeSeconds - well.startSeconds).clamp(0.0, well.life);
      final alpha = (1 - age / well.life).clamp(0.0, 1.0);
      final radius = 20 + age * 190;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFA3D1FF).withValues(alpha: alpha * 0.38);
      final halo = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFA3D1FF).withValues(alpha: alpha * 0.2),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: well.center, radius: radius + 22),
            );
      canvas.drawCircle(well.center, radius + 22, halo);
      canvas.drawCircle(well.center, radius, ring);
    }

    final glaze = Paint()
      ..color = const Color(0xFF02101B).withValues(alpha: 0.28);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  @override
  bool shouldRepaint(covariant _SpaceGalaxiesPainter oldDelegate) => true;
}

class _RainyCityBackground extends StatefulWidget {
  const _RainyCityBackground({required this.seed, required this.motionScale});

  final int seed;
  final double motionScale;

  @override
  State<_RainyCityBackground> createState() => _RainyCityBackgroundState();
}

class _RainyCityBackgroundState extends State<_RainyCityBackground>
    with SingleTickerProviderStateMixin, _GlobalTouchSceneMixin {
  static const _dropCount = 170;
  static const _buildingCount = 14;

  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_RainDrop> _drops;
  late final List<_BuildingBand> _buildings;
  final List<_ScenePulse> _puddles = <_ScenePulse>[];
  final List<_SplashParticle> _splashes = <_SplashParticle>[];

  double _lastT = 0;
  double _flash = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(2221 + widget.seed);
    _drops = List<_RainDrop>.generate(_dropCount, (index) {
      return _RainDrop(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.45 + _random.nextDouble() * 1.1,
        length: 7 + _random.nextDouble() * 18,
        thickness: 0.7 + _random.nextDouble() * 1.1,
      );
    });
    _buildings = List<_BuildingBand>.generate(_buildingCount, (index) {
      return _BuildingBand(
        widthFactor: 0.05 + _random.nextDouble() * 0.09,
        heightFactor: 0.2 + _random.nextDouble() * 0.43,
        windowOffset: _random.nextDouble(),
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    for (final drop in _drops) {
      drop.y += dt * drop.speed * 1.6 * widget.motionScale;
      if (drop.y > 1.15) {
        drop.y = -_random.nextDouble() * 0.24;
        drop.x = _random.nextDouble();
      }
    }

    _flash = (_flash - dt * 0.85).clamp(0.0, 1.0);
    _puddles.removeWhere((pulse) => now - pulse.startSeconds > 1.7);
    for (final splash in _splashes) {
      splash.velocity += Offset(0, 180 * dt);
      splash.position += splash.velocity * dt;
    }
    _splashes.removeWhere((splash) => now - splash.startSeconds > splash.life);
    if (mounted) setState(() {});
  }

  @override
  void onLocalTouch(Offset localPosition) {
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    _puddles.add(
      _ScenePulse(center: localPosition, startSeconds: now, strength: 1.0),
    );
    for (var i = 0; i < 22; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 22 + _random.nextDouble() * 110;
      _splashes.add(
        _SplashParticle(
          position: localPosition,
          velocity: Offset(math.cos(angle), -math.sin(angle).abs()) * speed,
          startSeconds: now,
          life: 0.65 + _random.nextDouble() * 0.45,
          radius: 0.8 + _random.nextDouble() * 1.6,
        ),
      );
    }
    _flash = math.max(_flash, 0.78);
  }

  @override
  Widget build(BuildContext context) {
    final t = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    return CustomPaint(
      painter: _RainyCityPainter(
        drops: _drops,
        buildings: _buildings,
        puddles: _puddles,
        splashes: _splashes,
        flash: _flash,
        timeSeconds: t,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RainyCityPainter extends CustomPainter {
  const _RainyCityPainter({
    required this.drops,
    required this.buildings,
    required this.puddles,
    required this.splashes,
    required this.flash,
    required this.timeSeconds,
  });

  final List<_RainDrop> drops;
  final List<_BuildingBand> buildings;
  final List<_ScenePulse> puddles;
  final List<_SplashParticle> splashes;
  final double flash;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF07141D), Color(0xFF112736), Color(0xFF081017)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final haze = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 0.95,
        colors: [
          const Color(0xFF4CC2D9).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, haze);

    var cursorX = 0.0;
    for (var i = 0; i < buildings.length; i++) {
      final b = buildings[i];
      final width = size.width * b.widthFactor;
      final height = size.height * (0.28 + b.heightFactor);
      final rect = Rect.fromLTWH(cursorX, size.height - height, width, height);
      final paint = Paint()
        ..color = const Color(0xFF0A1C28).withValues(alpha: 0.85);
      canvas.drawRect(rect, paint);

      final lightPaint = Paint()
        ..color = const Color(0xFFD9F7FF).withValues(alpha: 0.09);
      final columns = math.max(1, (width / 12).floor());
      final rows = math.max(1, (height / 20).floor());
      for (var cx = 0; cx < columns; cx++) {
        for (var ry = 0; ry < rows; ry++) {
          final gate = ((cx * 17 + ry * 13 + i * 19) % 9) / 9.0;
          final wave =
              0.5 + 0.5 * math.sin(timeSeconds * 0.9 + b.windowOffset * 5 + ry);
          if (wave * gate < 0.42) continue;
          final wx = rect.left + 3 + cx * 10.5;
          final wy = rect.top + 4 + ry * 16.0;
          canvas.drawRect(Rect.fromLTWH(wx, wy, 3.8, 6.2), lightPaint);
        }
      }
      cursorX += width + 2;
      if (cursorX > size.width) break;
    }

    final rainPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC9F4FF).withValues(alpha: 0.2);
    for (final drop in drops) {
      rainPaint.strokeWidth = drop.thickness;
      final sx = drop.x * size.width;
      final sy = drop.y * size.height;
      final ex = sx - drop.length * 0.2;
      final ey = sy + drop.length;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rainPaint);
    }

    for (final puddle in puddles) {
      final age = (timeSeconds - puddle.startSeconds).clamp(0.0, 1.7);
      final alpha = (1 - age / 1.7).clamp(0.0, 1.0);
      final radius = 28 + age * 170;
      final bloom = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFB6F3FF).withValues(alpha: alpha * 0.16),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: puddle.center, radius: radius + 24),
            );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFB6F3FF).withValues(alpha: alpha * 0.34);
      canvas.drawCircle(puddle.center, radius + 24, bloom);
      canvas.drawCircle(puddle.center, radius, ring);
    }

    final splashPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFDDF8FF).withValues(alpha: 0.6);
    for (final splash in splashes) {
      canvas.drawCircle(splash.position, splash.radius, splashPaint);
    }

    if (flash > 0.001) {
      final lightning = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: flash * 0.2);
      canvas.drawRect(Offset.zero & size, lightning);
    }

    final glaze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x22000000), Color(0x44000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  @override
  bool shouldRepaint(covariant _RainyCityPainter oldDelegate) => true;
}

class _DeepForestBackground extends StatefulWidget {
  const _DeepForestBackground({required this.seed, required this.motionScale});

  final int seed;
  final double motionScale;

  @override
  State<_DeepForestBackground> createState() => _DeepForestBackgroundState();
}

class _DeepForestBackgroundState extends State<_DeepForestBackground>
    with SingleTickerProviderStateMixin, _GlobalTouchSceneMixin {
  static const _fireflyCount = 64;
  static const _treeCount = 20;

  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_Firefly> _fireflies;
  late final List<_TreeSilhouette> _trees;
  final List<_ScenePulse> _glows = <_ScenePulse>[];
  final List<_SporeParticle> _spores = <_SporeParticle>[];

  Size _size = Size.zero;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(3713 + widget.seed);
    _fireflies = List<_Firefly>.generate(_fireflyCount, (index) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.02 + _random.nextDouble() * 0.09;
      return _Firefly(
        pos: Offset(_random.nextDouble(), _random.nextDouble()),
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        radius: 1.0 + _random.nextDouble() * 2.5,
        phase: _random.nextDouble() * math.pi * 2,
      );
    });
    _trees = List<_TreeSilhouette>.generate(_treeCount, (index) {
      return _TreeSilhouette(
        x: _random.nextDouble(),
        width: 0.02 + _random.nextDouble() * 0.05,
        height: 0.26 + _random.nextDouble() * 0.46,
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    _glows.removeWhere((pulse) => now - pulse.startSeconds > 1.9);
    final activeGlow = _glows.isEmpty ? null : _glows.last;

    for (final fly in _fireflies) {
      final wander =
          Offset(
            math.sin(now * 1.7 + fly.phase),
            math.cos(now * 1.9 + fly.phase * 0.83),
          ) *
          0.028;
      fly.velocity += wander * dt;

      if (activeGlow != null && _size.width > 0 && _size.height > 0) {
        final target = Offset(
          activeGlow.center.dx / _size.width,
          activeGlow.center.dy / _size.height,
        );
        final toTarget = target - fly.pos;
        final d = toTarget.distance;
        if (d > 0.0001) {
          fly.velocity += (toTarget / d) * (0.045 * dt * widget.motionScale);
        }
      }

      final speed = fly.velocity.distance;
      if (speed > 0.11) {
        fly.velocity = (fly.velocity / speed) * 0.11;
      }
      fly.pos += fly.velocity * dt * (5.7 + widget.motionScale * 1.2);
      fly.pos = Offset((fly.pos.dx + 1.0) % 1.0, (fly.pos.dy + 1.0) % 1.0);
    }

    for (final spore in _spores) {
      spore.velocity +=
          Offset(math.sin(now * 2.4 + spore.phase) * 3.2 * dt, -12.0 * dt) *
          widget.motionScale;
      spore.position += spore.velocity * dt;
    }
    _spores.removeWhere((spore) => now - spore.startSeconds > spore.life);

    if (mounted) setState(() {});
  }

  @override
  void onLocalTouch(Offset localPosition) {
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    _glows.add(
      _ScenePulse(center: localPosition, startSeconds: now, strength: 1.0),
    );
    for (var i = 0; i < 18; i++) {
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.9;
      final speed = 12 + _random.nextDouble() * 48;
      _spores.add(
        _SporeParticle(
          position: localPosition,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          startSeconds: now,
          life: 1.1 + _random.nextDouble() * 0.9,
          radius: 0.8 + _random.nextDouble() * 1.8,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final t =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
        return CustomPaint(
          painter: _DeepForestPainter(
            fireflies: _fireflies,
            trees: _trees,
            glows: _glows,
            spores: _spores,
            timeSeconds: t,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _DeepForestPainter extends CustomPainter {
  const _DeepForestPainter({
    required this.fireflies,
    required this.trees,
    required this.glows,
    required this.spores,
    required this.timeSeconds,
  });

  final List<_Firefly> fireflies;
  final List<_TreeSilhouette> trees;
  final List<_ScenePulse> glows;
  final List<_SporeParticle> spores;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final forest = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF05130D), Color(0xFF0A2A1C), Color(0xFF04110A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, forest);

    final mistA = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.4 + math.sin(timeSeconds * 0.12) * 0.1, -0.2),
        radius: 1.0,
        colors: [
          const Color(0xFF8DE5A2).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, mistA);

    for (final tree in trees) {
      final x = tree.x * size.width;
      final width = tree.width * size.width;
      final height = tree.height * size.height;
      final trunk = Rect.fromLTWH(
        x,
        size.height - height,
        width.clamp(2.0, 14.0),
        height,
      );
      canvas.drawRect(
        trunk,
        Paint()..color = const Color(0xFF08170F).withValues(alpha: 0.76),
      );
    }

    final fogShift = math.sin(timeSeconds * 0.22) * 16;
    final fogRect = Rect.fromLTWH(
      -40 + fogShift,
      size.height * 0.56,
      size.width + 80,
      size.height * 0.28,
    );
    final fog = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFB0FFCF).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(fogRect);
    canvas.drawRect(fogRect, fog);

    for (final fly in fireflies) {
      final p = Offset(fly.pos.dx * size.width, fly.pos.dy * size.height);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD7FFD1).withValues(
              alpha:
                  0.22 +
                  0.3 * (0.5 + 0.5 * math.sin(timeSeconds * 4 + fly.phase)),
            ),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: p, radius: fly.radius * 7));
      canvas.drawCircle(p, fly.radius * 7, glow);
      canvas.drawCircle(
        p,
        fly.radius,
        Paint()..color = const Color(0xFFF2FFE8).withValues(alpha: 0.9),
      );
    }

    for (final glow in glows) {
      final age = (timeSeconds - glow.startSeconds).clamp(0.0, 1.9);
      final alpha = (1 - age / 1.9).clamp(0.0, 1.0);
      final radius = 28 + age * 160;
      final aura = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD4FFCA).withValues(alpha: alpha * 0.22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: glow.center, radius: radius));
      canvas.drawCircle(glow.center, radius, aura);
    }

    for (final spore in spores) {
      final alpha = (1 - (timeSeconds - spore.startSeconds) / spore.life).clamp(
        0.0,
        1.0,
      );
      if (alpha <= 0.001) continue;
      final paint = Paint()
        ..color = const Color(0xFFCFFFD3).withValues(alpha: alpha * 0.42);
      canvas.drawCircle(spore.position, spore.radius, paint);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020A05).withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _DeepForestPainter oldDelegate) => true;
}

class _SunsetCityBackground extends StatefulWidget {
  const _SunsetCityBackground({required this.seed, required this.motionScale});

  final int seed;
  final double motionScale;

  @override
  State<_SunsetCityBackground> createState() => _SunsetCityBackgroundState();
}

class _SunsetCityBackgroundState extends State<_SunsetCityBackground>
    with SingleTickerProviderStateMixin, _GlobalTouchSceneMixin {
  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_CloudBand> _clouds;
  late final List<_BirdLine> _birds;
  late final List<_BuildingBand> _buildings;
  final List<_ScenePulse> _flares = <_ScenePulse>[];
  final List<_SunRayParticle> _sunRays = <_SunRayParticle>[];

  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(4583 + widget.seed);
    _clouds = List<_CloudBand>.generate(7, (index) {
      return _CloudBand(
        x: _random.nextDouble(),
        y: 0.1 + _random.nextDouble() * 0.42,
        widthFactor: 0.12 + _random.nextDouble() * 0.22,
        heightFactor: 0.04 + _random.nextDouble() * 0.06,
        speed: 0.008 + _random.nextDouble() * 0.018,
      );
    });
    _birds = List<_BirdLine>.generate(10, (index) {
      return _BirdLine(
        x: _random.nextDouble(),
        y: 0.16 + _random.nextDouble() * 0.34,
        phase: _random.nextDouble() * math.pi * 2,
        speed: 0.015 + _random.nextDouble() * 0.018,
      );
    });
    _buildings = List<_BuildingBand>.generate(12, (index) {
      return _BuildingBand(
        widthFactor: 0.06 + _random.nextDouble() * 0.11,
        heightFactor: 0.1 + _random.nextDouble() * 0.35,
        windowOffset: _random.nextDouble(),
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    for (final cloud in _clouds) {
      cloud.x += cloud.speed * dt * (0.7 + widget.motionScale * 0.5);
      if (cloud.x > 1.2) cloud.x = -0.25;
    }
    for (final bird in _birds) {
      bird.x += bird.speed * dt * (0.8 + widget.motionScale * 0.4);
      if (bird.x > 1.2) bird.x = -0.2;
    }
    for (final ray in _sunRays) {
      ray.length += dt * 42 * widget.motionScale;
    }
    _flares.removeWhere((flare) => now - flare.startSeconds > 1.8);
    _sunRays.removeWhere((ray) => now - ray.startSeconds > ray.life);
    if (mounted) setState(() {});
  }

  @override
  void onLocalTouch(Offset localPosition) {
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    _flares.add(
      _ScenePulse(center: localPosition, startSeconds: now, strength: 1.0),
    );
    for (var i = 0; i < 14; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      _sunRays.add(
        _SunRayParticle(
          center: localPosition,
          angle: angle,
          length: 14 + _random.nextDouble() * 20,
          startSeconds: now,
          life: 0.9 + _random.nextDouble() * 0.9,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    return CustomPaint(
      painter: _SunsetCityPainter(
        clouds: _clouds,
        birds: _birds,
        buildings: _buildings,
        flares: _flares,
        sunRays: _sunRays,
        timeSeconds: t,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SunsetCityPainter extends CustomPainter {
  const _SunsetCityPainter({
    required this.clouds,
    required this.birds,
    required this.buildings,
    required this.flares,
    required this.sunRays,
    required this.timeSeconds,
  });

  final List<_CloudBand> clouds;
  final List<_BirdLine> birds;
  final List<_BuildingBand> buildings;
  final List<_ScenePulse> flares;
  final List<_SunRayParticle> sunRays;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2D1F3D),
          Color(0xFFB4575D),
          Color(0xFFF59A61),
          Color(0xFF1D1D2C),
        ],
        stops: [0.0, 0.35, 0.66, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sunCenter = Offset(size.width * 0.78, size.height * 0.22);
    final sunRadius = size.width * 0.19;
    final sun = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFE2A6).withValues(alpha: 0.85),
              const Color(0xFFFFAF75).withValues(alpha: 0.35),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: sunCenter, radius: sunRadius * 2.1),
          );
    canvas.drawCircle(sunCenter, sunRadius * 2.1, sun);

    for (final cloud in clouds) {
      final cx = cloud.x * size.width;
      final cy = cloud.y * size.height;
      final cw = cloud.widthFactor * size.width;
      final ch = cloud.heightFactor * size.height;
      final paint = Paint()
        ..color = const Color(0xFFFFE8D2).withValues(alpha: 0.16);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - cw * 0.24, cy + ch * 0.05),
          width: cw * 0.7,
          height: ch * 0.75,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + cw * 0.24, cy - ch * 0.04),
          width: cw * 0.66,
          height: ch * 0.72,
        ),
        paint,
      );
    }

    var cursor = 0.0;
    for (var i = 0; i < buildings.length; i++) {
      final b = buildings[i];
      final width = size.width * b.widthFactor;
      final height = size.height * (0.18 + b.heightFactor);
      final rect = Rect.fromLTWH(cursor, size.height - height, width, height);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF171823).withValues(alpha: 0.84),
      );
      cursor += width + 2;
      if (cursor > size.width) break;
    }

    final birdPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A1F2A).withValues(alpha: 0.8);
    for (final bird in birds) {
      final bx = bird.x * size.width;
      final by =
          bird.y * size.height + math.sin(timeSeconds * 1.8 + bird.phase) * 4;
      final span =
          8 + (0.5 + 0.5 * math.sin(timeSeconds * 2.2 + bird.phase)) * 8;
      final path = Path()
        ..moveTo(bx - span, by)
        ..quadraticBezierTo(bx - span * 0.4, by - span * 0.55, bx, by)
        ..quadraticBezierTo(bx + span * 0.4, by - span * 0.55, bx + span, by);
      canvas.drawPath(path, birdPaint);
    }

    for (final flare in flares) {
      final age = (timeSeconds - flare.startSeconds).clamp(0.0, 1.8);
      final alpha = (1 - age / 1.8).clamp(0.0, 1.0);
      final radius = 24 + age * 170;
      final glow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFE3B2).withValues(alpha: alpha * 0.22),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: flare.center, radius: radius + 26),
            );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFFE3B2).withValues(alpha: alpha * 0.44);
      canvas.drawCircle(flare.center, radius + 26, glow);
      canvas.drawCircle(flare.center, radius, ring);
    }

    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3;
    for (final ray in sunRays) {
      final age = (timeSeconds - ray.startSeconds).clamp(0.0, ray.life);
      final alpha = (1 - age / ray.life).clamp(0.0, 1.0);
      rayPaint.color = const Color(0xFFFFE3B2).withValues(alpha: alpha * 0.46);
      final end =
          ray.center +
          Offset(math.cos(ray.angle), math.sin(ray.angle)) * ray.length;
      canvas.drawLine(ray.center, end, rayPaint);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF130E1A).withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant _SunsetCityPainter oldDelegate) => true;
}

class _SpaceStar {
  _SpaceStar({
    required this.pos,
    required this.drift,
    required this.radius,
    required this.phase,
  });

  Offset pos;
  final double drift;
  final double radius;
  final double phase;
}

class _ScenePulse {
  const _ScenePulse({
    required this.center,
    required this.startSeconds,
    required this.strength,
  });

  final Offset center;
  final double startSeconds;
  final double strength;
}

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.thickness,
  });

  double x;
  double y;
  final double speed;
  final double length;
  final double thickness;
}

class _BuildingBand {
  const _BuildingBand({
    required this.widthFactor,
    required this.heightFactor,
    required this.windowOffset,
  });

  final double widthFactor;
  final double heightFactor;
  final double windowOffset;
}

class _Firefly {
  _Firefly({
    required this.pos,
    required this.velocity,
    required this.radius,
    required this.phase,
  });

  Offset pos;
  Offset velocity;
  final double radius;
  final double phase;
}

class _TreeSilhouette {
  const _TreeSilhouette({
    required this.x,
    required this.width,
    required this.height,
  });

  final double x;
  final double width;
  final double height;
}

class _CloudBand {
  _CloudBand({
    required this.x,
    required this.y,
    required this.widthFactor,
    required this.heightFactor,
    required this.speed,
  });

  double x;
  final double y;
  final double widthFactor;
  final double heightFactor;
  final double speed;
}

class _BirdLine {
  _BirdLine({
    required this.x,
    required this.y,
    required this.phase,
    required this.speed,
  });

  double x;
  final double y;
  final double phase;
  final double speed;
}

class _WarpWell {
  const _WarpWell({
    required this.center,
    required this.startSeconds,
    required this.life,
    required this.strength,
  });

  final Offset center;
  final double startSeconds;
  final double life;
  final double strength;
}

class _SplashParticle {
  _SplashParticle({
    required this.position,
    required this.velocity,
    required this.startSeconds,
    required this.life,
    required this.radius,
  });

  Offset position;
  Offset velocity;
  final double startSeconds;
  final double life;
  final double radius;
}

class _SporeParticle {
  _SporeParticle({
    required this.position,
    required this.velocity,
    required this.startSeconds,
    required this.life,
    required this.radius,
    required this.phase,
  });

  Offset position;
  Offset velocity;
  final double startSeconds;
  final double life;
  final double radius;
  final double phase;
}

class _SunRayParticle {
  _SunRayParticle({
    required this.center,
    required this.angle,
    required this.length,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double angle;
  double length;
  final double startSeconds;
  final double life;
}
