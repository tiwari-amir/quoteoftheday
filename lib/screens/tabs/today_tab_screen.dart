import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_notifications/in_app_notifications_providers.dart';
import '../../features/v3_notifications/in_app_notifications_screen.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/streak_provider.dart';
import '../../services/author_wiki_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/adaptive_author_image.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../widgets/scale_tap.dart';

final _todayAuthorProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      final normalized = author.trim();
      if (normalized.isEmpty || normalized.toLowerCase() == 'unknown') {
        return null;
      }
      return ref.read(authorWikiServiceProvider).fetchAuthor(normalized);
    });

class TodayTabScreen extends ConsumerWidget {
  const TodayTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyQuoteProvider);
    final streak = ref.watch(streakProvider);
    final hasUnreadNotifications = ref.watch(
      hasUnreadInAppNotificationsProvider,
    );
    final latestNotification = ref.watch(latestInAppNotificationProvider);
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(seed: 91),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
          ),
          dailyAsync.when(
            data: (quote) {
              final isSaved = ref
                  .watch(savedQuoteIdsProvider)
                  .contains(quote.id);
              return SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.horizontalPadding,
                        layout.topPadding,
                        layout.horizontalPadding,
                        layout.isCompact ? FlowSpace.lg : FlowSpace.xl,
                      ),
                      child: Column(
                        children: [
                          _TodayTopBar(
                            streak: streak,
                            hasUnreadNotifications: hasUnreadNotifications,
                            onNotificationsTap: () async {
                              final latestId = latestNotification?.id ?? 0;
                              if (latestId > 0) {
                                unawaited(
                                  ref
                                      .read(
                                        inAppNotificationPreferencesProvider
                                            .notifier,
                                      )
                                      .markSeenUpTo(latestId),
                                );
                              }
                              await showInAppNotificationsSheet(context);
                            },
                            onSettingsTap: () => context.push('/settings'),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableHeight = constraints.maxHeight;
                                final denseHero =
                                    layout.isCompactHeight ||
                                    availableHeight < 620;
                                final verticalInset = denseHero
                                    ? FlowSpace.xs
                                    : FlowSpace.sm;

                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    vertical: verticalInset,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight:
                                          availableHeight > verticalInset * 2
                                          ? availableHeight -
                                                (verticalInset * 2)
                                          : 0,
                                    ),
                                    child: Center(
                                      child:
                                          _MinimalDailyHero(
                                                quote: quote.quote,
                                                author: quote.author,
                                                isSaved: isSaved,
                                                availableHeight:
                                                    availableHeight,
                                                dense: denseHero,
                                                onToggleSaved: () => ref
                                                    .read(
                                                      savedQuoteIdsProvider
                                                          .notifier,
                                                    )
                                                    .toggle(quote.id),
                                                onShare: () => showStoryShareSheet(
                                                  context: context,
                                                  quote: quote,
                                                  subject:
                                                      'QuoteFlow: Daily Scroll Quotes',
                                                ),
                                                onAuthorDetails: () =>
                                                    showAuthorInfoSheetForAuthor(
                                                      context,
                                                      ref,
                                                      quote.author,
                                                    ),
                                              )
                                              .animate()
                                              .fadeIn(
                                                duration: FlowDurations.regular,
                                              )
                                              .moveY(
                                                begin: 18,
                                                end: 0,
                                                duration:
                                                    FlowDurations.emphasized,
                                                curve: FlowDurations.curve,
                                              ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(FlowSpace.lg),
                child: PremiumSurface(
                  blurSigma: 16,
                  child: Text(
                    'Failed to load the daily quote: $error',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTopBar extends StatelessWidget {
  const _TodayTopBar({
    required this.streak,
    required this.hasUnreadNotifications,
    required this.onNotificationsTap,
    required this.onSettingsTap,
  });

  final int streak;
  final bool hasUnreadNotifications;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors?.textPrimary,
                  fontSize: layout.isCompact ? 22 : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _streakLabel(streak),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors?.textSecondary.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
        _TodayNotificationsButton(
          hasUnread: hasUnreadNotifications,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: FlowSpace.xs),
        PremiumIconPillButton(
          icon: Icons.tune_rounded,
          compact: true,
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class _MinimalDailyHero extends StatelessWidget {
  const _MinimalDailyHero({
    required this.quote,
    required this.author,
    required this.isSaved,
    required this.availableHeight,
    required this.dense,
    required this.onToggleSaved,
    required this.onShare,
    required this.onAuthorDetails,
  });

  final String quote;
  final String author;
  final bool isSaved;
  final double availableHeight;
  final bool dense;
  final VoidCallback onToggleSaved;
  final VoidCallback onShare;
  final VoidCallback onAuthorDetails;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final layout = FlowLayoutInfo.of(context);
    final words = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    final isShortViewport =
        dense || layout.isCompactHeight || availableHeight < 620;

    final baseQuoteSize = switch (words) {
      <= 12 => layout.isCompact ? 42.0 : 52.0,
      <= 22 => layout.isCompact ? 34.0 : 42.0,
      <= 36 => layout.isCompact ? 30.0 : 36.0,
      <= 48 => layout.isCompact ? 27.0 : 32.0,
      _ => layout.isCompact ? 23.0 : 28.0,
    };
    final quoteSize = isShortViewport
        ? (baseQuoteSize - 4).clamp(21.0, 46.0)
        : baseQuoteSize;
    final minQuoteSize = isShortViewport ? 17.0 : 19.0;
    final quoteLineLimit = switch (availableHeight) {
      < 520 => 7,
      < 620 => 8,
      < 760 => 9,
      _ => 10,
    };
    final haloSize = layout.fluid(
      min: isShortViewport ? 220 : 260,
      max: isShortViewport ? 300 : 340,
    );
    final portraitSize = layout.fluid(
      min: isShortViewport ? 70 : 78,
      max: isShortViewport ? 86 : 98,
    );
    final eyebrowGap = isShortViewport
        ? FlowSpace.sm
        : (layout.isCompact ? FlowSpace.md : FlowSpace.lg);
    final authorGap = isShortViewport
        ? FlowSpace.md
        : (layout.isCompact ? FlowSpace.lg : FlowSpace.xl);
    final actionGap = isShortViewport ? FlowSpace.sm : FlowSpace.md;
    final authorFontSize = isShortViewport
        ? (layout.isCompact ? 18.0 : 19.0)
        : (layout.isCompact ? 20.0 : null);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: layout.textColumnWidth),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              width: haloSize,
              height: haloSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (gradients?.accentStart ?? Colors.white).withValues(
                      alpha: 0.18,
                    ),
                    (gradients?.accentEnd ?? Colors.white).withValues(
                      alpha: 0.08,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? FlowSpace.xs : FlowSpace.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quote of the day',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors?.accentSecondary.withValues(alpha: 0.88),
                    letterSpacing: isShortViewport ? 0.9 : 1.1,
                  ),
                ),
                SizedBox(height: eyebrowGap),
                AutoSizeText(
                  quote,
                  textAlign: TextAlign.center,
                  maxLines: quoteLineLimit,
                  minFontSize: minQuoteSize,
                  stepGranularity: 1,
                  style:
                      FlowTypography.quoteStyle(
                        context: context,
                        color: colors?.textPrimary ?? Colors.white,
                        fontSize: quoteSize,
                        weight: FontWeight.w500,
                      ).copyWith(
                        height: words > 38 ? 1.4 : 1.32,
                        shadows: [
                          Shadow(
                            blurRadius: 28,
                            color: Colors.black.withValues(alpha: 0.28),
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                ),
                SizedBox(height: authorGap),
                _TodayAuthorPortrait(
                  author: author,
                  size: portraitSize,
                  onTap: onAuthorDetails,
                ),
                SizedBox(height: isShortViewport ? FlowSpace.sm : FlowSpace.md),
                ScaleTap(
                  onTap: onAuthorDetails,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FlowSpace.xs,
                      vertical: 2,
                    ),
                    child: Text(
                      author,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors?.accentSecondary.withValues(alpha: 0.98),
                        fontWeight: FontWeight.w600,
                        fontSize: authorFontSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: actionGap),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: layout.isCompact ? FlowSpace.sm : FlowSpace.md,
                  runSpacing: FlowSpace.xs,
                  children: [
                    _HeroInlineAction(
                      icon: Icons.person_outline_rounded,
                      label: 'Details',
                      onTap: onAuthorDetails,
                    ),
                    _HeroInlineAction(
                      icon: isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      label: isSaved ? 'Saved' : 'Save',
                      active: isSaved,
                      onTap: onToggleSaved,
                    ),
                    _HeroInlineAction(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      onTap: onShare,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAuthorPortrait extends ConsumerWidget {
  const _TodayAuthorPortrait({
    required this.author,
    required this.size,
    required this.onTap,
  });

  final String author;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final normalized = author.trim();
    final profileAsync = ref.watch(_todayAuthorProfileProvider(normalized));
    final outerSize = size + 10;

    return Semantics(
      button: true,
      label: 'Open details for $author',
      child: ScaleTap(
        onTap: onTap,
        child: Container(
          width: outerSize,
          height: outerSize,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                (gradients?.accentStart ?? Colors.white).withValues(
                  alpha: 0.78,
                ),
                Colors.white.withValues(alpha: 0.2),
                (gradients?.accentEnd ?? Colors.white).withValues(alpha: 0.72),
                (gradients?.accentStart ?? Colors.white).withValues(
                  alpha: 0.78,
                ),
              ],
              stops: const [0.0, 0.34, 0.72, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: (gradients?.accentStart ?? Colors.white).withValues(
                  alpha: 0.16,
                ),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (colors?.surface ?? Colors.black).withValues(alpha: 0.92),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    profileAsync.when(
                      data: (profile) {
                        final imageUrl = profile?.imageUrl?.trim();
                        if (imageUrl == null || imageUrl.isEmpty) {
                          return _TodayAuthorFallback(size: size);
                        }
                        return AdaptiveAuthorImage(
                          imageUrl: imageUrl,
                          placeholder: _TodayAuthorFallback(size: size),
                          error: _TodayAuthorFallback(size: size),
                        );
                      },
                      loading: () => _TodayAuthorFallback(size: size),
                      error: (_, _) => _TodayAuthorFallback(size: size),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                          ],
                          stops: const [0.0, 0.34, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayAuthorFallback extends StatelessWidget {
  const _TodayAuthorFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (gradients?.accentStart ?? Colors.white).withValues(alpha: 0.72),
            (colors?.surface ?? Colors.black).withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: size * 0.36,
          color: colors?.textPrimary.withValues(alpha: 0.9) ?? Colors.white,
        ),
      ),
    );
  }
}

class _HeroInlineAction extends StatelessWidget {
  const _HeroInlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final gradients = flow?.gradients;
    final layout = FlowLayoutInfo.of(context);
    final accentColor = active
        ? colors?.accentSecondary ?? Colors.white
        : colors?.textSecondary.withValues(alpha: 0.84) ?? Colors.white70;

    return ScaleTap(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.isCompact ? 6 : 8,
          vertical: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: layout.isCompact ? 16 : 18,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: active
                        ? colors?.textPrimary ?? Colors.white
                        : colors?.textSecondary.withValues(alpha: 0.82),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: FlowDurations.regular,
              curve: FlowDurations.curve,
              width: active ? 28 : 16,
              height: 1.6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: active
                      ? [
                          (gradients?.accentStart ?? Colors.white).withValues(
                            alpha: 0.95,
                          ),
                          (gradients?.accentEnd ?? Colors.white).withValues(
                            alpha: 0.84,
                          ),
                        ]
                      : [
                          (colors?.divider ?? Colors.white24).withValues(
                            alpha: 0.28,
                          ),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayNotificationsButton extends StatelessWidget {
  const _TodayNotificationsButton({
    required this.hasUnread,
    required this.onTap,
  });

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PremiumIconPillButton(
          icon: Icons.notifications_none_rounded,
          compact: true,
          onTap: onTap,
        ),
        if (hasUnread)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors?.accent ?? Colors.white,
                border: Border.all(
                  color: colors?.surface ?? Colors.black,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (colors?.accent ?? Colors.white).withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _streakLabel(int streak) {
  if (streak <= 0) return 'Fresh start';
  if (streak == 1) return '1 day streak';
  return '$streak day streak';
}
