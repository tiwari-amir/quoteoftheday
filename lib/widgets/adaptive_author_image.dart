import 'dart:math' as math;

import 'package:flutter/material.dart';

class AdaptiveAuthorImage extends StatelessWidget {
  const AdaptiveAuthorImage({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.error,
  });

  final String imageUrl;
  final Widget placeholder;
  final Widget? error;

  static const Alignment _portraitAlignment = Alignment(0, -0.14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.maybeOf(context);
        final devicePixelRatio = media?.devicePixelRatio ?? 1.0;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;
        final cacheWidth = _cacheDimension(
          logicalPixels: maxWidth,
          devicePixelRatio: devicePixelRatio,
        );
        final cacheHeight = _cacheDimension(
          logicalPixels: maxHeight,
          devicePixelRatio: devicePixelRatio,
        );

        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          alignment: _portraitAlignment,
          filterQuality: FilterQuality.low,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return placeholder;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return placeholder;
          },
          errorBuilder: (context, error, stackTrace) {
            return this.error ?? placeholder;
          },
        );
      },
    );
  }

  int? _cacheDimension({
    required double? logicalPixels,
    required double devicePixelRatio,
  }) {
    if (logicalPixels == null || logicalPixels <= 0) {
      return null;
    }
    final physicalPixels = (logicalPixels * devicePixelRatio).round();
    return math.max(48, math.min(physicalPixels, 640));
  }
}
