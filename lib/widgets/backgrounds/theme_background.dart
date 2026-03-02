import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ThemePointerPhase { down, move, up }

@immutable
class ThemeTouchEvent {
  const ThemeTouchEvent({required this.globalPosition, required this.phase});

  final Offset globalPosition;
  final ThemePointerPhase phase;
}

@immutable
class BackgroundInteraction {
  const BackgroundInteraction({
    required this.phase,
    required this.localPosition,
    required this.normalizedPosition,
    required this.elapsedSeconds,
  });

  final ThemePointerPhase phase;
  final Offset localPosition;
  final Offset normalizedPosition;
  final double elapsedSeconds;
}

/// Global pointer bus for subtle environment reactions and parallax focus.
class ThemeTouchBus {
  ThemeTouchBus._();

  static final StreamController<ThemeTouchEvent> _bus =
      StreamController<ThemeTouchEvent>.broadcast();

  static Stream<ThemeTouchEvent> get eventStream => _bus.stream;

  /// Backward compatibility stream (down events only).
  static Stream<Offset> get stream => _bus.stream
      .where((event) => event.phase == ThemePointerPhase.down)
      .map((event) => event.globalPosition);

  /// Backward compatibility alias.
  static void emit(Offset globalPosition) {
    emitDown(globalPosition);
  }

  static void emitDown(Offset globalPosition) {
    if (_bus.isClosed) return;
    _bus.add(
      ThemeTouchEvent(
        globalPosition: globalPosition,
        phase: ThemePointerPhase.down,
      ),
    );
  }

  static void emitMove(Offset globalPosition) {
    if (_bus.isClosed) return;
    _bus.add(
      ThemeTouchEvent(
        globalPosition: globalPosition,
        phase: ThemePointerPhase.move,
      ),
    );
  }

  static void emitUp(Offset globalPosition) {
    if (_bus.isClosed) return;
    _bus.add(
      ThemeTouchEvent(
        globalPosition: globalPosition,
        phase: ThemePointerPhase.up,
      ),
    );
  }
}

/// Base widget used by premium interactive theme backgrounds.
abstract class InteractiveBackground extends StatefulWidget {
  const InteractiveBackground({
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
abstract class InteractiveBackgroundState<T extends InteractiveBackground>
    extends State<T>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController controller;
  late final math.Random random;

  Duration get animationDuration;
  Size get sceneSize => _sceneSize;
  Alignment get parallaxAlignment => _parallax;

  Offset get parallaxOffsetPixels => Offset(
    _parallax.x * _sceneSize.width * 0.045,
    _parallax.y * _sceneSize.height * 0.03,
  );

  Size _sceneSize = Size.zero;
  double _lastSeconds = 0;
  double _lastPointerSeconds = 0;
  bool _activeLifecycle = true;
  StreamSubscription<ThemeTouchEvent>? _touchSubscription;
  Alignment _parallax = Alignment.center;
  Alignment _parallaxTarget = Alignment.center;

  /// Override for one-time scene setup.
  @protected
  void initializeScene() {}

  /// Override for frame-to-frame updates.
  @protected
  void onFrame(double elapsedSeconds, double deltaSeconds) {}

  /// Override for per-theme touch reactions.
  @protected
  void onSceneTap(Offset localPosition) {}

  /// Override for richer touch phases and normalized interaction.
  @protected
  void onScenePointer(BackgroundInteraction interaction) {}

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
    _touchSubscription = ThemeTouchBus.eventStream.listen(_handleGlobalTouch);
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

    // Parallax settles to center if pointer has been idle for a short window.
    if (elapsed - _lastPointerSeconds > 0.45) {
      _parallaxTarget =
          Alignment.lerp(
            _parallaxTarget,
            Alignment.center,
            (delta * 4.2).clamp(0.0, 1.0),
          ) ??
          Alignment.center;
    }

    final smoothing = (delta * 10.0).clamp(0.0, 1.0).toDouble();
    _parallax = Alignment(
      _parallax.x + (_parallaxTarget.x - _parallax.x) * smoothing,
      _parallax.y + (_parallaxTarget.y - _parallax.y) * smoothing,
    );

    onFrame(elapsed, delta);
  }

  void _handleGlobalTouch(ThemeTouchEvent event) {
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    if (_sceneSize.width <= 0 || _sceneSize.height <= 0) return;

    if (event.phase == ThemePointerPhase.up) {
      _lastPointerSeconds = _lastSeconds;
      _parallaxTarget =
          Alignment.lerp(_parallaxTarget, Alignment.center, 0.78) ??
          Alignment.center;
      return;
    }

    final local = render.globalToLocal(event.globalPosition);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > render.size.width ||
        local.dy > render.size.height) {
      return;
    }

    final nx = (local.dx / _sceneSize.width).clamp(0.0, 1.0).toDouble();
    final ny = (local.dy / _sceneSize.height).clamp(0.0, 1.0).toDouble();
    final ax = (nx * 2 - 1) * 0.16;
    final ay = (ny * 2 - 1) * 0.14;
    _parallaxTarget = Alignment(
      ax.clamp(-0.16, 0.16).toDouble(),
      ay.clamp(-0.14, 0.14).toDouble(),
    );
    _lastPointerSeconds = _lastSeconds;

    final interaction = BackgroundInteraction(
      phase: event.phase,
      localPosition: local,
      normalizedPosition: Offset(nx, ny),
      elapsedSeconds: _lastSeconds,
    );
    onScenePointer(interaction);
    if (event.phase == ThemePointerPhase.down) {
      onSceneTap(local);
    }
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

/// Backward-compatible aliases for existing theme files.
abstract class ThemeBackground extends InteractiveBackground {
  const ThemeBackground({
    super.key,
    required super.seed,
    required super.motionScale,
  });
}

abstract class ThemeBackgroundState<T extends ThemeBackground>
    extends InteractiveBackgroundState<T> {}
