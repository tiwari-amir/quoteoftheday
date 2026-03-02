import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/v3_background/background_theme_provider.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/streak_provider.dart';
import '../../theme/quote_container_palette.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';

class TodayTabScreen extends ConsumerWidget {
  const TodayTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyQuoteProvider);
    final streak = ref.watch(streakProvider);
    final backgroundTheme = ref.watch(appBackgroundThemeProvider);
    final quotePalette = quoteContainerPaletteFor(backgroundTheme);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: dailyAsync.when(
                data: (quote) {
                  final scheme = Theme.of(context).colorScheme;
                  final isSaved = ref
                      .watch(savedQuoteIdsProvider)
                      .contains(quote.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Today',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14,
                                  color: scheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(Icons.tune),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Column(
                            key: ValueKey(quote.id),
                            children: [
                              _TodayQuoteContainer(
                                quote: quote.quote,
                                author: quote.author,
                                palette: quotePalette,
                                onAuthorTap: () => showModalBottomSheet<void>(
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          // CTA-only blur: keeps quote content sharp and primary.
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                    ),
                                    onPressed: () => ref
                                        .read(savedQuoteIdsProvider.notifier)
                                        .toggle(quote.id),
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_outline_rounded,
                                    ),
                                    label: Text(isSaved ? 'Saved' : 'Save'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                    ),
                                    onPressed: () => showStoryShareSheet(
                                      context: context,
                                      quote: quote,
                                      subject: 'QuoteFlow: Daily Scroll Quotes',
                                    ),
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('Share'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}

class _TodayQuoteContainer extends StatelessWidget {
  const _TodayQuoteContainer({
    required this.quote,
    required this.author,
    required this.palette,
    required this.onAuthorTap,
  });

  final String quote;
  final String author;
  final QuoteContainerPalette palette;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, minWidth: 220),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final quoteFontSize = compact ? 29.0 : 33.0;
          final cardPadding = compact
              ? const EdgeInsets.fromLTRB(18, 20, 18, 16)
              : const EdgeInsets.fromLTRB(24, 24, 24, 18);
          final accent = palette.chromeTint.withValues(alpha: 0.78);

          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.fillTop,
                      Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.06),
                        palette.fillBottom,
                      ),
                    ],
                  ),
                  border: Border.all(color: palette.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: palette.glow.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.045),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: cardPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: palette.border.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'QUOTE OF THE DAY',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: palette.tagText.withValues(
                                          alpha: 0.95,
                                        ),
                                        letterSpacing: 0.9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Icon(
                            Icons.format_quote_rounded,
                            size: 26,
                            color: accent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            quote,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: quoteFontSize,
                              height: 1.34,
                              color: palette.quoteText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            height: 1,
                            width: compact ? 110 : 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  palette.border.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            author,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: palette.authorText,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              visualDensity: VisualDensity.compact,
                              foregroundColor: palette.tagText,
                              side: BorderSide(
                                color: palette.border.withValues(alpha: 0.68),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.03,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: onAuthorTap,
                            icon: const Icon(
                              Icons.person_search_outlined,
                              size: 18,
                            ),
                            label: const Text('Author details'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
