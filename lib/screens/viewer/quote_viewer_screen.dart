import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/quote_service.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/glass_icon_button.dart';
import '../../theme/app_theme.dart';

class QuoteViewerScreen extends ConsumerStatefulWidget {
  const QuoteViewerScreen({
    super.key,
    required this.type,
    required this.tag,
    this.quoteId,
  });

  final String type;
  final String tag;
  final String? quoteId;

  @override
  ConsumerState<QuoteViewerScreen> createState() => _QuoteViewerScreenState();
}

class _QuoteViewerScreenState extends ConsumerState<QuoteViewerScreen> {
  late final QuoteViewerFilter _filter;
  late final PageController _pageController;
  final Random _shuffleRandom = Random();

  Timer? _hintTimer;
  Timer? _controlsTimer;

  int _currentIndex = 0;
  bool _showHint = true;
  bool _showControls = true;
  bool _shuffleEnabled = false;

  String? _datasetSignature;
  List<QuoteModel> _sourceQuotes = const <QuoteModel>[];
  List<QuoteModel> _displayQuotes = const <QuoteModel>[];

  @override
  void initState() {
    super.initState();
    _filter = QuoteViewerFilter(
      type: widget.type,
      tag: widget.tag.toLowerCase(),
    );
    _pageController = PageController();
    _shuffleEnabled =
        ref.read(sharedPreferencesProvider).getBool(prefViewerShuffleEnabled) ??
        false;

    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showHint = false);
    });
    _armControlsFade();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controlsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _armControlsFade() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  void _syncQuotes(List<QuoteModel> quotes) {
    final signature = quotes.map((q) => q.id).join('|');
    if (signature == _datasetSignature) return;

    _datasetSignature = signature;
    _sourceQuotes = List<QuoteModel>.from(quotes, growable: false);
    _rebuildDeck(preferredQuoteId: widget.quoteId, keepCurrentQuote: false);
  }

  void _rebuildDeck({String? preferredQuoteId, bool keepCurrentQuote = true}) {
    if (_sourceQuotes.isEmpty) {
      _displayQuotes = const <QuoteModel>[];
      _currentIndex = 0;
      return;
    }

    if (_shuffleEnabled) {
      _displayQuotes = _nextShuffleCycle();
    } else {
      _displayQuotes = List<QuoteModel>.from(_sourceQuotes, growable: false);
    }

    String? targetQuoteId = preferredQuoteId;
    if (keepCurrentQuote &&
        _displayQuotes.isNotEmpty &&
        _currentIndex < _displayQuotes.length) {
      targetQuoteId ??= _displayQuotes[_currentIndex].id;
    }

    var nextIndex = 0;
    if (targetQuoteId != null) {
      final match = _displayQuotes.indexWhere((q) => q.id == targetQuoteId);
      if (match >= 0) nextIndex = match;
    }

    _currentIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  List<QuoteModel> _nextShuffleCycle() {
    final cycle = List<QuoteModel>.from(_sourceQuotes);
    cycle.shuffle(_shuffleRandom);
    return cycle;
  }

  void _toggleShuffle() {
    if (_sourceQuotes.isEmpty) return;
    if (_displayQuotes.isEmpty || _currentIndex >= _displayQuotes.length) {
      return;
    }
    final currentQuoteId = _displayQuotes[_currentIndex].id;

    setState(() {
      final turningOn = !_shuffleEnabled;
      _shuffleEnabled = turningOn;
      ref
          .read(sharedPreferencesProvider)
          .setBool(prefViewerShuffleEnabled, _shuffleEnabled);

      if (turningOn) {
        final seenIds = _displayQuotes
            .take(_currentIndex + 1)
            .map((q) => q.id)
            .toSet();
        final prefix = _displayQuotes.take(_currentIndex + 1).toList();
        final remaining = _sourceQuotes
            .where((q) => !seenIds.contains(q.id))
            .toList();
        remaining.shuffle(_shuffleRandom);
        _displayQuotes = [...prefix, ...remaining];
      } else {
        final restored = List<QuoteModel>.from(_sourceQuotes, growable: false);
        final currentInRestored = restored.indexWhere(
          (q) => q.id == currentQuoteId,
        );
        _displayQuotes = restored;
        if (currentInRestored >= 0) {
          _currentIndex = currentInRestored;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            _pageController.jumpToPage(_currentIndex);
          });
        }
      }

      _showControls = true;
    });
    _armControlsFade();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (_currentIndex > 0) {
        _showHint = false;
      }
      _showControls = true;
    });
    _armControlsFade();

    if (_shuffleEnabled && index == _displayQuotes.length - 1) {
      final nextCycle = _nextShuffleCycle();
      setState(() {
        _displayQuotes = [..._displayQuotes, ...nextCycle];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End of quotes. Continuing with a fresh shuffle.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareQuote(QuoteModel quote) {
    showStoryShareSheet(
      context: context,
      quote: quote,
      subject: 'QuoteFlow: Daily Scroll Quotes',
    );
  }

  void _showWhy(BuildContext context, QuoteModel quote) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why this quote?'),
        content: Text(_buildReason(quote)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<String> _authorSearchCandidates(String rawAuthor) {
    final clean = rawAuthor.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'unknown') return const [];

    final candidates = <String>{};
    if (clean.toLowerCase() == 'osho') {
      candidates.add('Rajneesh');
      candidates.add('Osho');
    }
    candidates.add(_sanitizeAuthorText(clean));

    for (final sep in [',', ' & ', ' and ', ' - ', '|', ';', ':']) {
      if (!clean.contains(sep)) continue;
      final left = clean.split(sep).first.trim();
      if (left.isNotEmpty) {
        candidates.add(_sanitizeAuthorText(left));
      }
    }

    final withoutParens = clean.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    if (withoutParens.isNotEmpty) {
      candidates.add(_sanitizeAuthorText(withoutParens));
    }

    final list = candidates.where((c) => c.isNotEmpty).toList(growable: false);
    list.sort(
      (a, b) =>
          _candidateAuthorQuality(b).compareTo(_candidateAuthorQuality(a)),
    );
    return list;
  }

  String _sanitizeAuthorText(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-\s]+'), '')
        .replaceAll(RegExp(r'[\-\s]+$'), '')
        .trim();
  }

  int _candidateAuthorQuality(String candidate) {
    final normalized = _normalizeIdentity(candidate);
    if (normalized.isEmpty) return -100;
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    var score = 0;

    if (tokens.length >= 2 && tokens.length <= 5) {
      score += 12;
    } else if (tokens.length == 1 || tokens.length > 7) {
      score -= 8;
    }

    if (RegExp(r'\d').hasMatch(normalized)) {
      score -= 20;
    }

    const noisyTerms = [
      'the',
      'a',
      'an',
      'of',
      'writings',
      'speeches',
      'testament',
      'essential',
      'perks',
      'being',
      'wallflower',
      'novel',
      'book',
    ];

    for (final term in noisyTerms) {
      if (tokens.contains(term)) {
        score -= 6;
      }
    }

    final originalTokens = candidate.split(RegExp(r'\s+'));
    var uppercaseLike = 0;
    for (final token in originalTokens) {
      if (token.isEmpty) continue;
      final c = token[0];
      if (c == c.toUpperCase() && RegExp(r'[A-Za-z]').hasMatch(c)) {
        uppercaseLike += 1;
      }
    }
    score += uppercaseLike;
    return score;
  }

  String _normalizeIdentity(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showAuthorInfo(BuildContext context, QuoteModel quote) {
    final cleaned = _authorSearchCandidates(quote.author);
    final displayAuthor = cleaned.isEmpty ? quote.author : cleaned.first;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AuthorInfoSheet(
          author: displayAuthor,
          loader: () =>
              ref.read(authorWikiServiceProvider).fetchAuthor(quote.author),
        );
      },
    );
  }

  String _buildReason(QuoteModel quote) {
    if (quote.revisedTags.isNotEmpty) {
      return 'Because you are exploring ${quote.revisedTags.first} and related ideas.';
    }

    final words = quote.quote
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words <= 12) return 'This is a quick, concise quote for fast reading.';
    if (words > 24) {
      return 'This is a longer quote selected for deep reflection.';
    }
    return 'This is a balanced pick based on your current feed.';
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final likedIds = ref.watch(likedQuoteIdsProvider);
    final normalizedType = _filter.type.toLowerCase();
    final quotesAsync = normalizedType == 'saved'
        ? ref.watch(allQuotesProvider).whenData((all) {
            return all
                .where((q) => savedIds.contains(q.id))
                .toList(growable: false);
          })
        : normalizedType == 'liked'
        ? ref.watch(allQuotesProvider).whenData((all) {
            return all
                .where((q) => likedIds.contains(q.id))
                .toList(growable: false);
          })
        : ref.watch(quotesByFilterProvider(_filter));
    final service = ref.read(quoteServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppThemeTokens>();
    final viewerAccent = tokens?.viewerAccent ?? scheme.primary;

    return Scaffold(
      body: quotesAsync.when(
        data: (quotes) {
          _syncQuotes(quotes);

          if (_displayQuotes.isEmpty) {
            final isAll =
                widget.tag.trim().isEmpty ||
                widget.tag.trim().toLowerCase() == 'all';
            return Stack(
              children: [
                const EditorialBackground(),
                Center(
                  child: Text(
                    isAll
                        ? 'No quotes available yet'
                        : 'No quotes found for ${service.toTitleCase(widget.tag)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            );
          }

          final currentQuote =
              _displayQuotes[_currentIndex.clamp(0, _displayQuotes.length - 1)];
          final isSaved = savedIds.contains(currentQuote.id);
          final isLiked = likedIds.contains(currentQuote.id);

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) _armControlsFade();
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  allowImplicitScrolling: true,
                  physics: const BouncingScrollPhysics(
                    parent: PageScrollPhysics(),
                  ),
                  itemCount: _displayQuotes.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final quote = _displayQuotes[index];
                    final cleanedNames = _authorSearchCandidates(quote.author);
                    final authorLabel = cleanedNames.isEmpty
                        ? quote.author
                        : cleanedNames.first;
                    return Stack(
                      children: [
                        EditorialBackground(
                          seed: quote.id.hashCode,
                          motionScale: 0.45,
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.2, -0.55),
                                radius: 1.05,
                                colors: [
                                  viewerAccent.withValues(alpha: 0.16),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  scheme.scrim.withValues(alpha: 0.2),
                                  scheme.scrim.withValues(alpha: 0.32),
                                  scheme.scrim.withValues(alpha: 0.76),
                                ],
                                stops: const [0.08, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 86, 24, 96),
                            child: Align(
                              alignment: Alignment.center,
                              child: _QuotePanel(
                                quote: quote,
                                authorLabel: authorLabel,
                                service: service,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Row(
                          children: [
                            GlassIconButton(
                              icon: Icons.close_rounded,
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/today');
                                }
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _toggleShuffle,
                              iconSize: 24,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                _shuffleEnabled
                                    ? Icons.shuffle_on_rounded
                                    : Icons.shuffle_rounded,
                                color: _shuffleEnabled
                                    ? scheme.primary
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_currentIndex == 0 && _showHint)
                        Text(
                              'Swipe up or down',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                            .animate()
                            .fadeIn(duration: 250.ms)
                            .fadeOut(delay: 1400.ms),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassIconButton(
                                icon: Icons.info_outline,
                                size: 34,
                                onTap: () => _showWhy(context, currentQuote),
                              ),
                              const SizedBox(width: 10),
                              GlassIconButton(
                                icon: Icons.person_search_outlined,
                                size: 34,
                                onTap: () =>
                                    _showAuthorInfo(context, currentQuote),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 22,
                child: SafeArea(
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ViewerActionButton(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          tint: isLiked ? scheme.tertiary : null,
                          onTap: () => ref
                              .read(likedQuoteIdsProvider.notifier)
                              .toggle(currentQuote.id),
                        ),
                        const SizedBox(height: 8),
                        _ViewerActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline_rounded,
                          tint: isSaved ? scheme.primary : null,
                          onTap: () => ref
                              .read(savedQuoteIdsProvider.notifier)
                              .toggle(currentQuote.id),
                        ),
                        const SizedBox(height: 8),
                        _ViewerActionButton(
                          icon: Icons.send_rounded,
                          onTap: () => _shareQuote(currentQuote),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Stack(
          children: [
            EditorialBackground(motionScale: 0.45),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stack) => Stack(
          children: [
            const EditorialBackground(motionScale: 0.45),
            Center(child: Text('Failed to load viewer: $error')),
          ],
        ),
      ),
    );
  }
}

class _QuotePanel extends StatelessWidget {
  const _QuotePanel({
    required this.quote,
    required this.authorLabel,
    required this.service,
  });

  final QuoteModel quote;
  final String authorLabel;
  final QuoteService service;

  @override
  Widget build(BuildContext context) {
    final words = quote.quote
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    final quoteStyle = _quoteTextStyle(context, words);
    final showScrollableBody = words > 38;
    final normalizedTags = quote.revisedTags
        .take(3)
        .map(service.toTitleCase)
        .join(' | ');

    return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, minWidth: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFF0B1D21).withValues(alpha: 0.5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.46,
                        ),
                        child: showScrollableBody
                            ? ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: false),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Text(
                                    quote.quote,
                                    style: quoteStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : Text(
                                quote.quote,
                                style: quoteStyle,
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        authorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15,
                          letterSpacing: 0.25,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      if (normalizedTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          normalizedTags,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(key: ValueKey(quote.id))
        .fadeIn(duration: 260.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  TextStyle _quoteTextStyle(BuildContext context, int words) {
    final base = GoogleFonts.lora(
      textStyle: Theme.of(context).textTheme.headlineMedium,
      color: Colors.white.withValues(alpha: 0.98),
      fontStyle: FontStyle.normal,
    );
    if (words <= 10) {
      return base.copyWith(
        fontSize: 40,
        height: 1.24,
        fontWeight: FontWeight.w600,
      );
    }
    if (words <= 24) {
      return base.copyWith(
        fontSize: 33,
        height: 1.3,
        fontWeight: FontWeight.w600,
      );
    }
    if (words <= 42) {
      return base.copyWith(
        fontSize: 28,
        height: 1.35,
        fontWeight: FontWeight.w500,
      );
    }
    return base.copyWith(
      fontSize: 23,
      height: 1.42,
      fontWeight: FontWeight.w500,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: tint ?? Colors.white, size: 20),
        ),
      ),
    );
  }
}
