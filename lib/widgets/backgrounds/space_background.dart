import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_background.dart';
import 'theme_color_definitions.dart';

class SpaceBackground extends ThemeBackground {
  const SpaceBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends ThemeBackgroundState<SpaceBackground> {
  final List<_Star> _stars = <_Star>[];
  final List<_WarpPulse> _warps = <_WarpPulse>[];
  final List<_SoftStreak> _streaks = <_SoftStreak>[];

  double _nextStreakAt = 18;

  @override
  Duration get animationDuration => const Duration(seconds: 34);

  @override
  void initializeScene() {
    _stars.clear();
    for (var i = 0; i < 64; i++) {
      final depth = random.nextDouble();
      _stars.add(
        _Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          depth: depth,
          radius: 0.4 + depth * 1.5,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }
    _nextStreakAt = 16 + random.nextDouble() * 12;
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.4 + widget.motionScale * 0.2).clamp(0.25, 0.8);
    for (final star in _stars) {
      final speed = 0.001 + star.depth * 0.003;
      star.x += speed * deltaSeconds * driftScale;
      final sway = math.sin(elapsedSeconds * 0.09 + star.phase) * 0.00004;
      star.y += sway * deltaSeconds;
      if (star.x > 1.03) {
        star.x = -0.03;
      }
      if (star.y < -0.03) {
        star.y = 1.03;
      } else if (star.y > 1.03) {
        star.y = -0.03;
      }
    }

    _warps.removeWhere(
      (warp) => elapsedSeconds - warp.startSeconds > warp.life,
    );
    _streaks.removeWhere(
      (streak) => elapsedSeconds - streak.startSeconds > streak.life,
    );

    if (elapsedSeconds >= _nextStreakAt && _streaks.isEmpty) {
      final start = Offset(
        random.nextDouble() * 0.7 + 0.2,
        random.nextDouble() * 0.4 + 0.05,
      );
      final end = Offset(
        (start.dx - 0.18 - random.nextDouble() * 0.12).clamp(0.0, 1.0),
        (start.dy + 0.08 + random.nextDouble() * 0.1).clamp(0.0, 1.0),
      );
      _streaks.add(
        _SoftStreak(
          start: start,
          end: end,
          startSeconds: elapsedSeconds,
          life: 2.0 + random.nextDouble() * 1.2,
        ),
      );
      _nextStreakAt = elapsedSeconds + 18 + random.nextDouble() * 16;
    }
  }

  @override
  void onSceneTap(Offset localPosition) {
    final now = (controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    if (_warps.length > 4) {
      _warps.removeAt(0);
    }
    _warps.add(_WarpPulse(center: localPosition, startSeconds: now, life: 2.6));
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _SpacePainter(
        animation: repaint,
        stars: _stars,
        warps: _warps,
        streaks: _streaks,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter({
    required this.animation,
    required this.stars,
    required this.warps,
    required this.streaks,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Star> stars;
  final List<_WarpPulse> warps;
  final List<_SoftStreak> streaks;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.space;
    final elapsed = animation.value * 34.0;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, palette.baseBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final fogA = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.5 + math.sin(elapsed * 0.06) * 0.08, -0.35),
        radius: 1.2,
        colors: [palette.hazeA, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fogA);

    final fogB = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.68 + math.cos(elapsed * 0.05) * 0.06, 0.4),
        radius: 1.05,
        colors: [palette.hazeB, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fogB);

    for (final star in stars) {
      final px = star.x * size.width;
      final py = star.y * size.height;
      final twinkle = 0.45 + 0.55 * math.sin(elapsed * 0.8 + star.phase);
      final alpha = (0.12 + star.depth * 0.33) * twinkle;
      final paint = Paint()
        ..color = const Color(
          0xFFE8EDF6,
        ).withValues(alpha: alpha.clamp(0.04, 0.38))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          0.8 + star.depth * 1.2,
        );
      canvas.drawCircle(Offset(px, py), star.radius, paint);
    }

    for (final streak in streaks) {
      final age = (elapsed - streak.startSeconds).clamp(0.0, streak.life);
      final progress = age / streak.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final sx = streak.start.dx * size.width;
      final sy = streak.start.dy * size.height;
      final ex = streak.end.dx * size.width;
      final ey = streak.end.dy * size.height;
      final current = Offset(
        sx + (ex - sx) * progress,
        sy + (ey - sy) * progress,
      );
      final trail = Offset(
        current.dx + (sx - ex) * 0.4,
        current.dy + (sy - ey) * 0.4,
      );
      final paint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            const Color(0xFFE8EEF6).withValues(alpha: alpha * 0.4),
          ],
        ).createShader(Rect.fromPoints(current, trail));
      canvas.drawLine(trail, current, paint);
    }

    for (final warp in warps) {
      final age = (elapsed - warp.startSeconds).clamp(0.0, warp.life);
      final progress = age / warp.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 18 + progress * 170;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFDDE8FB).withValues(alpha: alpha * 0.22);
      final halo = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xB89BB6E0).withValues(alpha: alpha * 0.14),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: warp.center, radius: radius + 24),
            );
      canvas.drawCircle(warp.center, radius + 24, halo);
      canvas.drawCircle(warp.center, radius, ring);
    }

    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x11000000), Color(0x4D000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.depth,
    required this.radius,
    required this.phase,
  });

  double x;
  double y;
  final double depth;
  final double radius;
  final double phase;
}

class _WarpPulse {
  const _WarpPulse({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}

class _SoftStreak {
  const _SoftStreak({
    required this.start,
    required this.end,
    required this.startSeconds,
    required this.life,
  });

  final Offset start;
  final Offset end;
  final double startSeconds;
  final double life;
}
