import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  // Phase 1: quick visual anchor so the screen does not feel blank.
  late final Animation<double> _backgroundFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.16, curve: Curves.easeOutCubic),
  );

  // Phase 1 -> 2: icon settles in, then drifts up slightly.
  late final Animation<double> _iconScale = Tween<double>(begin: 0.95, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.2, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _iconFloatY =
      Tween<double>(begin: 2.0, end: -2.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.18, 0.6, curve: Curves.easeInOutSine),
        ),
      );

  // Phase 2: soft bloom behind the icon.
  late final Animation<double> _bloom = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.62, curve: Curves.easeOutSine),
  );

  // Phase 3: title/subtitle and particles come in after the icon settles.
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.58, 0.86, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _particleFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.64, 0.95, curve: Curves.easeOutCubic),
  );

  // Exit: full overlay fades away into the already initialized first screen.
  late final Animation<double> _exitFade = Tween<double>(begin: 1.0, end: 0.0)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.88, 1.0, curve: Curves.easeOutCubic),
        ),
      );

  bool _didFinish = false;
  Timer? _fallbackTimer;

  void _finishIfNeeded() {
    if (_didFinish) return;
    _didFinish = true;
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _finishIfNeeded();
    });
    // Failsafe for edge cases where ticker callbacks do not complete on-device.
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), _finishIfNeeded);
    _controller.forward();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final compositeOpacity = (_backgroundFade.value * _exitFade.value)
              .clamp(0.0, 1.0);
          final textLift = (1 - _textFade.value) * 8;

          return Opacity(
            opacity: compositeOpacity,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF0E0C1A),
                    Color(0xFF19162A),
                    Color(0xFF3A273A),
                    Color(0xFF724942),
                  ],
                  stops: <double>[0.0, 0.35, 0.74, 1.0],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: -84,
                    top: -70,
                    child: IgnorePointer(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFFD4AB,
                          ).withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -90,
                    bottom: -76,
                    child: IgnorePointer(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFEEA175,
                          ).withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.1),
                          radius: 1.0,
                          colors: <Color>[
                            const Color(0xFFF6BB86).withValues(alpha: 0.12),
                            const Color(0xFFFFDAB8).withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                          stops: const <double>[0.0, 0.36, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.16),
                          ],
                          stops: const <double>[0.56, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.3),
                    child: Opacity(
                      opacity: _bloom.value * 0.16,
                      child: Container(
                        width: 410,
                        height: 148,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: <Color>[
                              const Color(0xFFFFCF9E).withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: _particleFade.value,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _ParticleFieldPainter(
                            progress: _controller.value,
                            opacity: _particleFade.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Transform.translate(
                            offset: Offset(0, _iconFloatY.value),
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                Opacity(
                                  opacity: _bloom.value * 0.24,
                                  child: Container(
                                    width: 192,
                                    height: 192,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFFFFD8B2,
                                        ).withValues(alpha: 0.28),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                Opacity(
                                  opacity: _bloom.value * 0.15,
                                  child: Container(
                                    width: 228,
                                    height: 228,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          Color(0xFFF5AE72),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                ScaleTransition(
                                  scale: _iconScale,
                                  child: Container(
                                    width: 124,
                                    height: 124,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.24,
                                        ),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          const Color(
                                            0xFF3A2A3B,
                                          ).withValues(alpha: 0.52),
                                          const Color(
                                            0xFF1C162A,
                                          ).withValues(alpha: 0.38),
                                        ],
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.36,
                                          ),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                        BoxShadow(
                                          color: const Color(
                                            0xFFF5AE72,
                                          ).withValues(alpha: 0.1),
                                          blurRadius: 22,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(34),
                                      child: Image.asset(
                                        'assets/branding/app_icon.png',
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                        errorBuilder: (context, error, stack) {
                                          return Container(
                                            color: const Color(0xFF1A1325),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.format_quote_rounded,
                                              size: 54,
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 34),
                          Transform.translate(
                            offset: Offset(0, textLift),
                            child: FadeTransition(
                              opacity: _textFade,
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    'QuoteFlow',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 45,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.96,
                                      ),
                                      letterSpacing: 0.32,
                                      height: 1.02,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Scroll daily quotes.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13.6,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: 0.74,
                                      ),
                                      letterSpacing: 0.32,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParticleFieldPainter extends CustomPainter {
  _ParticleFieldPainter({required this.progress, required this.opacity});

  final double progress;
  final double opacity;

  static const List<_ParticleSeed> _seeds = <_ParticleSeed>[
    _ParticleSeed(x: 0.08, y: 0.22, radius: 1.2, alpha: 0.18, phase: 0.2),
    _ParticleSeed(x: 0.17, y: 0.72, radius: 1.4, alpha: 0.14, phase: 1.0),
    _ParticleSeed(x: 0.24, y: 0.36, radius: 1.0, alpha: 0.16, phase: 2.0),
    _ParticleSeed(x: 0.31, y: 0.54, radius: 1.5, alpha: 0.12, phase: 2.9),
    _ParticleSeed(x: 0.41, y: 0.2, radius: 1.3, alpha: 0.13, phase: 3.6),
    _ParticleSeed(x: 0.52, y: 0.42, radius: 1.1, alpha: 0.16, phase: 4.1),
    _ParticleSeed(x: 0.63, y: 0.76, radius: 1.6, alpha: 0.12, phase: 4.7),
    _ParticleSeed(x: 0.73, y: 0.28, radius: 1.2, alpha: 0.15, phase: 5.5),
    _ParticleSeed(x: 0.84, y: 0.61, radius: 1.0, alpha: 0.16, phase: 6.1),
    _ParticleSeed(x: 0.92, y: 0.32, radius: 1.3, alpha: 0.11, phase: 0.8),
    _ParticleSeed(x: 0.12, y: 0.48, radius: 1.1, alpha: 0.14, phase: 1.7),
    _ParticleSeed(x: 0.29, y: 0.82, radius: 1.2, alpha: 0.12, phase: 2.6),
    _ParticleSeed(x: 0.47, y: 0.67, radius: 1.0, alpha: 0.14, phase: 3.3),
    _ParticleSeed(x: 0.58, y: 0.15, radius: 1.4, alpha: 0.11, phase: 4.4),
    _ParticleSeed(x: 0.69, y: 0.52, radius: 1.1, alpha: 0.13, phase: 5.1),
    _ParticleSeed(x: 0.79, y: 0.84, radius: 1.3, alpha: 0.1, phase: 5.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;

    final gentleDrift = progress * math.pi * 2;
    for (final seed in _seeds) {
      final dx =
          (seed.x * size.width) + (math.sin(gentleDrift + seed.phase) * 5.0);
      final dy =
          (seed.y * size.height) +
          (math.cos((gentleDrift * 0.55) + seed.phase) * 4.0);

      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: (seed.alpha * opacity).clamp(0.0, 1.0),
        );
      canvas.drawCircle(Offset(dx, dy), seed.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

class _ParticleSeed {
  const _ParticleSeed({
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
