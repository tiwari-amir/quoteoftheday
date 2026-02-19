import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/quote_providers.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/scale_tap.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodsAsync = ref.watch(moodCountsProvider);
    final service = ref.read(quoteServiceProvider);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        onTap: context.pop,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Browse by Mood',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    borderRadius: 18,
                    blur: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        hintText: 'Search moods',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: moodsAsync.when(
                      data: (moods) {
                        final list =
                            moods.entries
                                .map(
                                  (entry) => _MoodCount(
                                    mood: entry.key,
                                    label: service.toTitleCase(entry.key),
                                    count: entry.value,
                                  ),
                                )
                                .where(
                                  (item) =>
                                      item.label.toLowerCase().contains(_query),
                                )
                                .toList()
                              ..sort((a, b) => a.label.compareTo(b.label));

                        if (list.isEmpty) {
                          return const Center(
                            child: Text('No moods available in dataset'),
                          );
                        }

                        return GridView.builder(
                          itemCount: list.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.08,
                              ),
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return ScaleTap(
                                  onTap: () => context.push(
                                    '/viewer/mood/${Uri.encodeComponent(item.mood)}',
                                  ),
                                  child: _MoodCard(item: item),
                                )
                                .animate(delay: (index * 24).ms)
                                .fadeIn(duration: 260.ms)
                                .slideY(begin: 0.08, end: 0);
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Failed to load: $error')),
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

class _MoodCard extends StatefulWidget {
  const _MoodCard({required this.item});

  final _MoodCount item;

  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderIdle = Colors.white.withValues(alpha: 0.16);
    final borderHover = scheme.primary.withValues(alpha: 0.7);
    final glow = scheme.primary.withValues(alpha: 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.surface.withValues(alpha: 0.5),
          border: Border.all(color: _hovering ? borderHover : borderIdle),
          boxShadow: [
            BoxShadow(
              color: _hovering ? glow : Colors.black.withValues(alpha: 0.25),
              blurRadius: _hovering ? 22 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.label,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${widget.item.count} quotes',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodCount {
  const _MoodCount({
    required this.mood,
    required this.label,
    required this.count,
  });

  final String mood;
  final String label;
  final int count;
}
