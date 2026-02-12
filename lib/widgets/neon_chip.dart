import 'package:flutter/material.dart';

import 'scale_tap.dart';

class NeonChip extends StatelessWidget {
  const NeonChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected
            ? const Color(0xFF42C8FF).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: selected
              ? const Color(0xFF42C8FF).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.15),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF42C8FF).withValues(alpha: 0.32),
                  blurRadius: 18,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: selected ? 0.98 : 0.78),
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return chip;
    return ScaleTap(onTap: onTap!, child: chip);
  }
}
