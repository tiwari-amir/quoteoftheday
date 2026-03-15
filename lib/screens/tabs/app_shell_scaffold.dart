import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/scale_tap.dart';

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

  void _goToBranch(int branchIndex) {
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  void _openScrollViewer() {
    HapticFeedback.lightImpact();
    context.push('/viewer/category/all');
  }

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final layout = FlowLayoutInfo.of(context);

    final selectedIndex = switch (widget.navigationShell.currentIndex) {
      0 => 0,
      1 => 2,
      2 => 3,
      _ => 0,
    };

    final items = <_DockItemData>[
      _DockItemData(
        id: 'home',
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        selected: selectedIndex == 0,
        onTap: () => _goToBranch(0),
      ),
      _DockItemData(
        id: 'scroll',
        label: 'Scroll',
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
        selected: false,
        onTap: _openScrollViewer,
        prominent: true,
      ),
      _DockItemData(
        id: 'explore',
        label: 'Explore',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        selected: selectedIndex == 2,
        onTap: () => _goToBranch(1),
      ),
      _DockItemData(
        id: 'library',
        label: 'Library',
        icon: Icons.bookmark_outline_rounded,
        activeIcon: Icons.bookmark_rounded,
        selected: selectedIndex == 3,
        onTap: () => _goToBranch(2),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_supportsSystemExit) return;
        _handleBackPress();
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: layout.dockBodyInset),
                child: widget.navigationShell,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: flow?.glass.blurSigma ?? 26,
                    sigmaY: flow?.glass.blurSigma ?? 26,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (colors?.background ?? Colors.black).withValues(
                            alpha: 0.0,
                          ),
                          (colors?.elevatedSurface ?? Colors.black).withValues(
                            alpha: 0.86,
                          ),
                          (colors?.background ?? Colors.black).withValues(
                            alpha: 0.98,
                          ),
                        ],
                        stops: const [0.0, 0.18, 1.0],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: (colors?.textPrimary ?? Colors.white)
                              .withValues(alpha: 0.08),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (colors?.background ?? Colors.black)
                              .withValues(alpha: 0.32),
                          blurRadius: 28,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      minimum: EdgeInsets.fromLTRB(
                        layout.horizontalPadding,
                        2,
                        layout.horizontalPadding,
                        layout.isCompact ? 2 : 4,
                      ),
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < items.length;
                            index++
                          ) ...[
                            Expanded(
                              child: _DockAction(
                                item: items[index],
                                compactLayout: layout.isCompact,
                              ),
                            ),
                            if (index != items.length - 1)
                              const SizedBox(width: FlowSpace.xxs),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItemData {
  const _DockItemData({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.prominent = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool prominent;
}

class _DockAction extends StatelessWidget {
  const _DockAction({required this.item, required this.compactLayout});

  final _DockItemData item;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final selected = item.selected;
    final emphasized = item.prominent || selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScaleTap(
          key: ValueKey('dock-${item.id}'),
          onTap: item.onTap,
          child: AnimatedContainer(
            duration: FlowDurations.regular,
            curve: FlowDurations.curve,
            constraints: BoxConstraints(minHeight: compactLayout ? 46 : 50),
            padding: EdgeInsets.symmetric(
              vertical: compactLayout ? 5 : 6,
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: const Alignment(-1, -1),
                end: const Alignment(1, 1),
                colors: selected
                    ? <Color>[
                        (gradients?.accentStart ?? Colors.white).withValues(
                          alpha: 0.16,
                        ),
                        (gradients?.accentEnd ?? Colors.white).withValues(
                          alpha: 0.08,
                        ),
                      ]
                    : <Color>[Colors.transparent, Colors.transparent],
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      ...?flow?.shadows.level1,
                      BoxShadow(
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.16,
                        ),
                        blurRadius: 24,
                        spreadRadius: -10,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: FlowDurations.regular,
              curve: FlowDurations.curve,
              style:
                  Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colors?.textPrimary
                        : emphasized
                        ? colors?.textPrimary.withValues(alpha: 0.9)
                        : colors?.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ) ??
                  const TextStyle(),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: FlowDurations.regular,
                      curve: FlowDurations.curve,
                      width: selected ? 18 : 0,
                      height: selected ? 2 : 0,
                      margin: EdgeInsets.only(bottom: selected ? 5 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            gradients?.accentStart ?? Colors.white,
                            gradients?.accentEnd ?? Colors.white,
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: compactLayout ? 17 : 18,
                      color: selected
                          ? colors?.accentSecondary
                          : emphasized
                          ? colors?.textPrimary.withValues(alpha: 0.92)
                          : colors?.textSecondary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 2),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? colors?.textPrimary
                              : emphasized
                              ? colors?.textPrimary.withValues(alpha: 0.88)
                              : colors?.textSecondary.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
