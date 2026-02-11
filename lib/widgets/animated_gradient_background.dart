import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

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
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final pulse = 0.1 + (math.sin(t * math.pi * 2) + 1) * 0.05;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 1.2, -1),
              end: Alignment(1, 1 - t * 1.2),
              colors: [
                const Color(0xFF030712),
                Color.lerp(
                  const Color(0xFF0A1022),
                  const Color(0xFF0E1D3A),
                  t,
                )!,
                const Color(0xFF02040D),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -100,
                right: -60,
                child: _GlowBlob(
                  size: 260,
                  color: Colors.cyanAccent.withValues(alpha: 0.15 + pulse),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -70,
                child: _GlowBlob(
                  size: 320,
                  color: Colors.indigoAccent.withValues(alpha: 0.13 + pulse),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
