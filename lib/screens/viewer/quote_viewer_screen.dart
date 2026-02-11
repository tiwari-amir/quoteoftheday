import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_model.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../services/quote_service.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_card.dart';

class QuoteViewerScreen extends ConsumerStatefulWidget {
  const QuoteViewerScreen({super.key, required this.type, required this.tag});

  final String type;
  final String tag;

  @override
  ConsumerState<QuoteViewerScreen> createState() => _QuoteViewerScreenState();
}

class _QuoteViewerScreenState extends ConsumerState<QuoteViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _timerController;

  int _currentIndex = 0;
  int? _activeQuoteId;
  final Set<int> _likedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timerController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNextQuote();
        }
      });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimerForQuote(QuoteModel quote) {
    if (_activeQuoteId == quote.id && _timerController.isAnimating) {
      return;
    }

    _activeQuoteId = quote.id;
    final durationSeconds = QuoteService().readingDurationInSeconds(
      quote.quote,
    );
    _timerController
      ..duration = Duration(seconds: durationSeconds)
      ..forward(from: 0);
  }

  Future<void> _goToNextQuote() async {
    final quotes = await ref.read(quotesByTagProvider(widget.tag).future);
    if (!mounted || quotes.isEmpty) return;

    if (_currentIndex >= quotes.length - 1) {
      _timerController.stop();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _copyToClipboard(QuoteModel quote) {
    Clipboard.setData(
      ClipboardData(text: '"${quote.quote}" - ${quote.author}'),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quote copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesByTagProvider(widget.tag));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: quotesAsync.when(
              data: (quotes) {
                if (quotes.isEmpty) {
                  return Center(
                    child: Text(
                      'No quotes found for "${widget.tag}"',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                final currentQuote =
                    quotes[_currentIndex.clamp(0, quotes.length - 1)];
                _startTimerForQuote(currentQuote);

                final savedIds = ref.watch(savedQuoteIdsProvider);
                final isSaved = savedIds.contains(currentQuote.id);
                final isLiked = _likedIds.contains(currentQuote.id);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: context.pop,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          Expanded(
                            child: Hero(
                              tag: 'tag-${widget.tag}',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  '${widget.type.toUpperCase()}: ${widget.tag}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedBuilder(
                        animation: _timerController,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            minHeight: 4,
                            value: _timerController.value,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.secondary,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: quotes.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                            _activeQuoteId = null;
                          });
                        },
                        itemBuilder: (context, index) {
                          final quote = quotes[index];

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child:
                                        GlassCard(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '"${quote.quote}"',
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.headlineSmall,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Text(
                                                    '- ${quote.author}',
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                ],
                                              ),
                                            )
                                            .animate(key: ValueKey(quote.id))
                                            .fadeIn(duration: 300.ms)
                                            .slideY(
                                              begin: 0.16,
                                              end: 0,
                                              duration: 300.ms,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ActionButton(
                                      icon: isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isLiked
                                          ? Colors.pinkAccent
                                          : Colors.white,
                                      onTap: () {
                                        setState(() {
                                          if (!_likedIds.add(currentQuote.id)) {
                                            _likedIds.remove(currentQuote.id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _ActionButton(
                                      icon: isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_outline_rounded,
                                      color: isSaved
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondary
                                          : Colors.white,
                                      onTap: () {
                                        ref
                                            .read(
                                              savedQuoteIdsProvider.notifier,
                                            )
                                            .toggle(currentQuote.id);
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _ActionButton(
                                      icon: Icons.share_rounded,
                                      color: Colors.white,
                                      onTap: () =>
                                          _copyToClipboard(currentQuote),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('Failed to load viewer: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
