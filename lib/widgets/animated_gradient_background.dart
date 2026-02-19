import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    this.seed = 0,
    this.motionScale = 1.0,
  });

  final int seed;
  final double motionScale;

  static final StreamController<Offset> _globalRippleBus =
      StreamController<Offset>.broadcast();

  static Stream<Offset> get globalRippleStream => _globalRippleBus.stream;

  static void emitGlobalRipple(Offset globalPosition) {
    if (!_globalRippleBus.isClosed) {
      _globalRippleBus.add(globalPosition);
    }
  }

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  static const _fishCount = 14;

  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_Fish> _fishes;
  final List<_Ripple> _ripples = <_Ripple>[];
  StreamSubscription<Offset>? _globalRippleSub;

  Size _size = Size.zero;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(7331 + widget.seed);
    _fishes = List<_Fish>.generate(_fishCount, (i) => _Fish.random(_random, i));
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
    _globalRippleSub = AnimatedGradientBackground._globalRippleBus.stream
        .listen(_onGlobalTouch);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    _globalRippleSub?.cancel();
    super.dispose();
  }

  void _onGlobalTouch(Offset globalPos) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(globalPos);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return;
    }
    _onTouch(local);
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    _update(dt, now);
    if (mounted) setState(() {});
  }

  void _onTouch(Offset localPos) {
    if (_size.width <= 0 || _size.height <= 0) return;
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;

    var touchedFish = false;
    for (final fish in _fishes) {
      final p = fish.position(_size);
      final dist = (p - localPos).distance;
      if (dist < fish.bodyLength * 0.62) {
        touchedFish = true;
        final away = p - localPos;
        final dir = away.distance < 0.001
            ? const Offset(1, 0)
            : away / away.distance;
        fish.velocity += dir * (220 * widget.motionScale);
        fish.panic = 1.0;
      }
    }

    _ripples.add(
      _Ripple(
        center: localPos,
        startSeconds: now,
        strength: touchedFish ? 1.0 : 0.33,
      ),
    );
  }

  void _update(double dt, double timeSeconds) {
    if (_size.width <= 0 || _size.height <= 0) return;

    _ripples.removeWhere((r) => timeSeconds - r.startSeconds > 2.2);

    for (final fish in _fishes) {
      final p = fish.position(_size);

      // Loose schooling behavior for fish sharing the same school id.
      Offset avgVel = Offset.zero;
      Offset avgPos = Offset.zero;
      var neighbors = 0;
      for (final other in _fishes) {
        if (identical(fish, other) || other.schoolId != fish.schoolId) continue;
        final op = other.position(_size);
        final d = (op - p).distance;
        if (d > 130) continue;
        avgVel += other.velocity;
        avgPos += op;
        neighbors += 1;
      }
      if (neighbors > 0) {
        avgVel /= neighbors.toDouble();
        avgPos /= neighbors.toDouble();
        final align = (avgVel - fish.velocity) * 0.018;
        final cohesion = (avgPos - p) * 0.0045;
        fish.velocity += (align + cohesion) * widget.motionScale;
      }

      final currentHeading = math.atan2(fish.velocity.dy, fish.velocity.dx);
      final wander = fish.wanderPhase + timeSeconds * (0.2 + fish.size * 0.12);
      final desiredHeading = currentHeading + math.sin(wander) * 0.27;
      final desiredSpeed =
          fish.baseSpeed + fish.panic * (120 * widget.motionScale);
      final desiredVel =
          Offset(math.cos(desiredHeading), math.sin(desiredHeading)) *
          desiredSpeed;

      fish.velocity +=
          (desiredVel - fish.velocity) * dt * (0.9 + fish.panic * 2.0);

      for (final ripple in _ripples) {
        final age = (timeSeconds - ripple.startSeconds).clamp(0.0, 2.2);
        final radius = age * 170;
        final dist = (p - ripple.center).distance;
        final waveBand = 42.0;
        final wave = math.exp(
          -math.pow((dist - radius) / waveBand, 2).toDouble(),
        );
        if (wave < 0.0009) continue;
        final dir = dist < 0.001
            ? const Offset(1, 0)
            : (p - ripple.center) / dist;
        fish.velocity +=
            dir *
            wave *
            ((82 + ripple.strength * 160) * widget.motionScale) *
            dt;
      }

      // Soft boundary steering for natural turns.
      const margin = 32.0;
      var boundaryForce = Offset.zero;
      if (p.dx < margin) {
        boundaryForce += const Offset(1, 0) * (margin - p.dx) * 0.45;
      }
      if (p.dx > _size.width - margin) {
        boundaryForce +=
            const Offset(-1, 0) * (p.dx - (_size.width - margin)) * 0.45;
      }
      if (p.dy < margin) {
        boundaryForce += const Offset(0, 1) * (margin - p.dy) * 0.6;
      }
      if (p.dy > _size.height - margin) {
        boundaryForce +=
            const Offset(0, -1) * (p.dy - (_size.height - margin)) * 0.6;
      }
      fish.velocity += boundaryForce * dt;

      fish.panic = (fish.panic - dt * 0.28).clamp(0.0, 1.0);

      final speed = fish.velocity.distance;
      final minS = fish.baseSpeed * 0.7;
      final maxS =
          fish.baseSpeed + (130 * widget.motionScale) * fish.panic + 38;
      if (speed < minS) {
        final dir = speed < 0.001 ? const Offset(1, 0) : fish.velocity / speed;
        fish.velocity = dir * minS;
      } else if (speed > maxS) {
        fish.velocity = (fish.velocity / speed) * maxS;
      }

      fish.velocity *= (0.968 - fish.panic * 0.03 * widget.motionScale);

      final next = p + fish.velocity * dt;
      fish.pos = Offset(
        (next.dx / _size.width).clamp(-0.08, 1.08),
        (next.dy / _size.height).clamp(0.02, 0.98),
      );

      if (next.dx < -48) {
        fish.pos = Offset(1.1, fish.pos.dy);
      }
      if (next.dx > _size.width + 48) {
        fish.pos = Offset(-0.1, fish.pos.dy);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final timeSeconds =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;

        return CustomPaint(
          painter: _EmeraldAquariumPainter(
            fishes: _fishes,
            ripples: _ripples,
            timeSeconds: timeSeconds,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _EmeraldAquariumPainter extends CustomPainter {
  const _EmeraldAquariumPainter({
    required this.fishes,
    required this.ripples,
    required this.timeSeconds,
  });

  final List<_Fish> fishes;
  final List<_Ripple> ripples;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF031814), Color(0xFF052E27), Color(0xFF04100D)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final softA = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.35),
        radius: 1.1,
        colors: [
          const Color(0xFF1BC2A0).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, softA);

    final softB = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.85),
        radius: 1.0,
        colors: [
          const Color(0xFF0FAE88).withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, softB);

    for (final fish in fishes) {
      _paintFish(canvas, size, fish, timeSeconds);
    }

    for (final ripple in ripples) {
      final age = (timeSeconds - ripple.startSeconds).clamp(0.0, 2.2);
      final radius = age * 170;
      final alpha = (1 - age / 2.2).clamp(0.0, 1.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + ripple.strength * 1.6
        ..color = const Color(
          0xFFC8FFF2,
        ).withValues(alpha: alpha * (0.12 + ripple.strength * 0.14));
      canvas.drawCircle(ripple.center, radius, paint);
    }

    final glass = Paint()
      ..color = const Color(0xFF0E3B32).withValues(alpha: 0.63);
    canvas.drawRect(Offset.zero & size, glass);

    final highlight = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x6AFFFFFF), Color(0x00FFFFFF), Color(0x26000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlight);
  }

  void _paintFish(Canvas canvas, Size size, _Fish fish, double t) {
    final p = fish.position(size);
    final heading = math.atan2(fish.velocity.dy, fish.velocity.dx);
    final tailWave = math.sin(t * (8.0 + fish.size * 2.4) + fish.phase);
    final len = fish.bodyLength;
    final h = fish.bodyHeight;
    final glowR = len * (1.1 + fish.panic * 0.45);

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(heading);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          fish.color.withValues(alpha: 0.34 + fish.panic * 0.24),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: glowR));
    canvas.drawCircle(Offset.zero, glowR, glow);

    final bodyPath = switch (fish.shape) {
      _FishShape.torpedo =>
        Path()
          ..moveTo(len * 0.56, 0)
          ..quadraticBezierTo(len * 0.24, -h * 0.58, -len * 0.5, -h * 0.36)
          ..quadraticBezierTo(-len * 0.62, 0, -len * 0.5, h * 0.36)
          ..quadraticBezierTo(len * 0.24, h * 0.58, len * 0.56, 0)
          ..close(),
      _FishShape.oval =>
        Path()
          ..moveTo(len * 0.46, 0)
          ..quadraticBezierTo(len * 0.08, -h * 0.92, -len * 0.36, -h * 0.5)
          ..quadraticBezierTo(-len * 0.46, 0, -len * 0.36, h * 0.5)
          ..quadraticBezierTo(len * 0.08, h * 0.92, len * 0.46, 0)
          ..close(),
      _FishShape.angler =>
        Path()
          ..moveTo(len * 0.4, 0)
          ..quadraticBezierTo(0, -h * 0.8, -len * 0.34, -h * 0.62)
          ..quadraticBezierTo(-len * 0.54, 0, -len * 0.34, h * 0.62)
          ..quadraticBezierTo(0, h * 0.8, len * 0.4, 0)
          ..close(),
    };
    final bodyPaint = Paint()..color = fish.color.withValues(alpha: 0.9);
    canvas.drawPath(bodyPath, bodyPaint);

    final bellyPath = Path()
      ..moveTo(len * 0.16, 0)
      ..quadraticBezierTo(-len * 0.05, h * 0.32, -len * 0.3, h * 0.14)
      ..quadraticBezierTo(-len * 0.08, h * 0.03, len * 0.22, 0)
      ..close();
    final bellyPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawPath(bellyPath, bellyPaint);

    final tailSpread = switch (fish.shape) {
      _FishShape.torpedo => 0.42,
      _FishShape.oval => 0.62,
      _FishShape.angler => 0.72,
    };
    final tailPath = Path()
      ..moveTo(-len * 0.42, 0)
      ..quadraticBezierTo(
        -len * 0.68,
        -h * (tailSpread + tailWave * 0.2),
        -len * 0.88,
        -h * 0.15,
      )
      ..quadraticBezierTo(-len * 0.74, 0, -len * 0.88, h * 0.15)
      ..quadraticBezierTo(
        -len * 0.68,
        h * (tailSpread + tailWave * 0.2),
        -len * 0.42,
        0,
      )
      ..close();
    final tailPaint = Paint()..color = fish.color.withValues(alpha: 0.76);
    canvas.drawPath(tailPath, tailPaint);

    final finPaint = Paint()..color = fish.color.withValues(alpha: 0.58);
    final finPath = Path()
      ..moveTo(-len * 0.06, -h * 0.08)
      ..quadraticBezierTo(
        len * 0.12,
        -h * (0.66 + tailWave * 0.08),
        len * 0.26,
        -h * 0.12,
      )
      ..close();
    canvas.drawPath(finPath, finPaint);

    final eyePaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(Offset(len * 0.2, -h * 0.16), 1.3, eyePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmeraldAquariumPainter oldDelegate) => true;
}

