import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/scale_tap.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCountsProvider);
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
                        'Browse Categories',
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
                        hintText: 'Search category',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: categoriesAsync.when(
                      data: (categories) {
                        final entries = categories.entries.toList();
                        final filtered = entries.where((entry) {
                          final label = quoteService
                              .displayTag(entry.key)
                              .toLowerCase();
                          return label.contains(_query.toLowerCase());
                        }).toList();

                        final popular = filtered.take(12).toList();
                        final grouped = <String, List<MapEntry<String, int>>>{};

                        for (final entry
                            in filtered
                              ..sort((a, b) => a.key.compareTo(b.key))) {
                          final label = quoteService.displayTag(entry.key);
                          final letter = label.substring(0, 1).toUpperCase();
                          grouped
                              .putIfAbsent(
                                letter,
                                () => <MapEntry<String, int>>[],
                              )
                              .add(entry);
                        }

                        return ListView(
                          children: [
                            if (popular.isNotEmpty && _query.isEmpty) ...[
                              Text(
                                'Popular',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final entry in popular)
                                    _TagPill(
                                      label: quoteService.displayTag(entry.key),
                                      count: entry.value,
                                      onTap: () => context.push(
                                        '/viewer/category/${Uri.encodeComponent(entry.key)}',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              'All Categories (${filtered.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            for (final letter in grouped.keys) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 6,
                                ),
                                child: Text(
                                  letter,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              for (final entry in grouped[letter]!)
                                ScaleTap(
                                  onTap: () => context.push(
                                    '/viewer/category/${Uri.encodeComponent(entry.key)}',
                                  ),
                                  child: Hero(
                                    tag: 'tag-${entry.key}',
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              quoteService.displayTag(
                                                entry.key,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                          ),
                                          Text(
                                            '${entry.value}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(width: 10),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 220.ms),
                            ],
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Failed to load categories: $error'),
                      ),
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

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.14),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(width: 8),
            Text('$count', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
