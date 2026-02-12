import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../services/quote_service.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';

class QuoteViewerScreen extends ConsumerStatefulWidget {
  const QuoteViewerScreen({super.key, required this.type, required this.tag});

  final String type;
  final String tag;

  @override
  ConsumerState<QuoteViewerScreen> createState() => _QuoteViewerScreenState();
}

class _QuoteViewerScreenState extends ConsumerState<QuoteViewerScreen>
    with SingleTickerProviderStateMixin {
  late final QuoteViewerFilter _filter;
  late final PageController _pageController;
  late final AnimationController _progressController;

  final Set<String> _likedIds = <String>{};
  Timer? _hintTimer;

  int _currentIndex = 0;
  String? _activeQuoteId;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _filter = QuoteViewerFilter(type: widget.type, tag: widget.tag.toLowerCase());
    _pageController = PageController();
    _progressController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _autoAdvance();
        }
      });

    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimerForQuote(QuoteModel quote) {
    if (_activeQuoteId == quote.id && _progressController.isAnimating) return;

    _activeQuoteId = quote.id;
    final durationSeconds = ref.read(quoteServiceProvider).readingDurationInSeconds(quote.quote);

    _progressController
      ..duration = Duration(seconds: durationSeconds)
      ..forward(from: 0);
  }

  Future<void> _autoAdvance() async {
    final quotes = await ref.read(quotesByFilterProvider(_filter).future);
    if (!mounted || quotes.isEmpty || !_pageController.hasClients) return;

    final nextIndex = (_currentIndex + 1) % quotes.length;
    await _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index, List<QuoteModel> quotes) {
    setState(() {
      _currentIndex = index;
      _activeQuoteId = null;
      if (_currentIndex > 0) _showHint = false;
    });

    _startTimerForQuote(quotes[index]);
  }

  void _shareQuote(QuoteModel quote) {
    Share.share('"${quote.quote}"\n\n- ${quote.author}', subject: 'Quote of the Day');
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesByFilterProvider(_filter));
    final service = ref.read(quoteServiceProvider);

    return Scaffold(
      body: quotesAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return Stack(
              children: [
                const AnimatedGradientBackground(),
                Center(
                  child: Text(
                    'No quotes found for ${service.toTitleCase(widget.tag)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            );
          }

          final currentQuote = quotes[_currentIndex.clamp(0, quotes.length - 1)];
          final savedIds = ref.watch(savedQuoteIdsProvider);
          final isSaved = savedIds.contains(currentQuote.id);
          final isLiked = _likedIds.contains(currentQuote.id);

          _startTimerForQuote(currentQuote);

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: quotes.length,
                onPageChanged: (index) => _onPageChanged(index, quotes),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  return Stack(
                    children: [
                      AnimatedGradientBackground(seed: quote.id.hashCode),
                      SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 80, 24, 100),
                            child: _QuotePanel(quote: quote, service: service),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GlassIconButton(icon: Icons.close_rounded, onTap: context.pop),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    minHeight: 5,
                                    value: _progressController.value,
                                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3FD6FF)),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 54),
                        ],
                      ),
                      const Spacer(),
                      if (_currentIndex == 0 && _showHint)
                        Text(
                          'Swipe up',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ).animate().fadeIn(duration: 250.ms).fadeOut(delay: 1400.ms),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ViewerActionButton(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        tint: isLiked ? const Color(0xFFFF6B8A) : null,
                        onTap: () {
                          setState(() {
                            if (!_likedIds.add(currentQuote.id)) {
                              _likedIds.remove(currentQuote.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _ViewerActionButton(
                        icon: isSaved ? Icons.bookmark : Icons.bookmark_outline_rounded,
                        tint: isSaved ? const Color(0xFF3FD6FF) : null,
                        onTap: () => ref.read(savedQuoteIdsProvider.notifier).toggle(currentQuote.id),
                      ),
                      const SizedBox(height: 12),
                      _ViewerActionButton(
                        icon: Icons.send_rounded,
                        onTap: () => _shareQuote(currentQuote),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Stack(
          children: [
            AnimatedGradientBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stack) => Stack(
          children: [
            const AnimatedGradientBackground(),
            Center(child: Text('Failed to load viewer: $error')),
          ],
        ),
      ),
    );
  }
}

class _QuotePanel extends StatelessWidget {
  const _QuotePanel({required this.quote, required this.service});

  final QuoteModel quote;
  final QuoteService service;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.46,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        quote.quote,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    quote.author,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tag in quote.revisedTags.take(4)) ...[
                          _TagChip(label: service.toTitleCase(tag)),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        )
        .animate(key: ValueKey(quote.id))
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ViewerActionButton extends StatelessWidget {
  const _ViewerActionButton({
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(icon: icon, onTap: onTap, iconColor: tint);
  }
}