class _Fish {
  _Fish({
    required this.id,
    required this.pos,
    required this.velocity,
    required this.size,
    required this.color,
    required this.phase,
    required this.wanderPhase,
    required this.baseSpeed,
    required this.shape,
    required this.schoolId,
  }) : bodyLength = switch (shape) {
         _FishShape.torpedo => 18 + size * 18,
         _FishShape.oval => 16 + size * 14,
         _FishShape.angler => 15 + size * 12,
       },
       bodyHeight = switch (shape) {
         _FishShape.torpedo => 6 + size * 4.2,
         _FishShape.oval => 8 + size * 7.2,
         _FishShape.angler => 9 + size * 8.4,
       };

  factory _Fish.random(math.Random random, int id) {
    final shape = _FishShape.values[random.nextInt(_FishShape.values.length)];
    final hue = switch (shape) {
      _FishShape.torpedo => 160 + random.nextDouble() * 26,
      _FishShape.oval => 172 + random.nextDouble() * 22,
      _FishShape.angler => 150 + random.nextDouble() * 18,
    };
    final sat = switch (shape) {
      _FishShape.torpedo => 0.32 + random.nextDouble() * 0.24,
      _FishShape.oval => 0.28 + random.nextDouble() * 0.2,
      _FishShape.angler => 0.22 + random.nextDouble() * 0.16,
    };
    final light = switch (shape) {
      _FishShape.torpedo => 0.5 + random.nextDouble() * 0.2,
      _FishShape.oval => 0.52 + random.nextDouble() * 0.2,
      _FishShape.angler => 0.4 + random.nextDouble() * 0.14,
    };
    final angle = random.nextDouble() * math.pi * 2;
    final size = switch (shape) {
      _FishShape.torpedo => 0.58 + random.nextDouble() * 0.9,
      _FishShape.oval => 0.78 + random.nextDouble() * 1.1,
      _FishShape.angler => 0.92 + random.nextDouble() * 1.18,
    };
    final speed = 18 + random.nextDouble() * 22;
    return _Fish(
      id: id,
      pos: Offset(random.nextDouble(), random.nextDouble()),
      velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
      size: size,
      color: HSLColor.fromAHSL(1, hue, sat, light).toColor(),
      phase: random.nextDouble() * math.pi * 2,
      wanderPhase: random.nextDouble() * math.pi * 2,
      baseSpeed: speed,
      shape: shape,
      schoolId: random.nextInt(4),
    );
  }

  final int id;
  Offset pos;
  Offset velocity;
  final double size;
  final Color color;
  final double phase;
  final double wanderPhase;
  final double baseSpeed;
  final _FishShape shape;
  final int schoolId;
  final double bodyLength;
  final double bodyHeight;
  double panic = 0;

  Offset position(Size size) =>
      Offset(pos.dx * size.width, pos.dy * size.height);
}

enum _FishShape { torpedo, oval, angler }

class _Ripple {
  const _Ripple({
    required this.center,
    required this.startSeconds,
    required this.strength,
  });

  final Offset center;
  final double startSeconds;
  final double strength;
}
