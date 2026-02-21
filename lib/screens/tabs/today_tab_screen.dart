import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/v3_share/story_share_sheet.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/streak_provider.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';

class TodayTabScreen extends ConsumerWidget {
  const TodayTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyQuoteProvider);
    final streak = ref.watch(streakProvider);

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
                              Text(
                                quote.quote,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 34,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                quote.author,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Author details',
                                onPressed: () => showModalBottomSheet<void>(
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
                                icon: const Icon(
                                  Icons.person_search_outlined,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const Spacer(),
                      Row(
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
