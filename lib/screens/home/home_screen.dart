import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/neon_chip.dart';
import '../../widgets/scale_tap.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyQuoteAsync = ref.watch(dailyQuoteProvider);
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final moodsAsync = ref.watch(moodCountsProvider);
    final service = ref.read(quoteServiceProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Quote of the Day',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(letterSpacing: 0.2),
                          ),
                        ),
                        GlassIconButton(
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => context.push('/saved'),
                        ),
                        const SizedBox(width: 10),
                        GlassIconButton(
                          icon: Icons.settings_outlined,
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    dailyQuoteAsync.when(
                      data: (quote) {
                        return GlassCard(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FadingQuoteText(text: quote.quote),
                                  const SizedBox(height: 14),
                                  Text(
                                    quote.author,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final tag in quote.revisedTags.take(
                                        2,
                                      ))
                                        NeonChip(
                                          label: service.toTitleCase(tag),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 380.ms)
                            .slideY(
                              begin: 0.12,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => GlassCard(
                        child: Text('Failed to load daily quote: $error'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: 'Browse by category',
                      onTap: () => context.push('/categories'),
                    ),
                    const SizedBox(height: 10),
                    categoriesAsync.when(
                      data: (categories) {
                        final preview = categories.keys.take(3).toList();
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final tag in preview)
                              NeonChip(
                                label: service.toTitleCase(tag),
                                onTap: () => context.push(
                                  '/viewer/category/${Uri.encodeComponent(tag)}',
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 36,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (error, stack) =>
                          Text('Failed to load categories: $error'),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      title: 'Browse by mood',
                      onTap: () => context.push('/moods'),
                    ),
                    const SizedBox(height: 10),
                    moodsAsync.when(
                      data: (moods) {
                        final preview = moods.keys.take(3).toList();
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final tag in preview)
                              NeonChip(
                                label: service.toTitleCase(tag),
                                onTap: () => context.push(
                                  '/viewer/mood/${Uri.encodeComponent(tag)}',
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 36,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (error, stack) =>
                          Text('Failed to load moods: $error'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ScaleTap(
            onTap: onTap,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        TextButton(onPressed: onTap, child: const Text('See all')),
      ],
    );
  }
}

class _FadingQuoteText extends StatelessWidget {
  const _FadingQuoteText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.82, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Text(
        text,
        maxLines: 6,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
