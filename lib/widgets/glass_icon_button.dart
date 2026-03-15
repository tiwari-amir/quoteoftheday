import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'scale_tap.dart';

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>();
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final fill = tokens?.glassFill ?? Colors.white.withValues(alpha: 0.1);
    final border = tokens?.glassBorder ?? Colors.white.withValues(alpha: 0.15);
    final icon = iconColor ?? Theme.of(context).colorScheme.onSurface;
    final accent = colors?.accent ?? Colors.white;

    return ScaleTap(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (colors?.elevatedSurface ?? fill).withValues(alpha: 0.94),
                  (colors?.surface ?? fill).withValues(alpha: 0.84),
                ],
              ),
              border: Border.all(
                color: border.withValues(alpha: 0.82),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(this.icon, size: 20, color: icon),
          ),
        ),
      ),
    );
  }
}
