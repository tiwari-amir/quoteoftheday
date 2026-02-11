import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/scale_tap.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<String> _moodOrder = [
    'happy',
    'calm',
    'hopeful',
    'motivated',
    'confident',
    'sad',
    'lonely',
    'angry',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodsAsync = ref.watch(moodCountsProvider);
    final quoteService = ref.read(quoteServiceProvider);

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
                        'Browse Moods',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search mood',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: moodsAsync.when(
                      data: (moods) {
                        final entries = moods.entries.toList();
                        final ordered = <MapEntry<String, int>>[];

                        for (final mood in _moodOrder) {
                          final match = entries
                              .where((entry) => entry.key == mood)
                              .firstOrNull;
                          if (match != null) ordered.add(match);
                        }

                        final extras =
                            entries
                                .where(
                                  (entry) => !_moodOrder.contains(entry.key),
                                )
                                .toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
                        ordered.addAll(extras);

                        final filtered = ordered.where((entry) {
                          final label = quoteService
                              .displayTag(entry.key)
                              .toLowerCase();
                          return label.contains(_query.toLowerCase());
                        }).toList();

                        return GridView.builder(
                          itemCount: filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.06,
                              ),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final mood = entry.key;
                            final count = entry.value;

                            return ScaleTap(
                                  onTap: () => context.push(
                                    '/viewer/mood/${Uri.encodeComponent(mood)}',
                                  ),
                                  child: Hero(
                                    tag: 'tag-$mood',
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
                                              alpha: 0.14,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.tealAccent.withValues(
                                            alpha: 0.45,
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
                                            quoteService.displayTag(mood),
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
                                .animate(delay: (index * 35).ms)
                                .fadeIn(duration: 240.ms);
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
