import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/scale_tap.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyQuoteAsync = ref.watch(dailyQuoteProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Quote of the Day',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => context.push('/saved'),
                          icon: const Icon(Icons.bookmark_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    dailyQuoteAsync.when(
                      data: (quote) {
                        return GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '"${quote.quote}"',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '- ${quote.author}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 450.ms)
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      loading: () => const AspectRatio(
                        aspectRatio: 1.25,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => GlassCard(
                        child: Text('Could not load quote: $error'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Browse by Category',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    ScaleTap(
                      onTap: () => context.push('/categories'),
                      child: const _NavTile(
                        title: 'Categories',
                        subtitle: 'Explore tags and themes',
                        icon: Icons.grid_view_rounded,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Browse by Mood',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    ScaleTap(
                      onTap: () => context.push('/moods'),
                      child: const _NavTile(
                        title: 'Moods',
                        subtitle: 'Find quotes by feeling',
                        icon: Icons.mood_rounded,
                      ),
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

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
