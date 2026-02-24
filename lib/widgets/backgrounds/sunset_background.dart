import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_background.dart';
import 'theme_color_definitions.dart';

class SunsetBackground extends ThemeBackground {
  const SunsetBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });

  @override
  State<SunsetBackground> createState() => _SunsetBackgroundState();
}

class _SunsetBackgroundState extends ThemeBackgroundState<SunsetBackground> {
  final List<_CloudHaze> _clouds = <_CloudHaze>[];
  final List<double> _skyline = <double>[];
  final List<_WarmBloom> _blooms = <_WarmBloom>[];

  @override
  Duration get animationDuration => const Duration(seconds: 26);

  @override
  void initializeScene() {
    _clouds.clear();
    _skyline.clear();

    for (var i = 0; i < 6; i++) {
      _clouds.add(
        _CloudHaze(
          x: random.nextDouble(),
          y: 0.12 + random.nextDouble() * 0.38,
          width: 0.22 + random.nextDouble() * 0.28,
          height: 0.05 + random.nextDouble() * 0.08,
          speed: 0.002 + random.nextDouble() * 0.004,
          alpha: 0.08 + random.nextDouble() * 0.08,
          phase: random.nextDouble() * math.pi * 2,
        ),
      );
    }

    for (var i = 0; i < 18; i++) {
      _skyline.add(0.12 + random.nextDouble() * 0.2);
    }
  }

  @override
  void onFrame(double elapsedSeconds, double deltaSeconds) {
    final driftScale = (0.44 + widget.motionScale * 0.16).clamp(0.25, 0.72);
    for (final cloud in _clouds) {
      cloud.x += cloud.speed * deltaSeconds * driftScale;
      if (cloud.x > 1.25) {
        cloud.x = -0.25;
      }
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
      _WarmBloom(center: localPosition, startSeconds: now, life: 2.3),
    );
  }

  @override
  Widget buildScene(BuildContext context, Animation<double> repaint) {
    return CustomPaint(
      painter: _SunsetPainter(
        animation: repaint,
        clouds: _clouds,
        skyline: _skyline,
        blooms: _blooms,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SunsetPainter extends CustomPainter {
  _SunsetPainter({
    required this.animation,
    required this.clouds,
    required this.skyline,
    required this.blooms,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_CloudHaze> clouds;
  final List<double> skyline;
  final List<_WarmBloom> blooms;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ThemeColorDefinitions.sunset;
    final elapsed = animation.value * 26.0;

    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.baseTop, const Color(0xFF7A536B), palette.baseBottom],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final horizonCenter = Offset(
      size.width * (0.52 + math.sin(elapsed * 0.05) * 0.01),
      size.height * 0.64,
    );
    final horizon = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.accent.withValues(alpha: 0.26),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: horizonCenter, radius: size.width * 0.5),
          );
    canvas.drawCircle(horizonCenter, size.width * 0.5, horizon);

    for (final cloud in clouds) {
      final cx = cloud.x * size.width;
      final cy =
          (cloud.y + math.sin(elapsed * 0.11 + cloud.phase) * 0.006) *
          size.height;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: cloud.width * size.width,
        height: cloud.height * size.height,
      );
      final paint = Paint()
        ..color = const Color(0xFFFFE8D7).withValues(alpha: cloud.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
      canvas.drawOval(rect, paint);
    }

    final skylinePath = Path()..moveTo(0, size.height);
    skylinePath.lineTo(0, size.height * (0.82 - skyline.first * 0.18));
    for (var i = 0; i < skyline.length; i++) {
      final x = (i / (skyline.length - 1)) * size.width;
      final y = size.height * (0.86 - skyline[i] * 0.35);
      skylinePath.lineTo(x, y);
    }
    skylinePath.lineTo(size.width, size.height);
    skylinePath.close();

    final skylinePaint = Paint()
      ..color = const Color(0xFF1E1925).withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawPath(skylinePath, skylinePaint);

    for (final bloom in blooms) {
      final age = (elapsed - bloom.startSeconds).clamp(0.0, bloom.life);
      final progress = age / bloom.life;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 18 + progress * 140;
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFD6B6).withValues(alpha: alpha * 0.22),
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
        colors: [Color(0x05000000), Color(0x4D000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter oldDelegate) => false;
}

class _CloudHaze {
  _CloudHaze({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.alpha,
    required this.phase,
  });

  double x;
  final double y;
  final double width;
  final double height;
  final double speed;
  final double alpha;
  final double phase;
}

class _WarmBloom {
  const _WarmBloom({
    required this.center,
    required this.startSeconds,
    required this.life,
  });

  final Offset center;
  final double startSeconds;
  final double life;
}
