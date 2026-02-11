import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/scale_tap.dart';

class MoodScreen extends ConsumerWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(moodCountsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: context.pop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Browse by Mood',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: moodsAsync.when(
                      data: (moods) {
                        final entries = moods.entries.toList();
                        return GridView.builder(
                          itemCount: entries.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.15,
                              ),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final tag = entry.key;
                            final count = entry.value;

                            return ScaleTap(
                                  onTap: () => context.push(
                                    '/viewer/mood/${Uri.encodeComponent(tag)}',
                                  ),
                                  child: Hero(
                                    tag: 'tag-$tag',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.tealAccent.withValues(
                                              alpha: 0.2,
                                            ),
                                            Colors.lightBlueAccent.withValues(
                                              alpha: 0.15,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.tealAccent.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.tealAccent.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 18,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tag,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const Spacer(),
                                          Text(
                                            '$count quotes',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .animate(delay: (index * 30).ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.1, end: 0);
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Failed to load moods: $error')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
