import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/v3_audio/ambient_audio_controller.dart';
import 'features/v3_background/background_theme_provider.dart';
import 'features/v3_notifications/notification_providers.dart';
import 'providers/auth_bootstrap_provider.dart';
import 'providers/router_provider.dart';
import 'providers/streak_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_gradient_background.dart';
import 'widgets/splash_screen.dart';

class QuoteOfTheDayApp extends ConsumerStatefulWidget {
  const QuoteOfTheDayApp({super.key});

  @override
  ConsumerState<QuoteOfTheDayApp> createState() => _QuoteOfTheDayAppState();
}

class _QuoteOfTheDayAppState extends ConsumerState<QuoteOfTheDayApp> {
  bool _showSplash = true;
  bool _didStartBootstrap = false;

  @override
  void initState() {
    super.initState();
    _startNotificationBootstrap();
  }

  void _startNotificationBootstrap() {
    if (_didStartBootstrap) return;
    _didStartBootstrap = true;
    Future<void>(() async {
      try {
        await ref
            .read(notificationSettingsProvider.notifier)
            .rescheduleFromStartup();
      } catch (error) {
        debugPrint('[Notifications] Startup bootstrap failed: $error');
      }
    });
  }

  void _handleSplashFinished() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final backgroundTheme = ref.watch(appBackgroundThemeProvider);
    ref.watch(ambientAudioProvider);
    ref.listen<AppBackgroundTheme>(appBackgroundThemeProvider, (
      previous,
      next,
    ) {
      ref.read(ambientAudioProvider.notifier).applyTheme(next);
    });
    ref.watch(authBootstrapProvider);
    ref.watch(streakProvider);
    ref.listen(notificationTapProvider, (previous, next) {
      final route = next.valueOrNull;
      if (route == null || route.isEmpty) return;
      router.push(route);
    });

    return MaterialApp.router(
      title: 'QuoteFlow: Daily Scroll Quotes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkThemeFor(backgroundTheme),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  AnimatedGradientBackground.emitGlobalPointerDown(
                    event.position,
                  );
                  unawaited(
                    ref.read(ambientAudioProvider.notifier).onUserInteraction(),
                  );
                },
                onPointerMove: (event) {
                  AnimatedGradientBackground.emitGlobalPointerMove(
                    event.position,
                  );
                },
                onPointerHover: (event) {
                  AnimatedGradientBackground.emitGlobalPointerMove(
                    event.position,
                  );
                },
                onPointerUp: (event) {
                  AnimatedGradientBackground.emitGlobalPointerUp(
                    event.position,
                  );
                },
                onPointerCancel: (event) {
                  AnimatedGradientBackground.emitGlobalPointerUp(
                    event.position,
                  );
                },
                child: const SizedBox.expand(),
              ),
            ),
            if (_showSplash)
              Positioned.fill(
                child: AbsorbPointer(
                  child: SplashScreen(onFinished: _handleSplashFinished),
                ),
              ),
          ],
        );
      },
    );
  }
}
