import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animated_gradient_background.dart';

class QuoteFlowGlowBackground extends StatefulWidget {
  const QuoteFlowGlowBackground({
    super.key,
    this.seed = 0,
    this.motionScale = 1.0,
  });

  final int seed;
  final double motionScale;

  @override
  State<QuoteFlowGlowBackground> createState() =>
      _QuoteFlowGlowBackgroundState();
}

class _QuoteFlowGlowBackgroundState extends State<QuoteFlowGlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_GlowOrb> _orbs;
  final List<_TouchBloom> _blooms = <_TouchBloom>[];
  StreamSubscription<Offset>? _touchSub;

  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _random = math.Random(9043 + widget.seed);
    _orbs = List<_GlowOrb>.generate(24, (index) {
      return _GlowOrb(
        pos: Offset(_random.nextDouble(), _random.nextDouble()),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.015,
          (_random.nextDouble() - 0.5) * 0.015,
        ),
        radius: 26 + _random.nextDouble() * 68,
        hueShift: _random.nextDouble(),
        phase: _random.nextDouble() * math.pi * 2,
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_tick)
          ..repeat();
    _touchSub = AnimatedGradientBackground.globalRippleStream.listen(
      _onGlobalTouch,
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    _touchSub?.cancel();
    super.dispose();
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
    _onLocalTouch(local);
  }

  void _onLocalTouch(Offset local) {
    final now = (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
    _blooms.add(
      _TouchBloom(
        center: local,
        startSeconds: now,
        life: 1.9,
        strength: 0.9 + _random.nextDouble() * 0.45,
      ),
    );
  }

  void _tick() {
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final now = micros / 1000000.0;
    var dt = now - _lastT;
    _lastT = now;
    if (dt <= 0 || dt > 0.08) dt = 0.016;

    for (final orb in _orbs) {
      orb.pos += orb.velocity * dt * (0.42 + widget.motionScale * 0.35);
      var x = orb.pos.dx;
      var y = orb.pos.dy;
      if (x < -0.08) x = 1.08;
      if (x > 1.08) x = -0.08;
      if (y < -0.08) y = 1.08;
      if (y > 1.08) y = -0.08;
      orb.pos = Offset(x, y);
    }

    _blooms.removeWhere((bloom) => now - bloom.startSeconds > bloom.life);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final t =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
        return CustomPaint(
          painter: _QuoteFlowGlowPainter(
            orbs: _orbs,
            blooms: _blooms,
            timeSeconds: t,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _QuoteFlowGlowPainter extends CustomPainter {
  const _QuoteFlowGlowPainter({
    required this.orbs,
    required this.blooms,
    required this.timeSeconds,
  });

  final List<_GlowOrb> orbs;
  final List<_TouchBloom> blooms;
  final double timeSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE7CC), Color(0xFFFFAF90), Color(0xFF9959AA)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    final sunrise = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.05, 0.12),
        radius: 0.78,
        colors: [
          const Color(0xFFFFF5B8).withValues(alpha: 0.58),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sunrise);

    _paintWaveBand(
      canvas,
      size,
      yNorm: 0.63 + math.sin(timeSeconds * 0.08) * 0.015,
      amp: 34,
      color: const Color(0xFFFF8FA4).withValues(alpha: 0.5),
      phase: 0.0,
    );
    _paintWaveBand(
      canvas,
      size,
      yNorm: 0.72 + math.sin(timeSeconds * 0.06 + 1.2) * 0.017,
      amp: 42,
      color: const Color(0xFFD078B8).withValues(alpha: 0.42),
      phase: 1.1,
    );
    _paintWaveBand(
      canvas,
      size,
      yNorm: 0.8 + math.sin(timeSeconds * 0.04 + 2.5) * 0.02,
      amp: 36,
      color: const Color(0xFFA25CB4).withValues(alpha: 0.48),
      phase: 2.1,
    );

    for (final orb in orbs) {
      final center = Offset(orb.pos.dx * size.width, orb.pos.dy * size.height);
      final pulse = 0.75 + 0.25 * math.sin(timeSeconds * 1.8 + orb.phase);
      final radius = orb.radius * pulse;
      final color = Color.lerp(
        const Color(0xFFFFEAB2),
        const Color(0xFFF479AD),
        orb.hueShift,
      )!;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.17),
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    for (final bloom in blooms) {
      final age = (timeSeconds - bloom.startSeconds).clamp(0.0, bloom.life);
      final alpha = (1 - age / bloom.life).clamp(0.0, 1.0);
      final radius = 26 + age * 180 * bloom.strength;
      final halo = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFF8CA).withValues(alpha: alpha * 0.28),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: bloom.center, radius: radius + 18),
            );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + bloom.strength
        ..color = const Color(0xFFFFF3BD).withValues(alpha: alpha * 0.48);
      canvas.drawCircle(bloom.center, radius + 18, halo);
      canvas.drawCircle(bloom.center, radius, ring);
    }

    final glaze = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x1AFFFFFF), Color(0x33000000)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  void _paintWaveBand(
    Canvas canvas,
    Size size, {
    required double yNorm,
    required double amp,
    required Color color,
    required double phase,
  }) {
    final path = Path();
    final yBase = size.height * yNorm;
    path.moveTo(0, yBase);
    final steps = 5;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = size.width * t;
      final y =
          yBase + math.sin((t * math.pi * 2) + phase + timeSeconds * 0.3) * amp;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QuoteFlowGlowPainter oldDelegate) => true;
}

class _GlowOrb {
  _GlowOrb({
    required this.pos,
    required this.velocity,
    required this.radius,
    required this.hueShift,
    required this.phase,
  });

  Offset pos;
  final Offset velocity;
  final double radius;
  final double hueShift;
  final double phase;
}

class _TouchBloom {
  const _TouchBloom({
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
