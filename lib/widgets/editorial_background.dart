import 'package:flutter/material.dart';

import 'animated_gradient_background.dart';

class EditorialBackground extends StatelessWidget {
  const EditorialBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnimatedGradientBackground(seed: 77);
  }
}
