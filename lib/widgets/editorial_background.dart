import 'package:flutter/material.dart';

import 'app_background.dart';

class EditorialBackground extends StatelessWidget {
  const EditorialBackground({
    super.key,
    this.seed = 77,
    this.motionScale = 1.0,
  });

  final int seed;
  final double motionScale;

  @override
  Widget build(BuildContext context) {
    return AppBackground(seed: seed, motionScale: motionScale);
  }
}
