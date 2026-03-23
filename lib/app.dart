import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/v3_background/background_theme_provider.dart';
import 'features/v3_notifications/in_app_notifications_providers.dart';
import 'features/v3_notifications/notification_providers.dart';
import 'providers/auth_bootstrap_provider.dart';
import 'providers/performance_profile_provider.dart';
import 'providers/quote_providers.dart';
import 'providers/router_provider.dart';
import 'providers/streak_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/splash_screen.dart';

class QuoteOfTheDayApp extends ConsumerStatefulWidget {
  const QuoteOfTheDayApp({super.key});

  @override
  ConsumerState<QuoteOfTheDayApp> createState() => _QuoteOfTheDayAppState();
}

class _QuoteOfTheDayAppState extends ConsumerState<QuoteOfTheDayApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _didStartBootstrap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAppBootstrap();
    _startNotificationBootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    Future<void>(() async {
      try {
        await ref
            .read(notificationSettingsProvider.notifier)
            .refreshForRuntimeStateChange();
        await ref.read(inAppNotificationsBootstrapProvider).syncNow();
      } catch (error) {
        debugPrint('[App] Resume refresh failed: $error');
      }
    });
  }

  void _startAppBootstrap() {
    Future<void>(() async {
      try {
        final performanceProfile = ref.read(appPerformanceProfileProvider);
        ref.read(streakProvider);
        ref.read(inAppNotificationsBootstrapProvider);
        await ref.read(authBootstrapProvider.future);
        await ref
            .read(quoteRepositoryProvider)
            .warmStartupLight(
              quoteLimit: performanceProfile.startupWarmQuoteLimit,
            );
      } catch (error) {
        debugPrint('[App] Startup bootstrap failed: $error');
      }
    });
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
    final performanceProfile = ref.watch(appPerformanceProfileProvider);
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
            if (_showSplash)
              Positioned.fill(
                child: AbsorbPointer(
                  child: SplashScreen(
                    onFinished: _handleSplashFinished,
                    simpleMode: performanceProfile.useLiteRendering,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
