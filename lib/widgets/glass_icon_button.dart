import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
    final fill = tokens?.glassFill ?? Colors.white.withValues(alpha: 0.1);
    final border = tokens?.glassBorder ?? Colors.white.withValues(alpha: 0.15);
    final icon = iconColor ?? Theme.of(context).colorScheme.onSurface;

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
              color: fill,
              border: Border.all(color: border, width: 1),
            ),
            child: Icon(this.icon, size: 20, color: icon),
          ),
        ),
      ),
    );
  }
}
