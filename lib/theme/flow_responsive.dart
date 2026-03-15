import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class FlowLayoutInfo {
  const FlowLayoutInfo._({
    required this.size,
    required this.viewPadding,
    required this.viewInsets,
  });

  factory FlowLayoutInfo.of(BuildContext context) {
    final media = MediaQuery.of(context);
    return FlowLayoutInfo._(
      size: media.size,
      viewPadding: media.viewPadding,
      viewInsets: media.viewInsets,
    );
  }

  final Size size;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;

  bool get isNarrow => size.width < 360;
  bool get isCompactWidth => size.width < 390;
  bool get isCompactHeight => size.height < 760;
  bool get isCompact => isCompactWidth || isCompactHeight;
  bool get isTablet => size.width >= 700;
  bool get isDesktop => size.width >= 1100;

  double get horizontalPadding => switch (size.width) {
    >= 1100 => 36,
    >= 700 => 28,
    < 390 => 16,
    _ => 20,
  };

  double get topPadding => isCompact ? 8 : 12;

  double get maxContentWidth => switch (size.width) {
    >= 1280 => 1040,
    >= 900 => 860,
    >= 700 => 760,
    _ => size.width,
  };

  double get textColumnWidth => switch (size.width) {
    >= 1280 => 760,
    >= 900 => 700,
    >= 700 => 640,
    _ => size.width,
  };

  double get dockHeight => isCompact ? 52 : 56;

  double get dockBottomInset {
    final base = viewInsets.bottom > 0 ? viewInsets.bottom + 4 : 0;
    return base.toDouble();
  }

  double get dockBodyInset =>
      dockHeight +
      math.max(viewPadding.bottom, dockBottomInset) +
      (isCompact ? 6 : 8);

  double get dockMaxWidth => switch (size.width) {
    >= 1100 => 460,
    >= 700 => 420,
    < 360 => size.width - 16,
    _ => math.min(410, size.width - horizontalPadding * 2),
  };

  double fluid({
    required double min,
    required double max,
    double minWidth = 320,
    double maxWidth = 1440,
  }) {
    final t = ((size.width - minWidth) / (maxWidth - minWidth)).clamp(0.0, 1.0);
    return lerpDouble(min, max, t) ?? min;
  }

  int columnsFor(
    double availableWidth, {
    required double minTileWidth,
    int maxColumns = 6,
  }) {
    final safeWidth = availableWidth.isFinite ? availableWidth : size.width;
    final columns = safeWidth ~/ minTileWidth;
    return columns.clamp(1, maxColumns);
  }

  double tileWidthFor(
    double availableWidth, {
    required int columns,
    required double gap,
  }) {
    if (columns <= 1) return availableWidth;
    return (availableWidth - gap * (columns - 1)) / columns;
  }
}
