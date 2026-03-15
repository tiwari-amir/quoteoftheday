import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/v3_background/background_theme_provider.dart';
import '../theme/design_tokens.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, this.seed = 0, this.motionScale = 1.0});

  final int seed;
  final double motionScale;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 72),
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
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CinematicBackgroundPainter(
                progress: _controller.value,
                seed: widget.seed,
                motionScale: widget.motionScale,
                mood: flow?.mood ?? AppBackgroundTheme.spaceGalaxies,
                background: colors?.background ?? const Color(0xFF020406),
                atmosphereTop:
                    gradients?.atmosphereTop ?? const Color(0xFF091016),
                atmosphereBottom:
                    gradients?.atmosphereBottom ?? const Color(0xFF020304),
                atmosphereHighlight:
                    gradients?.atmosphereHighlight ?? const Color(0xFF322316),
                accentPrimary:
                    gradients?.accentStart ?? const Color(0xFFD4AB66),
                accentSecondary:
                    gradients?.accentEnd ?? const Color(0xFFF1DAB1),
                mistTint: (colors?.textPrimary ?? Colors.white).withValues(
                  alpha: 0.08,
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

class _CinematicBackgroundPainter extends CustomPainter {
  const _CinematicBackgroundPainter({
    required this.progress,
    required this.seed,
    required this.motionScale,
    required this.mood,
    required this.background,
    required this.atmosphereTop,
    required this.atmosphereBottom,
    required this.atmosphereHighlight,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.mistTint,
  });

  final double progress;
  final int seed;
  final double motionScale;
  final AppBackgroundTheme mood;
  final Color background;
  final Color atmosphereTop;
  final Color atmosphereBottom;
  final Color atmosphereHighlight;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color mistTint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = progress * math.pi * 2;
    final motion = motionScale.clamp(0.35, 1.1);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [atmosphereTop, background, atmosphereBottom],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.8, 1),
          colors: [
            accentPrimary.withValues(alpha: 0.06),
            Colors.transparent,
            accentSecondary.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    _paintOrb(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.48),
      width: size.width * 1.2,
      height: size.height * 0.88,
      color: atmosphereHighlight,
      opacity: 0.09,
    );
    _paintVeil(
      canvas,
      center: Offset(
        size.width * (0.48 + 0.02 * math.sin(t * 0.18 + seed * 0.13)),
        size.height * 0.34,
      ),
      width: size.width * 1.18,
      height: size.height * 0.18,
      rotation: -0.18 + 0.01 * math.cos(t * 0.22 + seed * 0.11),
      color: mistTint,
      opacity: 0.032,
    );

    _paintMoodOverlay(canvas, size, rect, t, motion);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.18,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.36),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0.0, 0.34, 1.0],
        ).createShader(rect),
    );
  }

  void _paintOrb(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double opacity,
    double featherStop = 0.56,
  }) {
    final orbRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );
    final blurSigma = math.max(
      14.0,
      math.min(30.0, math.min(width, height) * 0.08),
    );
    canvas.drawOval(
      orbRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.42),
            Colors.transparent,
          ],
          stops: [0.0, featherStop, 1.0],
        ).createShader(orbRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma),
    );
  }

  void _paintVeil(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double rotation,
    required Color color,
    required double opacity,
  }) {
    final blurSigma = math.max(18.0, math.min(40.0, height * 0.22));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final veilRect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.drawOval(
      veilRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            color.withValues(alpha: opacity * 0.28),
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
        ).createShader(veilRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma),
    );
    canvas.restore();
  }

  void _paintMoodOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    switch (mood) {
      case AppBackgroundTheme.spaceGalaxies:
        _paintMidnightOverlay(canvas, size, rect, t, motion);
        break;
      case AppBackgroundTheme.sunsetCity:
        _paintSolarOverlay(canvas, size, rect, t, motion);
        break;
      case AppBackgroundTheme.deepForest:
        _paintZenOverlay(canvas, size, rect, t, motion);
        break;
      case AppBackgroundTheme.quoteflowGlow:
        _paintCyberOverlay(canvas, size, rect, t, motion);
        break;
      case AppBackgroundTheme.rainyCity:
        _paintClassicOverlay(canvas, size, rect, t, motion);
        break;
      case AppBackgroundTheme.oceanFloor:
        _paintEtherealOverlay(canvas, size, rect, t, motion);
        break;
    }
  }

  void _paintMidnightOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.2 + 0.025 * math.sin(t * 0.34 + seed * 0.31) * motion),
        size.height * (0.18 + 0.02 * math.cos(t * 0.28 + seed * 0.19) * motion),
      ),
      width: size.width * 0.84,
      height: size.height * 0.54,
      color: accentPrimary,
      opacity: 0.1,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.82 + 0.022 * math.cos(t * 0.26 + seed * 0.27) * motion),
        size.height *
            (0.24 + 0.018 * math.sin(t * 0.22 + seed * 0.12) * motion),
      ),
      width: size.width * 0.62,
      height: size.height * 0.42,
      color: atmosphereHighlight,
      opacity: 0.16,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * 0.52,
        size.height * (0.82 + 0.014 * math.cos(t * 0.18 + seed * 0.22)),
      ),
      width: size.width * 0.92,
      height: size.height * 0.34,
      color: accentSecondary,
      opacity: 0.04,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.4, size.height * 0.28),
      width: size.width * 1.02,
      height: size.height * 0.14,
      rotation: -0.22 + 0.012 * math.sin(t * 0.24),
      color: mistTint,
      opacity: 0.05,
    );
  }

  void _paintSolarOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    final horizonY = size.height * (0.78 + 0.012 * math.sin(t * 0.18));
    _paintOrb(
      canvas,
      center: Offset(size.width * 0.5, horizonY),
      width: size.width * 1.08,
      height: size.height * 0.46,
      color: accentPrimary,
      opacity: 0.15,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.76 + 0.018 * math.cos(t * 0.2 + seed * 0.16) * motion),
        size.height * 0.24,
      ),
      width: size.width * 0.54,
      height: size.height * 0.34,
      color: atmosphereHighlight,
      opacity: 0.13,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.64),
      width: size.width * 1.16,
      height: size.height * 0.14,
      rotation: -0.02,
      color: accentSecondary,
      opacity: 0.045,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.62, size.height * 0.18),
      width: size.width * 0.96,
      height: size.height * 0.12,
      rotation: -0.18 + 0.012 * math.sin(t * 0.22),
      color: accentPrimary,
      opacity: 0.035,
    );
  }

  void _paintZenOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    _paintOrb(
      canvas,
      center: Offset(size.width * 0.26, size.height * 0.24),
      width: size.width * 0.62,
      height: size.height * 0.38,
      color: accentPrimary,
      opacity: 0.08,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * 0.78,
        size.height * (0.7 + 0.014 * math.cos(t * 0.18 + seed * 0.2)),
      ),
      width: size.width * 0.56,
      height: size.height * 0.34,
      color: atmosphereHighlight,
      opacity: 0.14,
    );
    for (var index = 0; index < 3; index++) {
      _paintVeil(
        canvas,
        center: Offset(
          size.width * 0.5,
          size.height *
              (0.24 +
                  index * 0.22 +
                  0.016 * math.sin(t * 0.2 + index) * motion),
        ),
        width: size.width * 1.22,
        height: size.height * (0.11 + index * 0.01),
        rotation: -0.03 + index * 0.02,
        color: index.isEven ? mistTint : accentSecondary,
        opacity: 0.038 - index * 0.006,
      );
    }
  }

  void _paintCyberOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.8 + 0.016 * math.cos(t * 0.22 + seed * 0.18) * motion),
        size.height * 0.22,
      ),
      width: size.width * 0.56,
      height: size.height * 0.34,
      color: accentPrimary,
      opacity: 0.14,
    );
    _paintOrb(
      canvas,
      center: Offset(size.width * 0.22, size.height * 0.78),
      width: size.width * 0.48,
      height: size.height * 0.3,
      color: accentSecondary,
      opacity: 0.09,
    );
    _paintVeil(
      canvas,
      center: Offset(
        size.width * 0.52,
        size.height *
            (0.24 + 0.42 * ((math.sin(t * 0.16 + seed * 0.14) + 1) * 0.5)),
      ),
      width: size.width * 0.96,
      height: size.height * 0.09,
      rotation: -0.02,
      color: accentPrimary,
      opacity: 0.03,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.46, size.height * 0.38),
      width: size.width * 1.12,
      height: size.height * 0.12,
      rotation: -0.42 + 0.014 * math.sin(t * 0.2),
      color: accentSecondary,
      opacity: 0.026,
    );
  }

  void _paintClassicOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    _paintOrb(
      canvas,
      center: Offset(size.width * 0.72, size.height * 0.22),
      width: size.width * 0.44,
      height: size.height * 0.28,
      color: accentPrimary,
      opacity: 0.11,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * 0.24,
        size.height * (0.7 + 0.012 * math.sin(t * 0.16 + seed * 0.24)),
      ),
      width: size.width * 0.58,
      height: size.height * 0.34,
      color: atmosphereHighlight,
      opacity: 0.14,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.62, size.height * 0.28),
      width: size.width * 1.02,
      height: size.height * 0.14,
      rotation: -0.24 + 0.01 * math.cos(t * 0.18),
      color: accentPrimary,
      opacity: 0.038,
    );
    _paintVeil(
      canvas,
      center: Offset(size.width * 0.42, size.height * 0.76),
      width: size.width * 0.88,
      height: size.height * 0.1,
      rotation: 0.05,
      color: mistTint,
      opacity: 0.024,
    );
  }

  void _paintEtherealOverlay(
    Canvas canvas,
    Size size,
    Rect rect,
    double t,
    double motion,
  ) {
    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.24 + 0.018 * math.sin(t * 0.2 + seed * 0.18) * motion),
        size.height * 0.2,
      ),
      width: size.width * 0.74,
      height: size.height * 0.44,
      color: accentSecondary,
      opacity: 0.12,
    );
    _paintOrb(
      canvas,
      center: Offset(
        size.width * 0.78,
        size.height * (0.58 + 0.014 * math.cos(t * 0.18 + seed * 0.22)),
      ),
      width: size.width * 0.58,
      height: size.height * 0.34,
      color: atmosphereHighlight,
      opacity: 0.14,
    );
    _paintOrb(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.82),
      width: size.width * 0.92,
      height: size.height * 0.28,
      color: mistTint,
      opacity: 0.04,
    );
    _paintVeil(
      canvas,
      center: Offset(
        size.width * 0.46,
        size.height * (0.3 + 0.016 * math.sin(t * 0.16 + seed * 0.08)),
      ),
      width: size.width * 1.14,
      height: size.height * 0.12,
      rotation: -0.3,
      color: accentSecondary,
      opacity: 0.034,
    );
    _paintVeil(
      canvas,
      center: Offset(
        size.width * 0.6,
        size.height * (0.62 + 0.014 * math.cos(t * 0.18 + seed * 0.12)),
      ),
      width: size.width * 1.06,
      height: size.height * 0.11,
      rotation: 0.24,
      color: atmosphereHighlight,
      opacity: 0.032,
    );
  }

  @override
  bool shouldRepaint(covariant _CinematicBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.motionScale != motionScale ||
        oldDelegate.mood != mood ||
        oldDelegate.background != background ||
        oldDelegate.atmosphereTop != atmosphereTop ||
        oldDelegate.atmosphereBottom != atmosphereBottom ||
        oldDelegate.atmosphereHighlight != atmosphereHighlight ||
        oldDelegate.accentPrimary != accentPrimary ||
        oldDelegate.accentSecondary != accentSecondary ||
        oldDelegate.mistTint != mistTint;
  }
}
