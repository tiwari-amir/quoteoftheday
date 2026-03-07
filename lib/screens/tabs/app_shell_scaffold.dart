import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';

class AppShellScaffold extends StatefulWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  DateTime? _lastBackPressedAt;

  bool get _supportsSystemExit {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  void _handleBackPress() {
    // First back from Explore/Library returns to Today.
    if (widget.navigationShell.currentIndex != 0) {
      _lastBackPressedAt = null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      widget.navigationShell.goBranch(0, initialLocation: false);
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final selectedIndex = switch (widget.navigationShell.currentIndex) {
      0 => 0,
      1 => 2,
      2 => 3,
      _ => 0,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_supportsSystemExit) return;
        _handleBackPress();
      },
      child: Scaffold(
        body: widget.navigationShell,
        extendBody: true,
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            FlowSpace.md,
            0,
            FlowSpace.md,
            FlowSpace.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: FlowRadii.radiusXl,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (colors?.surface ?? Colors.black).withValues(alpha: 0.94),
                  (colors?.elevatedSurface ?? Colors.black).withValues(
                    alpha: 0.88,
                  ),
                ],
              ),
              border: Border.all(
                color: (colors?.divider ?? Colors.white24).withValues(
                  alpha: 0.85,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 34,
                  offset: const Offset(0, 16),
                ),
                ...?flow?.shadows.level2,
              ],
            ),
            child: ClipRRect(
              borderRadius: FlowRadii.radiusXl,
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                currentIndex: selectedIndex,
                onTap: (index) {
                  if (index == 1) {
                    context.push('/viewer/category/all');
                    return;
                  }

                  final branchIndex = switch (index) {
                    0 => 0,
                    2 => 1,
                    3 => 2,
                    _ => 0,
                  };
                  widget.navigationShell.goBranch(
                    branchIndex,
                    initialLocation:
                        branchIndex == widget.navigationShell.currentIndex,
                  );
                },
                selectedFontSize: 11,
                unselectedFontSize: 11,
                selectedLabelStyle: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.18,
                    ),
                unselectedLabelStyle: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.14,
                    ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.today_outlined),
                    activeIcon: Icon(Icons.today_rounded),
                    label: 'Today',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.auto_stories_outlined),
                    activeIcon: Icon(Icons.auto_stories_rounded),
                    label: 'Scroll',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore_rounded),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.collections_bookmark_outlined),
                    activeIcon: Icon(Icons.collections_bookmark_rounded),
                    label: 'Library',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
