import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_background.dart';
import 'theme_color_definitions.dart';

class RainBackground extends ThemeBackground {
  const RainBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<RainBackground> createState() => _RainBackgroundState();
}

class _RainBackgroundState extends ThemeBackgroundState<RainBackground> {
  final List<_RainDrop> _drops = <_RainDrop>[];
  final List<double> _skyline = <double>[];
  final List<_PuddleRipple> _ripples = <_PuddleRipple>[];

  @override
  Duration get animationDuration => const Duration(seconds: 24);

  @override
  void initializeScene() {
    _drops.clear();
    _skyline.clear();

    for (var i = 0; i < 52; i++) {
      final foreground = i < 26;
      _drops.add(
        _RainDrop(
          x: random.nextDouble(),
          y: random.nextDouble(),
          speed: foreground
              ? 0.18 + random.nextDouble() * 0.18
              : 0.1 + random.nextDouble() * 0.08,
          length: foreground
              ? 12 + random.nextDouble() * 12
              : 8 + random.nextDouble() * 8,
          width: foreground ? 1.0 : 0.7,
          alpha: foreground ? 0.18 : 0.1,
        ),
      );
    }

    for (var i = 0; i < 20; i++) {
      _skyline.add(0.22 + random.nextDouble() * 0.26);
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final speedScale = (0.38 + widget.motionScale * 0.18).clamp(0.25, 0.7);
    for (final drop in _drops) {
      drop.y += drop.speed * deltaSeconds * speedScale;
      if (drop.y > 1.15) {
        drop.y = -0.08;
        drop.x = random.nextDouble();
      }
    }

    _ripples.removeWhere(
      (ripple) => elapsedSeconds - ripple.startSeconds > ripple.life,
    );
  }

  @override
  void onSceneTap(Offset localPosition) {
    final now = (controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    if (_ripples.length > 4) {
      _ripples.removeAt(0);
    }
    _ripples.add(
      _PuddleRipple(center: localPosition, startSeconds: now, life: 2.1),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _RainPainter(
        animation: repaint,
        drops: _drops,
        skyline: _skyline,
        ripples: _ripples,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter({
    required this.animation,
    required this.drops,
    required this.skyline,
    required this.ripples,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_RainDrop> drops;
  final List<double> skyline;
  final List<_PuddleRipple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.rain;
    final elapsed = animation.value * 24.0;

    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, palette.baseBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final hazeA = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.2 + math.sin(elapsed * 0.07) * 0.04, -0.3),
        radius: 1.1,
        colors: [palette.hazeA, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hazeA);

    final skylinePath = Path()..moveTo(0, size.height);
    skylinePath.lineTo(0, size.height * (0.72 - skyline.first * 0.12));
    for (var i = 0; i < skyline.length; i++) {
      final x = (i / (skyline.length - 1)) * size.width;
      final h = size.height * (0.78 - skyline[i] * 0.42);
      skylinePath.lineTo(x, h);
    }
    skylinePath.lineTo(size.width, size.height);
    skylinePath.close();

    final skylinePaint = Paint()
      ..color = const Color(0xCC0A131B).withValues(alpha: 0.56)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(skylinePath, skylinePaint);

    final mistRect = Rect.fromLTWH(
      0,
      size.height * 0.62 + math.sin(elapsed * 0.12) * 10,
      size.width,
      size.height * 0.4,
    );
    final mist = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.hazeB, Colors.transparent],
      ).createShader(mistRect);
    canvas.drawRect(mistRect, mist);

    for (final drop in drops) {
      final sx = drop.x * size.width;
      final sy = drop.y * size.height;
      final ex = sx - drop.length * 0.16;
      final ey = sy + drop.length;
      final paint = Paint()
        ..strokeWidth = drop.width
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFCCDFE7).withValues(alpha: drop.alpha);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), paint);
    }

    for (final ripple in ripples) {
      final age = (elapsed - ripple.startSeconds).clamp(0.0, ripple.life);
      final progress = age / ripple.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 14 + progress * 140;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFC8DCE3).withValues(alpha: alpha * 0.22);
      final blur = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0x8888A8BA).withValues(alpha: alpha * 0.12),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: ripple.center, radius: radius + 20),
            );
      canvas.drawCircle(ripple.center, radius + 20, blur);
      canvas.drawCircle(ripple.center, radius, ring);
    }

    final lightningPulse = math
        .pow(((math.sin(elapsed * 0.34 + 1.3) + 1) / 2), 16)
        .toDouble();
    if (lightningPulse > 0.001) {
      final flash = Paint()
        ..color = const Color(
          0xFFB7CADA,
        ).withValues(alpha: lightningPulse * 0.08);
      canvas.drawRect(Offset.zero & size, flash);
    }

    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x11000000), Color(0x66000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => false;
}

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.width,
    required this.alpha,
  });

  double x;
  double y;
  final double speed;
  final double length;
  final double width;
  final double alpha;
}

class _PuddleRipple {
  const _PuddleRipple({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}
