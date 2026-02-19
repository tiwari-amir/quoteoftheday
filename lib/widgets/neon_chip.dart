import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppThemeTokens>();
    final base = tokens?.chipBase ?? Colors.white.withValues(alpha: 0.08);
    final selectedFill =
        tokens?.chipSelected ?? scheme.primary.withValues(alpha: 0.2);
    final borderBase =
        tokens?.glassBorder ?? Colors.white.withValues(alpha: 0.15);
    final borderSelected =
        tokens?.chipBorder ?? scheme.primary.withValues(alpha: 0.6);
    final glow = tokens?.chipGlow ?? scheme.primary.withValues(alpha: 0.32);

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? selectedFill : base,
        border: Border.all(color: selected ? borderSelected : borderBase),
        boxShadow: selected
            ? [BoxShadow(color: glow, blurRadius: 18, spreadRadius: 0.5)]
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
