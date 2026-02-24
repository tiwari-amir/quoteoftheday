import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Global pointer bus for subtle environment reactions.
class ThemeTouchBus {
  ThemeTouchBus._();

  static final StreamController<Offset> _bus =
      StreamController<Offset>.broadcast();

  static Stream<Offset> get stream => _bus.stream;

  static void emit(Offset globalPosition) {
    if (_bus.isClosed) return;
    _bus.add(globalPosition);
  }
}

/// Base widget used by all cinematic theme backgrounds.
abstract class ThemeBackground extends StatefulWidget {
  const ThemeBackground({
    super.key,
    required this.seed,
    required this.motionScale,
  });

  final int seed;
  final double motionScale;
}

/// Unified animation strategy:
/// - One controller per theme
/// - Frame callbacks mutate lightweight model data only
/// - Repaint driven by [repaint] on CustomPainter (no rebuild loop)
/// - Auto pause/resume with app lifecycle + TickerMode
abstract class ThemeBackgroundState<T extends ThemeBackground> extends State<T>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController controller;
  late final math.Random random;

  Duration get animationDuration;
  Size get sceneSize => _sceneSize;

  Size _sceneSize = Size.zero;
  double _lastSeconds = 0;
  bool _activeLifecycle = true;
  StreamSubscription<Offset>? _touchSubscription;

  /// Override for one-time scene setup.
  @protected
  void initializeScene() {}

  /// Override for frame-to-frame updates.
  @protected
  void onFrame(double elapsedSeconds, double deltaSeconds) {}

  /// Override for per-theme touch reactions.
  @protected
  void onSceneTap(Offset localPosition) {}

  /// Return the theme scene.
  @protected
  Widget buildScene(BuildContext context, Animation<double> repaint);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    random = math.Random(widget.seed ^ runtimeType.hashCode);
    initializeScene();
    controller = AnimationController(vsync: this, duration: animationDuration)
      ..addListener(_handleFrame)
      ..repeat();
    _touchSubscription = ThemeTouchBus.stream.listen(_handleGlobalTouch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTickerState();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTickerState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activeLifecycle = state == AppLifecycleState.resumed;
    _syncTickerState();
  }

  void _syncTickerState() {
    final canAnimate = _activeLifecycle && TickerMode.of(context);
    if (canAnimate) {
      if (!controller.isAnimating) {
        controller.repeat();
      }
    } else {
      if (controller.isAnimating) {
        controller.stop();
      }
    }
  }

  void _handleFrame() {
    final micros = controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final elapsed = micros / 1000000.0;
    var delta = elapsed - _lastSeconds;
    _lastSeconds = elapsed;
    if (delta <= 0 || delta > 0.1) {
      delta = 1 / 60;
    }
    onFrame(elapsed, delta);
  }

  void _handleGlobalTouch(Offset globalPosition) {
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final local = render.globalToLocal(globalPosition);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > render.size.width ||
        local.dy > render.size.height) {
      return;
    }
    onSceneTap(local);
  }

  @override
  void dispose() {
    _touchSubscription?.cancel();
    controller
      ..removeListener(_handleFrame)
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sceneSize = Size(constraints.maxWidth, constraints.maxHeight);
        return RepaintBoundary(child: buildScene(context, controller));
      },
    );
  }
}
