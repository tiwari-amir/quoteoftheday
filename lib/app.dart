import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/v3_background/background_theme_provider.dart';
import 'features/v3_notifications/notification_providers.dart';
import 'providers/auth_bootstrap_provider.dart';
import 'providers/router_provider.dart';
import 'providers/streak_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_gradient_background.dart';

class QuoteOfTheDayApp extends ConsumerWidget {
  const QuoteOfTheDayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final backgroundTheme = ref.watch(appBackgroundThemeProvider);
    ref.watch(authBootstrapProvider);
    ref.watch(streakProvider);
    ref.watch(notificationSettingsProvider);
    ref.listen(notificationTapProvider, (previous, next) {
      final route = next.valueOrNull;
      if (route == null || route.isEmpty) return;
      router.push(route);
    });

    return MaterialApp.router(
      title: 'Quote of the Day',
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
                  AnimatedGradientBackground.emitGlobalRipple(event.position);
                },
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
