import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class PremiumAtmosphereOverlay extends StatefulWidget {
  const PremiumAtmosphereOverlay({
    super.key,
    this.seed = 0,
    this.intensity = 1,
    this.showParticles = true,
  });

  final int seed;
  final double intensity;
  final bool showParticles;

  @override
  State<PremiumAtmosphereOverlay> createState() =>
      _PremiumAtmosphereOverlayState();
}

class _PremiumAtmosphereOverlayState extends State<PremiumAtmosphereOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 32),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }

    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final gold = Color.lerp(
      const Color(0xFFD7B472),
      colors?.accentSecondary ?? Colors.white,
      0.35,
    )!;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _PremiumAtmospherePainter(
                progress: _controller.value,
                seed: widget.seed,
                intensity: widget.intensity,
                showParticles: widget.showParticles,
                baseGlow: gold,
                ambientGlow:
                    gradients?.atmosphereHighlight ?? const Color(0xFF3D2E1D),
                mistColor: (colors?.textPrimary ?? Colors.white).withValues(
                  alpha: 0.1,
                ),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumAtmospherePainter extends CustomPainter {
  const _PremiumAtmospherePainter({
    required this.progress,
    required this.seed,
    required this.intensity,
    required this.showParticles,
    required this.baseGlow,
    required this.ambientGlow,
    required this.mistColor,
  });

  final double progress;
  final int seed;
  final double intensity;
  final bool showParticles;
  final Color baseGlow;
  final Color ambientGlow;
  final Color mistColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = progress * math.pi * 2;
    final safeIntensity = intensity.clamp(0.4, 1.8);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ambientGlow.withValues(alpha: 0.18 * safeIntensity),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18 * safeIntensity),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    _paintGlow(
      canvas,
      size,
      center: Offset(
        size.width * (0.16 + 0.04 * math.sin(t * 0.8 + seed)),
        size.height * (0.2 + 0.04 * math.cos(t * 0.65 + seed)),
      ),
      radius: size.width * 0.42,
      color: baseGlow.withValues(alpha: 0.12 * safeIntensity),
    );
    _paintGlow(
      canvas,
      size,
      center: Offset(
        size.width * (0.84 + 0.05 * math.cos(t * 0.52 + seed * 0.7)),
        size.height * (0.28 + 0.06 * math.sin(t * 0.76 + seed * 0.3)),
      ),
      radius: size.width * 0.3,
      color: ambientGlow.withValues(alpha: 0.1 * safeIntensity),
    );
    _paintGlow(
      canvas,
      size,
      center: Offset(
        size.width * 0.52,
        size.height * (0.82 + 0.03 * math.sin(t * 0.4 + seed)),
      ),
      radius: size.width * 0.48,
      color: baseGlow.withValues(alpha: 0.06 * safeIntensity),
    );

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          mistColor.withValues(alpha: 0.05 * safeIntensity),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.save();
    canvas.translate(size.width * 0.2, size.height * 0.08);
    canvas.rotate(-0.22 + 0.02 * math.sin(t * 0.55));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * 0.86, size.height * 0.15),
        const Radius.circular(999),
      ),
      beamPaint,
    );
    canvas.restore();

    if (showParticles) {
      for (var index = 0; index < 24; index++) {
        final phase = (seed * 0.19) + index * 0.71;
        final dx =
            ((math.sin(phase * 1.7) + 1) / 2) * size.width +
            math.sin(t * (0.24 + index * 0.01) + phase) * 16;
        final dy =
            ((math.cos(phase * 1.2) + 1) / 2) * size.height +
            math.cos(t * (0.18 + index * 0.015) + phase) * 18;
        final alpha = (0.04 + (index % 5) * 0.01) * safeIntensity;
        final radius = 0.8 + (index % 3) * 0.9;
        canvas.drawCircle(
          Offset(dx, dy),
          radius,
          Paint()..color = mistColor.withValues(alpha: alpha.clamp(0.01, 0.11)),
        );
      }
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.25,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18 * safeIntensity),
            Colors.black.withValues(alpha: 0.34 * safeIntensity),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(rect),
    );
  }

  void _paintGlow(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.intensity != intensity ||
        oldDelegate.showParticles != showParticles ||
        oldDelegate.baseGlow != baseGlow ||
        oldDelegate.ambientGlow != ambientGlow ||
        oldDelegate.mistColor != mistColor;
  }
}
