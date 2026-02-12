import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key, this.seed = 0});

  final int seed;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seedShift = (widget.seed % 360) / 360;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final drift = math.sin((t + seedShift) * math.pi * 2) * 0.22;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + drift, -1),
                  end: Alignment(1, 1 - drift),
                  colors: const [
                    Color(0xFF090B10),
                    Color(0xFF121523),
                    Color(0xFF0B111C),
                  ],
                ),
              ),
            ),
            _MeshBlob(
              alignment: Alignment(-0.75 + (t * 0.22), -0.55),
              color: const Color(0xFF5F66FF).withValues(alpha: 0.22),
              radius: 240,
            ),
            _MeshBlob(
              alignment: Alignment(0.9 - (t * 0.2), 0.65),
              color: const Color(0xFF19D4D4).withValues(alpha: 0.16),
              radius: 260,
            ),
            _MeshBlob(
              alignment: Alignment(-0.2 + (drift * 0.7), 0.95 - (t * 0.08)),
              color: const Color(0xFF7B4DFF).withValues(alpha: 0.12),
              radius: 220,
            ),
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.015),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MeshBlob extends StatelessWidget {
  const _MeshBlob({
    required this.alignment,
    required this.color,
    required this.radius,
  });

  final Alignment alignment;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: radius,
          height: radius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, Colors.transparent],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}
