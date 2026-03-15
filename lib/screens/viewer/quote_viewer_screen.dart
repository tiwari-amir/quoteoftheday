import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/v3_background/background_theme_provider.dart';
import '../../features/v3_collections/collections_ui/add_to_collection_sheet.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/viewer_progress_provider.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import '../../features/v3_notifications/notification_providers.dart';

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
  static const int _kAnchorCycle = 1000;
  static const int _kMaxCachedCycles = 5;

  late final QuoteViewerFilter _filter;
  late final PageController _pageController;

  Timer? _hintTimer;
  Timer? _controlsTimer;
  Timer? _rewardTimer;

  int _currentIndex = 0;
  bool _showHint = true;
  bool _showControls = true;
  bool _shuffleEnabled = false;
  String? _rewardMessage;
  int _lifetimeScrolledCount = 0;
  int _lastMilestoneShown = 0;
  DateTime _lastLongQuoteAdvance = DateTime.fromMillisecondsSinceEpoch(0);

  String? _datasetSignature;
  List<QuoteModel> _sourceQuotes = const <QuoteModel>[];
  final Map<int, List<QuoteModel>> _cycleDeckCache = <int, List<QuoteModel>>{};
  final Set<String> _sessionReadQuoteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _filter = QuoteViewerFilter(
      type: widget.type,
      tag: widget.tag.toLowerCase(),
    );
    _pageController = PageController();
    _shuffleEnabled = false;
    final progress = ref.read(viewerProgressProvider);
    _lifetimeScrolledCount = progress.scrolledCount;
    _lastMilestoneShown = progress.lastMilestone;

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
    _rewardTimer?.cancel();
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
    _sessionReadQuoteIds.clear();
    _rebuildDeck(preferredQuoteId: widget.quoteId, keepCurrentQuote: false);
  }

  bool get _isPrimaryScrollFeed =>
      _filter.normalizedType == 'category' && _filter.normalizedTag == 'all';

  bool get _shouldRandomizeDeck => _shuffleEnabled || _isPrimaryScrollFeed;
  int get _cycleLength => _sourceQuotes.isEmpty ? 1 : _sourceQuotes.length;
  int get _anchorPage => _kAnchorCycle * _cycleLength;
  bool get _isAtDeckStart =>
      _sourceQuotes.isNotEmpty && _currentIndex == _anchorPage;

  List<QuoteModel> _deckForCycle(int cycle) {
    if (!_shouldRandomizeDeck) {
      return _sourceQuotes;
    }

    return _cycleDeckCache.putIfAbsent(cycle, () {
      final deck = List<QuoteModel>.from(_sourceQuotes, growable: false);
      deck.shuffle(
        Random(
          Object.hash(
            _datasetSignature,
            cycle,
            _shuffleEnabled,
            _isPrimaryScrollFeed,
          ),
        ),
      );
      return deck;
    });
  }

  void _pruneCycleCache(int aroundCycle) {
    if (_cycleDeckCache.length <= _kMaxCachedCycles) {
      return;
    }

    final orderedCycles = _cycleDeckCache.keys.toList(growable: false)
      ..sort(
        (a, b) => (a - aroundCycle).abs().compareTo((b - aroundCycle).abs()),
      );
    final keep = orderedCycles.take(_kMaxCachedCycles).toSet();
    _cycleDeckCache.removeWhere((cycle, _) => !keep.contains(cycle));
  }

  QuoteModel _quoteForPage(int page) {
    final cycle = page ~/ _cycleLength;
    final offset = page % _cycleLength;
    final deck = _deckForCycle(cycle);
    _pruneCycleCache(cycle);
    return deck[offset];
  }

  int _pageForQuote(String quoteId, {int cycle = _kAnchorCycle}) {
    final deck = _deckForCycle(cycle);
    final match = deck.indexWhere((quote) => quote.id == quoteId);
    if (match < 0) {
      return _anchorPage;
    }
    return (cycle * _cycleLength) + match;
  }

  void _rebuildDeck({String? preferredQuoteId, bool keepCurrentQuote = true}) {
    if (_sourceQuotes.isEmpty) {
      _cycleDeckCache.clear();
      _currentIndex = 0;
      return;
    }

    String? targetQuoteId = preferredQuoteId;
    if (keepCurrentQuote && _currentIndex >= 0) {
      targetQuoteId ??= _quoteForPage(_currentIndex).id;
    }

    _cycleDeckCache.clear();

    var nextIndex = _anchorPage;
    if (targetQuoteId != null) {
      nextIndex = _pageForQuote(targetQuoteId);
    }

    _currentIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentIndex);
      unawaited(_recordQuoteReadForPage(_currentIndex));
    });
  }

  Future<void> _recordQuoteReadForPage(int pageIndex) async {
    if (_sourceQuotes.isEmpty) return;
    final quoteId = _quoteForPage(pageIndex).id;
    if (!_sessionReadQuoteIds.add(quoteId)) return;

    final metRequirement = await ref
        .read(streakProvider.notifier)
        .recordQuoteRead();
    if (metRequirement) {
      await ref
          .read(notificationSettingsProvider.notifier)
          .refreshForRuntimeStateChange();
    }
  }

  Future<void> _recordScrollProgress() async {
    _lifetimeScrolledCount = await ref
        .read(viewerProgressProvider.notifier)
        .incrementScrolledCount();

    final milestone = _milestoneFor(_lifetimeScrolledCount);
    if (milestone == null || milestone <= _lastMilestoneShown) return;
    _lastMilestoneShown = milestone;
    await ref.read(viewerProgressProvider.notifier).setLastMilestone(milestone);
    _showReward(_milestoneMessage(milestone));
  }

  int? _milestoneFor(int count) {
    const fixed = <int>[5, 15, 25, 50];
    for (final milestone in fixed) {
      if (count == milestone) return milestone;
    }
    if (count > 50 && count % 50 == 0) {
      return count;
    }
    return null;
  }

  String _milestoneMessage(int count) {
    final rank = _scrollRankTitle(count);
    if (count == 5) return 'Nice start. Momentum unlocked.';
    if (count == 15) return 'You are in rhythm now.';
    if (count == 25) return 'Flow mode activated.';
    return '$rank reached - $count quotes scrolled.';
  }

  String _scrollRankTitle(int count) {
    if (count >= 1000) return 'Quote Legend';
    if (count >= 500) return 'Quote Master';
    if (count >= 250) return 'Deep Reader';
    if (count >= 100) return 'Night Scroller';
    if (count >= 50) return 'Quote Voyager';
    if (count >= 25) return 'Flow Reader';
    if (count >= 10) return 'Rising Reader';
    return 'Fresh Explorer';
  }

  void _showReward(String message) {
    _rewardTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _rewardMessage = message;
    });
    _rewardTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() => _rewardMessage = null);
    });
  }

  void _advanceFromLongQuote(int index) {
    final now = DateTime.now();
    if (now.difference(_lastLongQuoteAdvance).inMilliseconds < 420) return;
    _lastLongQuoteAdvance = now;

    if (!_pageController.hasClients) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleShuffle() {
    if (_sourceQuotes.isEmpty) return;
    final currentQuoteId = _quoteForPage(_currentIndex).id;

    setState(() {
      _shuffleEnabled = !_shuffleEnabled;
      _showControls = true;
    });
    _rebuildDeck(preferredQuoteId: currentQuoteId, keepCurrentQuote: false);
    _armControlsFade();
  }

  void _onPageChanged(int index) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      if (_currentIndex > _anchorPage) {
        _showHint = false;
      }
      _showControls = true;
    });
    _armControlsFade();
    unawaited(SystemSound.play(SystemSoundType.click));

    if (index != previousIndex) {
      unawaited(_recordScrollProgress());
      unawaited(_recordQuoteReadForPage(index));
    }
  }

  void _shareQuote(QuoteModel quote) {
    showStoryShareSheet(
      context: context,
      quote: quote,
      subject: 'QuoteFlow: Daily Scroll Quotes',
    );
  }

  void _showSourceDetails(BuildContext context, QuoteModel quote) {
    final attribution = _buildAttribution(quote);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SourceLicenseSheet(quote: quote, attribution: attribution),
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
    showAuthorInfoSheetForAuthor(
      context,
      ref,
      quote.author,
      displayAuthor: displayAuthor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final likedIds = ref.watch(likedQuoteIdsProvider);
    ref.watch(appBackgroundThemeProvider);
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
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final viewerAccent = flow?.colors.accent ?? scheme.primary;
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: quotesAsync.when(
        data: (quotes) {
          _syncQuotes(quotes);

          if (_sourceQuotes.isEmpty) {
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

          final currentQuote = _quoteForPage(_currentIndex);
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
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final quote = _quoteForPage(index);
                    final cleanedNames = _authorSearchCandidates(quote.author);
                    final authorLabel = cleanedNames.isEmpty
                        ? quote.author
                        : cleanedNames.first;
                    final media = MediaQuery.of(context);
                    final sideInset = layout.fluid(min: 18, max: 32);
                    final topInset = max(
                      layout.isTablet ? 100.0 : 88.0,
                      media.padding.top + (layout.isTablet ? 72 : 62),
                    );
                    final bottomInset = max(
                      layout.isTablet ? 128.0 : 108.0,
                      media.padding.bottom + (layout.isTablet ? 112 : 98),
                    );
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
                        Positioned(
                          left: -24,
                          right: -24,
                          bottom: -8,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(double.infinity, 220),
                              painter: _ViewerLandscapePainter(
                                accent: viewerAccent,
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              sideInset,
                              topInset,
                              sideInset,
                              bottomInset,
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: layout.isTablet
                                      ? layout.textColumnWidth + 64
                                      : layout.textColumnWidth,
                                ),
                                child: _QuotePanel(
                                  quote: quote,
                                  authorLabel: authorLabel,
                                  tags: quote.revisedTags
                                      .take(2)
                                      .toList(growable: false),
                                  onAdvanceRequested: () =>
                                      _advanceFromLongQuote(index),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: sideInset,
                          right: sideInset,
                          bottom: layout.isTablet ? 24 : 18,
                          child: SafeArea(
                            top: false,
                            child: _ReelInfoDock(
                              onSource: () =>
                                  _showSourceDetails(context, quote),
                              onAuthor: () => _showAuthorInfo(context, quote),
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
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    10,
                    layout.horizontalPadding,
                    12,
                  ),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: FlowDurations.regular,
                        child: Row(
                          children: [
                            PremiumIconPillButton(
                              icon: Icons.close_rounded,
                              label: 'Close',
                              compact: true,
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/today');
                                }
                              },
                            ),
                            const Spacer(),
                            PremiumIconPillButton(
                              icon: _shuffleEnabled
                                  ? Icons.shuffle_on_rounded
                                  : Icons.shuffle_rounded,
                              label: 'Shuffle',
                              active: _shuffleEnabled,
                              compact: true,
                              onTap: _toggleShuffle,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isAtDeckStart && _showHint)
                        Text(
                              'Swipe up or down',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                            .animate()
                            .fadeIn(duration: FlowDurations.quick)
                            .fadeOut(delay: 1400.ms),
                      const SizedBox(height: 124),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: layout.isTablet ? layout.horizontalPadding : 14,
                bottom: layout.isTablet ? 124 : 112,
                child: SafeArea(
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: FlowDurations.regular,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ViewerEdgeIconButton(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          active: isLiked,
                          activeColor: scheme.tertiary,
                          onTap: () => ref
                              .read(likedQuoteIdsProvider.notifier)
                              .toggle(currentQuote.id),
                        ),
                        const SizedBox(height: FlowSpace.sm),
                        _ViewerEdgeIconButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline_rounded,
                          active: isSaved,
                          activeColor: scheme.primary,
                          onTap: () =>
                              showSaveQuoteSheet(context, ref, currentQuote.id),
                        ),
                        const SizedBox(height: FlowSpace.sm),
                        _ViewerEdgeIconButton(
                          icon: Icons.send_rounded,
                          onTap: () => _shareQuote(currentQuote),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 72,
                left: layout.horizontalPadding,
                right: layout.horizontalPadding,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: FlowDurations.regular,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _rewardMessage == null
                        ? const SizedBox.shrink()
                        : Center(
                            key: ValueKey<String>(_rewardMessage!),
                            child:
                                PremiumSurface(
                                      radius: 999,
                                      elevation: 2,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: FlowSpace.md,
                                        vertical: FlowSpace.xs,
                                      ),
                                      child: Text(
                                        _rewardMessage!,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: FlowDurations.quick)
                                    .slideY(
                                      begin: -0.14,
                                      end: 0,
                                      curve: FlowDurations.curve,
                                    ),
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
    required this.tags,
    required this.onAdvanceRequested,
  });

  final QuoteModel quote;
  final String authorLabel;
  final List<String> tags;
  final VoidCallback onAdvanceRequested;

  @override
  Widget build(BuildContext context) {
    final words = quote.quote
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    final showScrollableBody = words > 34;

    Widget quoteBody;
    if (showScrollableBody) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      final maxHeight = (screenHeight * 0.78).clamp(400.0, 700.0);
      quoteBody = _LongQuoteBody(
        maxHeight: maxHeight.toDouble(),
        onRequestNext: onAdvanceRequested,
        child: _LongQuoteContent(
          quote: quote.quote,
          authorLabel: authorLabel,
          tags: tags,
          quoteLength: words,
        ),
      );
    } else {
      quoteBody = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.lg,
          vertical: FlowSpace.md,
        ),
        child: _LongQuoteContent(
          quote: quote.quote,
          authorLabel: authorLabel,
          tags: tags,
          quoteLength: words,
        ),
      );
    }

    return quoteBody
        .animate(key: ValueKey(quote.id))
        .fadeIn(duration: FlowDurations.regular)
        .slideY(begin: 0.05, end: 0, curve: FlowDurations.curve);
  }
}

class _ReelInfoDock extends StatelessWidget {
  const _ReelInfoDock({required this.onSource, required this.onAuthor});

  final VoidCallback onSource;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: FlowSpace.sm,
      runSpacing: FlowSpace.xs,
      children: [
        _ReelInlineAction(
          icon: Icons.person_search_outlined,
          label: 'Author',
          onTap: onAuthor,
        ),
        _ReelInlineAction(
          icon: Icons.library_books_outlined,
          label: 'Source',
          onTap: onSource,
        ),
      ],
    );
  }
}

class _ViewerEdgeIconButton extends StatelessWidget {
  const _ViewerEdgeIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final foreground = active
        ? activeColor ?? colors?.accent ?? Colors.white
        : colors?.textPrimary.withValues(alpha: 0.92) ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        highlightShape: BoxShape.circle,
        splashColor: foreground.withValues(alpha: 0.12),
        highlightColor: foreground.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 21,
            color: foreground,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: active ? 0.3 : 0.18),
                blurRadius: active ? 14 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelInlineAction extends StatelessWidget {
  const _ReelInlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final foreground =
        colors?.textSecondary.withValues(alpha: 0.86) ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.xs,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LongQuoteContent extends StatelessWidget {
  const _LongQuoteContent({
    required this.quote,
    required this.authorLabel,
    required this.tags,
    required this.quoteLength,
  });

  final String quote;
  final String authorLabel;
  final List<String> tags;
  final int quoteLength;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final quoteSize = quoteLength > 96
        ? 19.5
        : quoteLength > 72
        ? 21.0
        : quoteLength > 42
        ? 22.5
        : 26.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.lg,
        FlowSpace.md,
        FlowSpace.lg,
        FlowSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            quote,
            textAlign: TextAlign.center,
            style:
                FlowTypography.quoteStyle(
                  context: context,
                  color: colors?.textPrimary ?? Colors.white,
                  fontSize: quoteSize,
                ).copyWith(
                  height: quoteLength > 48 ? 1.52 : 1.46,
                  shadows: [
                    Shadow(
                      blurRadius: 28,
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: FlowSpace.lg),
          Text(
            authorLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors?.accentSecondary.withValues(alpha: 0.94),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: FlowSpace.xxs),
            Text(
              tags.map((tag) => tag.toUpperCase()).join('  |  '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors?.textSecondary.withValues(alpha: 0.66),
                fontSize: 10.5,
                letterSpacing: 0.48,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewerLandscapePainter extends CustomPainter {
  const _ViewerLandscapePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF08111A).withValues(alpha: 0.64),
            const Color(0xFF04070B),
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(rect),
    );

    final ridge = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.62,
        size.width * 0.34,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.5,
        size.width * 0.7,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.66,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()..color = const Color(0xFF071018).withValues(alpha: 0.96),
    );

    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.74),
      Offset(size.width * 0.56, size.height * 0.74),
      Paint()
        ..color = accent.withValues(alpha: 0.14)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _ViewerLandscapePainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _SourceLicenseSheet extends StatelessWidget {
  const _SourceLicenseSheet({required this.quote, required this.attribution});

  final QuoteModel quote;
  final _QuoteAttributionData attribution;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final layout = FlowLayoutInfo.of(context);
    final hasSourceLink = attribution.sourceUrl.isNotEmpty;
    final mutedText =
        colors?.textSecondary.withValues(alpha: 0.82) ?? Colors.white70;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.lg,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.isTablet ? 560 : double.infinity,
          ),
          child: PremiumSurface(
            radius: FlowRadii.xl,
            elevation: 3,
            blurSigma: 18,
            padding: EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: FlowRadii.radiusXl,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (colors?.surface ?? Colors.black).withValues(alpha: 0.985),
                    (colors?.elevatedSurface ?? Colors.black).withValues(
                      alpha: 0.96,
                    ),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FlowSpace.lg,
                  FlowSpace.sm,
                  FlowSpace.lg,
                  FlowSpace.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: (colors?.divider ?? Colors.white24).withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: FlowSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Source',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: mutedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: FlowSpace.xs),
                    Text(
                      quote.author,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: mutedText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.18,
                      ),
                    ),
                    const SizedBox(height: FlowSpace.md),
                    _MinimalSourceRow(
                      label: 'Origin',
                      value: attribution.sourceLabel,
                      detail: hasSourceLink
                          ? _sourceHostLabel(attribution.sourceUrl)
                          : 'Link unavailable',
                    ),
                    const SizedBox(height: FlowSpace.sm),
                    _MinimalSourceRow(
                      label: 'License',
                      value: attribution.licenseLabel,
                    ),
                    const SizedBox(height: FlowSpace.md),
                    Wrap(
                      spacing: FlowSpace.md,
                      runSpacing: FlowSpace.xs,
                      children: [
                        if (hasSourceLink)
                          _MinimalSheetAction(
                            icon: Icons.open_in_new_rounded,
                            label: 'Open source',
                            onTap: () => unawaited(
                              _openExternalUrl(attribution.sourceUrl),
                            ),
                          ),
                        _MinimalSheetAction(
                          icon: Icons.gavel_rounded,
                          label: 'View license',
                          onTap: () => unawaited(
                            _openExternalUrl(attribution.licenseUrl),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalSourceRow extends StatelessWidget {
  const _MinimalSourceRow({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors?.textSecondary.withValues(alpha: 0.74),
            letterSpacing: 0.18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detail!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.82),
            ),
          ),
        ],
      ],
    );
  }
}

class _MinimalSheetAction extends StatelessWidget {
  const _MinimalSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colors?.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color:
                      colors?.textSecondary.withValues(alpha: 0.9) ??
                      Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteAttributionData {
  const _QuoteAttributionData({
    required this.sourceUrl,
    required this.sourceLabel,
    required this.licenseLabel,
    required this.licenseUrl,
  });

  final String sourceUrl;
  final String sourceLabel;
  final String licenseLabel;
  final String licenseUrl;
}

_QuoteAttributionData _buildAttribution(QuoteModel quote) {
  final sourceUrl = quote.sourceUrl?.trim() ?? '';
  return _QuoteAttributionData(
    sourceUrl: sourceUrl,
    sourceLabel: 'Wikiquote',
    licenseLabel: 'CC BY-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
  );
}

String _sourceHostLabel(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  final host = uri?.host.trim() ?? '';
  if (host.isEmpty) return 'Original source page';
  return host.replaceFirst(RegExp(r'^www\.'), '');
}

Future<void> _openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _LongQuoteBody extends StatefulWidget {
  const _LongQuoteBody({
    required this.maxHeight,
    required this.onRequestNext,
    required this.child,
  });

  final double maxHeight;
  final VoidCallback onRequestNext;
  final Widget child;

  @override
  State<_LongQuoteBody> createState() => _LongQuoteBodyState();
}

class _LongQuoteBodyState extends State<_LongQuoteBody> {
  late final ScrollController _controller;
  double _dragAtBottomAccumulator = 0;
  int _bottomSwipeStage = 0;
  Timer? _stageResetTimer;
  Timer? _hintTimer;
  bool _showNextSwipeHint = false;
  DateTime _lastHandoff = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _stageResetTimer?.cancel();
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    final atBottom = metrics.pixels >= (metrics.maxScrollExtent - 1.5);

    if (notification is ScrollUpdateNotification) {
      if (!atBottom && metrics.extentAfter > 24) {
        _dragAtBottomAccumulator = 0;
        _resetSwipeStage();
      } else {
        final delta = notification.scrollDelta ?? 0;
        if (atBottom && delta > 0) {
          _dragAtBottomAccumulator += delta;
        }
      }
    }

    if (notification is OverscrollNotification) {
      final dragDelta = notification.dragDetails?.primaryDelta ?? 0;
      final draggingUp = dragDelta < 0;
      if (atBottom && draggingUp) {
        _dragAtBottomAccumulator +=
            notification.overscroll.abs() + dragDelta.abs();
      } else if (!atBottom) {
        _dragAtBottomAccumulator = 0;
      }
    }

    if (notification is ScrollEndNotification) {
      if (atBottom && _dragAtBottomAccumulator > 22) {
        _registerBottomSwipeAttempt();
      }
      _dragAtBottomAccumulator = 0;
    }

    return false;
  }

  void _registerBottomSwipeAttempt() {
    final now = DateTime.now();
    if (now.difference(_lastHandoff).inMilliseconds <= 360) return;
    if (_bottomSwipeStage == 0) {
      _bottomSwipeStage = 1;
      _showSwipeHint();
      _stageResetTimer?.cancel();
      _stageResetTimer = Timer(const Duration(seconds: 3), _resetSwipeStage);
      return;
    }
    _resetSwipeStage();
    _lastHandoff = now;
    widget.onRequestNext();
  }

  void _resetSwipeStage() {
    _stageResetTimer?.cancel();
    _bottomSwipeStage = 0;
  }

  void _showSwipeHint() {
    _hintTimer?.cancel();
    if (mounted) {
      setState(() => _showNextSwipeHint = true);
    }
    _hintTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() => _showNextSwipeHint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: SingleChildScrollView(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: FlowSpace.lg),
              child: widget.child,
            ),
          ),
          Positioned(
            left: FlowSpace.md,
            right: FlowSpace.md,
            bottom: FlowSpace.sm,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showNextSwipeHint ? 1 : 0,
                duration: FlowDurations.quick,
                child: Center(
                  child: Text(
                    'Drag up once more for next quote',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
