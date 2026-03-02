import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_share/story_share_sheet.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/streak_provider.dart';
import '../../services/author_wiki_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';

final _todayAuthorProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      return ref.read(authorWikiServiceProvider).fetchAuthor(author);
    });

class TodayTabScreen extends ConsumerWidget {
  const TodayTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyQuoteProvider);
    final streak = ref.watch(streakProvider);
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.0, 0.36, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.md,
                FlowSpace.lg,
                FlowSpace.lg,
              ),
              child: dailyAsync.when(
                data: (quote) {
                  final isSaved = ref
                      .watch(savedQuoteIdsProvider)
                      .contains(quote.id);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lockscreenDateLabel(DateTime.now()),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors?.textSecondary.withValues(
                                alpha: 0.94,
                              ),
                              letterSpacing: 0.42,
                            ),
                      ).animate().fadeIn(duration: FlowDurations.quick),
                      const SizedBox(height: FlowSpace.xxs),
                      Row(
                        children: [
                          Text(
                            'Today',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const Spacer(),
                          PremiumSurface(
                            radius: 999,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(
                              horizontal: FlowSpace.sm,
                              vertical: FlowSpace.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14,
                                  color: colors?.accent,
                                ),
                                const SizedBox(width: FlowSpace.xs),
                                Text(
                                  '$streak',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: FlowSpace.xs),
                          PremiumIconPillButton(
                            icon: Icons.tune_rounded,
                            compact: true,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ).animate().fadeIn(duration: FlowDurations.regular),
                      const SizedBox(height: FlowSpace.md),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: FlowDurations.emphasized,
                          switchInCurve: FlowDurations.curve,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final floatIn =
                                Tween<Offset>(
                                  begin: const Offset(0, 0.025),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: FlowDurations.curve,
                                  ),
                                );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: floatIn,
                                child: child,
                              ),
                            );
                          },
                          child: LayoutBuilder(
                            key: ValueKey(quote.id),
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: _LockscreenQuoteContent(
                                      quote: quote.quote,
                                      author: quote.author,
                                      onAuthorDetails: () {
                                        showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => AuthorInfoSheet(
                                            author: quote.author,
                                            loader: () => ref
                                                .read(authorWikiServiceProvider)
                                                .fetchAuthor(quote.author),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: FlowSpace.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PremiumIconPillButton(
                            icon: isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            label: isSaved ? 'Saved' : 'Save',
                            compact: true,
                            active: isSaved,
                            onTap: () => ref
                                .read(savedQuoteIdsProvider.notifier)
                                .toggle(quote.id),
                          ),
                          const SizedBox(width: FlowSpace.sm),
                          PremiumIconPillButton(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            compact: true,
                            onTap: () => showStoryShareSheet(
                              context: context,
                              quote: quote,
                              subject: 'QuoteFlow: Daily Scroll Quotes',
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: FlowDurations.regular),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('Failed to load: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lockscreenDateLabel(DateTime date) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _LockscreenQuoteContent extends StatelessWidget {
  const _LockscreenQuoteContent({
    required this.quote,
    required this.author,
    required this.onAuthorDetails,
  });

  final String quote;
  final String author;
  final VoidCallback onAuthorDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final words = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;

    final quoteSize = switch (words) {
      <= 12 => 40.0,
      <= 22 => 35.0,
      <= 34 => 30.0,
      <= 48 => 26.0,
      _ => 22.0,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, minWidth: 220),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.sm,
          vertical: FlowSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TodayAuthorPortrait(author: author),
            const SizedBox(height: FlowSpace.md),
            Text(
              '"',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: colors?.textSecondary.withValues(alpha: 0.36),
                height: 0.66,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              quote,
              textAlign: TextAlign.center,
              style:
                  FlowTypography.quoteStyle(
                    color: colors?.textPrimary ?? Colors.white,
                    fontSize: quoteSize,
                  ).copyWith(
                    height: words > 42 ? 1.45 : 1.38,
                    shadows: [
                      Shadow(
                        blurRadius: 24,
                        color: Colors.black.withValues(alpha: 0.28),
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: FlowSpace.lg),
            Container(
              height: 1,
              width: 172,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    colors?.divider.withValues(alpha: 0.9) ??
                        Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: FlowSpace.sm),
            Text(
              '— $author',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors?.textSecondary.withValues(alpha: 0.96),
                letterSpacing: 0.24,
              ),
            ),
            const SizedBox(height: FlowSpace.xs),
            TextButton.icon(
              onPressed: onAuthorDetails,
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Author details'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colors?.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayAuthorPortrait extends ConsumerWidget {
  const _TodayAuthorPortrait({required this.author});

  final String author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = ref.watch(_todayAuthorProfileProvider(author));

    return profileAsync.when(
      data: (profile) {
        final imageUrl = profile?.imageUrl?.trim();
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;

        return SizedBox(
          width: 122,
          height: 122,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (colors?.accent ?? Colors.white).withValues(
                        alpha: 0.28,
                      ),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors?.accent.withValues(alpha: 0.78) ?? Colors.white70,
                      colors?.surface.withValues(alpha: 0.9) ?? Colors.black54,
                    ],
                  ),
                  border: Border.all(
                    color:
                        colors?.divider.withValues(alpha: 0.95) ??
                        Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 50,
                backgroundColor: colors?.surface.withValues(alpha: 0.9),
                backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                child: hasImage
                    ? null
                    : Icon(
                        Icons.person_outline_rounded,
                        size: 34,
                        color: colors?.textSecondary.withValues(alpha: 0.92),
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => SizedBox(
        width: 108,
        height: 108,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors?.accent),
      ),
      error: (error, stackTrace) => CircleAvatar(
        radius: 50,
        backgroundColor: colors?.surface.withValues(alpha: 0.9),
        child: Icon(
          Icons.person_outline_rounded,
          size: 34,
          color: colors?.textSecondary.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
