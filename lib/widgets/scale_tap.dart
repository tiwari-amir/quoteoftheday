import 'package:flutter/material.dart';

class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.95,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? widget.pressedScale : (_hovered ? 1.01 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
