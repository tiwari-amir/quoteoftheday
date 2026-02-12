import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_bootstrap_provider.dart';
import 'providers/router_provider.dart';
import 'theme/app_theme.dart';

class QuoteOfTheDayApp extends ConsumerWidget {
  const QuoteOfTheDayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    ref.watch(authBootstrapProvider);

    return MaterialApp.router(
      title: 'Quote of the Day',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
