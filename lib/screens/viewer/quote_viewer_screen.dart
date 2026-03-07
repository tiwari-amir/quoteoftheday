import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/v3_audio/ambient_audio_controller.dart';
import '../../features/v3_background/background_theme_provider.dart';
import '../../features/v3_share/story_share_sheet.dart';
import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/liked_quotes_provider.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../providers/viewer_progress_provider.dart';
import '../../services/author_wiki_service.dart';
import '../../services/quote_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/adaptive_author_image.dart';
import '../../widgets/author_info_sheet.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';

final _viewerAuthorProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      final normalized = author.trim();
      if (normalized.isEmpty) return null;
      return ref.read(authorWikiServiceProvider).fetchAuthor(normalized);
    });

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
  List<QuoteModel> _displayQuotes = const <QuoteModel>[];

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
    _rebuildDeck(preferredQuoteId: widget.quoteId, keepCurrentQuote: false);
  }

  bool get _isPrimaryScrollFeed =>
      _filter.normalizedType == 'category' && _filter.normalizedTag == 'all';

  bool get _shouldRandomizeDeck => _shuffleEnabled || _isPrimaryScrollFeed;

  List<QuoteModel> _buildDeckForCurrentMode() {
    if (_shouldRandomizeDeck) {
      return _nextShuffleCycle();
    }
    return List<QuoteModel>.from(_sourceQuotes, growable: false);
  }

  void _rebuildDeck({String? preferredQuoteId, bool keepCurrentQuote = true}) {
    if (_sourceQuotes.isEmpty) {
      _displayQuotes = const <QuoteModel>[];
      _currentIndex = 0;
      return;
    }

    _displayQuotes = _buildDeckForCurrentMode();

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

    final nextIndex = index + 1;
    if (nextIndex >= _displayQuotes.length) {
      final nextCycle = _buildDeckForCurrentMode();
      setState(() {
        _displayQuotes = [..._displayQuotes, ...nextCycle];
      });
    }

    if (!_pageController.hasClients) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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
        final restored = _buildDeckForCurrentMode();
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
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      if (_currentIndex > 0) {
        _showHint = false;
      }
      _showControls = true;
    });
    _armControlsFade();
    unawaited(SystemSound.play(SystemSoundType.click));

    if (index != previousIndex) {
      unawaited(_recordScrollProgress());
    }

    if (index == _displayQuotes.length - 1) {
      final nextCycle = _buildDeckForCurrentMode();
      setState(() {
        _displayQuotes = [..._displayQuotes, ...nextCycle];
      });
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
    final ambientAudio = ref.watch(ambientAudioProvider);

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
                    final media = MediaQuery.of(context);
                    final topInset = max(70.0, media.padding.top + 52);
                    final bottomInset = max(82.0, media.padding.bottom + 72);
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
                            padding: EdgeInsets.fromLTRB(
                              24,
                              topInset,
                              24,
                              bottomInset,
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: _QuotePanel(
                                quote: quote,
                                authorLabel: authorLabel,
                                service: service,
                                onAdvanceRequested: () =>
                                    _advanceFromLongQuote(index),
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
                  padding: const EdgeInsets.fromLTRB(
                    FlowSpace.md,
                    10,
                    FlowSpace.md,
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
                              icon: ambientAudio.muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              compact: true,
                              onTap: () => ref
                                  .read(ambientAudioProvider.notifier)
                                  .toggleMute(),
                            ),
                            const SizedBox(width: FlowSpace.xs),
                            PremiumIconPillButton(
                              icon: _shuffleEnabled
                                  ? Icons.shuffle_on_rounded
                                  : Icons.shuffle_rounded,
                              active: _shuffleEnabled,
                              compact: true,
                              onTap: _toggleShuffle,
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
                            .fadeIn(duration: FlowDurations.quick)
                            .fadeOut(delay: 1400.ms),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: FlowDurations.regular,
                        child: Padding(
                          padding: const EdgeInsets.only(top: FlowSpace.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PremiumIconPillButton(
                                icon: Icons.library_books_outlined,
                                label: 'Source',
                                compact: true,
                                onTap: () =>
                                    _showSourceDetails(context, currentQuote),
                              ),
                              const SizedBox(width: FlowSpace.xs),
                              PremiumIconPillButton(
                                icon: Icons.person_search_outlined,
                                compact: true,
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
                top: 72,
                left: 22,
                right: 22,
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
              Positioned(
                right: 10,
                bottom: 22,
                child: SafeArea(
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: FlowDurations.regular,
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
                        const SizedBox(height: FlowSpace.xs),
                        _ViewerActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline_rounded,
                          tint: isSaved ? scheme.primary : null,
                          onTap: () => ref
                              .read(savedQuoteIdsProvider.notifier)
                              .toggle(currentQuote.id),
                        ),
                        const SizedBox(height: FlowSpace.xs),
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
    required this.onAdvanceRequested,
  });

  final QuoteModel quote;
  final String authorLabel;
  final QuoteService service;
  final VoidCallback onAdvanceRequested;

  @override
  Widget build(BuildContext context) {
    final words = quote.quote
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    final showScrollableBody = words > 36;
    final tagLabels = quote.revisedTags
        .take(3)
        .map(service.toTitleCase)
        .toList(growable: false);

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
          tagLabels: tagLabels,
        ),
      );
    } else {
      quoteBody = QuoteSurface(
        quote: quote.quote,
        author: authorLabel,
        eyebrow: 'QUOTE',
        footer: _QuoteAttributionFooter(
          authorLabel: authorLabel,
          tagLabels: tagLabels,
        ),
      );
    }

    return quoteBody
        .animate(key: ValueKey(quote.id))
        .fadeIn(duration: FlowDurations.regular)
        .slideY(begin: 0.05, end: 0, curve: FlowDurations.curve);
  }
}

class _LongQuoteContent extends StatelessWidget {
  const _LongQuoteContent({
    required this.quote,
    required this.authorLabel,
    required this.tagLabels,
  });

  final String quote;
  final String authorLabel;
  final List<String> tagLabels;

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    final words = quote
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    final quoteSize = words > 96
        ? 19.0
        : words > 72
        ? 20.0
        : 22.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.lg,
        FlowSpace.md,
        FlowSpace.lg,
        FlowSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'QUOTE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.92),
              letterSpacing: 0.46,
            ),
          ),
          const SizedBox(height: FlowSpace.xs),
          Text(
            '"',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.34),
              height: 0.68,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            quote,
            textAlign: TextAlign.center,
            style:
                FlowTypography.quoteStyle(
                  color: colors?.textPrimary ?? Colors.white,
                  fontSize: quoteSize,
                ).copyWith(
                  height: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 20,
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: FlowSpace.lg),
          Container(
            height: 1,
            width: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  colors?.divider.withValues(alpha: 0.9) ??
                      Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          _InlineAuthorPortrait(
            author: authorLabel,
            size: 58,
            bottomSpacing: FlowSpace.sm,
          ),
          Text(
            authorLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors?.textSecondary ?? Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.24,
            ),
            textAlign: TextAlign.center,
          ),
          if (tagLabels.isNotEmpty) ...[
            const SizedBox(height: FlowSpace.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: FlowSpace.xs,
              runSpacing: FlowSpace.xs,
              children: [
                for (final tag in tagLabels)
                  _ViewerMetaChip(
                    label: tag,
                    icon: Icons.sell_outlined,
                    compact: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: FlowSpace.md),
        ],
      ),
    );
  }
}

class _QuoteAttributionFooter extends StatelessWidget {
  const _QuoteAttributionFooter({
    required this.authorLabel,
    required this.tagLabels,
  });

  final String authorLabel;
  final List<String> tagLabels;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InlineAuthorPortrait(
          author: authorLabel,
          size: 46,
          bottomSpacing: tagLabels.isNotEmpty ? FlowSpace.sm : 0,
        ),
        if (tagLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: FlowSpace.xxs),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: FlowSpace.xs,
              runSpacing: FlowSpace.xs,
              children: [
                for (final tag in tagLabels)
                  _ViewerMetaChip(
                    label: tag,
                    icon: Icons.sell_outlined,
                    compact: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SourceLicenseSheet extends StatelessWidget {
  const _SourceLicenseSheet({required this.quote, required this.attribution});

  final QuoteModel quote;
  final _QuoteAttributionData attribution;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final hasSourceLink = attribution.sourceUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.lg,
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
                (colors?.surface ?? Colors.black).withValues(alpha: 0.98),
                (colors?.elevatedSurface ?? Colors.black).withValues(
                  alpha: 0.94,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: (colors?.divider ?? Colors.white24).withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: FlowSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.16,
                        ),
                      ),
                      child: Icon(
                        Icons.library_books_outlined,
                        color: colors?.accent,
                      ),
                    ),
                    const SizedBox(width: FlowSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Source & license',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: FlowSpace.xxs),
                          Text(
                            'Review where this quote came from and the reuse terms attached to the imported record.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors?.textSecondary.withValues(
                                    alpha: 0.94,
                                  ),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FlowSpace.md),
                PremiumSurface(
                  radius: FlowRadii.lg,
                  elevation: 1,
                  padding: const EdgeInsets.fromLTRB(
                    FlowSpace.md,
                    FlowSpace.md,
                    FlowSpace.md,
                    FlowSpace.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.quote,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      Text(
                        quote.author,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors?.textSecondary.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FlowSpace.md),
                _SourceDetailCard(
                  icon: Icons.library_books_outlined,
                  title: attribution.sourceLabel,
                  eyebrow: 'Origin',
                  description: hasSourceLink
                      ? 'This record points back to the original Wikiquote page so the wording and surrounding context can be verified.'
                      : 'This quote was imported from Wikiquote, but this record does not currently include a direct page URL.',
                  detailLabel: hasSourceLink
                      ? _sourceHostLabel(attribution.sourceUrl)
                      : 'Direct source link unavailable',
                  actionLabel: hasSourceLink ? 'Open source page' : null,
                  onAction: hasSourceLink
                      ? () => unawaited(_openExternalUrl(attribution.sourceUrl))
                      : null,
                ),
                const SizedBox(height: FlowSpace.sm),
                _SourceDetailCard(
                  icon: Icons.verified_outlined,
                  title: attribution.licenseLabel,
                  eyebrow: 'Reuse terms',
                  description:
                      'This material is distributed under the Creative Commons Attribution-ShareAlike 4.0 license. Sharing and adaptation generally require attribution, and remixed versions should stay under the same license family.',
                  detailLabel:
                      'Review the full license terms for exact requirements',
                  actionLabel: 'Open license details',
                  onAction: () =>
                      unawaited(_openExternalUrl(attribution.licenseUrl)),
                ),
                const SizedBox(height: FlowSpace.md),
                Wrap(
                  spacing: FlowSpace.xs,
                  runSpacing: FlowSpace.xs,
                  children: [
                    if (hasSourceLink)
                      PremiumIconPillButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'Source page',
                        compact: true,
                        onTap: () =>
                            unawaited(_openExternalUrl(attribution.sourceUrl)),
                      ),
                    PremiumIconPillButton(
                      icon: Icons.gavel_rounded,
                      label: 'License',
                      compact: true,
                      onTap: () =>
                          unawaited(_openExternalUrl(attribution.licenseUrl)),
                    ),
                    PremiumIconPillButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      compact: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceDetailCard extends StatelessWidget {
  const _SourceDetailCard({
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.detailLabel,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String eyebrow;
  final String description;
  final String detailLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return PremiumSurface(
      radius: FlowRadii.lg,
      elevation: 1,
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
        FlowSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (colors?.accent ?? Colors.white).withValues(
                    alpha: 0.14,
                  ),
                ),
                child: Icon(icon, size: 18, color: colors?.accent),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors?.textSecondary.withValues(alpha: 0.82),
                      ),
                    ),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors?.textSecondary.withValues(alpha: 0.94),
              height: 1.48,
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          _ViewerMetaChip(
            label: detailLabel,
            icon: Icons.info_outline_rounded,
            compact: true,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: FlowSpace.sm),
            PremiumIconPillButton(
              icon: Icons.open_in_new_rounded,
              label: actionLabel,
              compact: true,
              onTap: onAction!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineAuthorPortrait extends ConsumerWidget {
  const _InlineAuthorPortrait({
    required this.author,
    required this.size,
    this.bottomSpacing = 0,
  });

  final String author;
  final double size;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedAuthor = author.trim();
    if (normalizedAuthor.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final profileAsync = ref.watch(
      _viewerAuthorProfileProvider(normalizedAuthor),
    );

    return profileAsync.when(
      data: (profile) {
        final imageUrl = profile?.imageUrl?.trim();
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;
        if (!hasImage) {
          return const SizedBox.shrink();
        }

        final outerSize = size + 12;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                showAuthorInfoSheetForAuthor(context, ref, normalizedAuthor),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomSpacing),
              child: SizedBox(
                width: outerSize,
                height: outerSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: outerSize,
                      height: outerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (colors?.accent ?? Colors.white).withValues(
                              alpha: 0.18,
                            ),
                            (colors?.accent ?? Colors.white).withValues(
                              alpha: 0.08,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.12, 0.52, 1.0],
                        ),
                      ),
                    ),
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (colors?.accent ?? Colors.white).withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AdaptiveAuthorImage(
                          imageUrl: imageUrl,
                          placeholder: _PortraitFallback(colors: colors),
                          error: _PortraitFallback(colors: colors),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.colors});

  final FlowColorTokens? colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors?.surface.withValues(alpha: 0.92) ?? Colors.black54,
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 22,
          color: colors?.textSecondary.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _ViewerMetaChip extends StatelessWidget {
  const _ViewerMetaChip({
    required this.label,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: compact ? 11.5 : 13,
          color:
              colors?.textSecondary.withValues(alpha: 0.84) ?? Colors.white70,
        ),
        SizedBox(width: compact ? 5 : 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                colors?.textSecondary.withValues(alpha: 0.84) ?? Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 10.2 : null,
            letterSpacing: compact ? 0.12 : 0.18,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? FlowSpace.xs + 2 : FlowSpace.sm,
          vertical: compact ? 5.5 : 7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: (colors?.surface ?? Colors.black).withValues(alpha: 0.38),
          border: Border.all(
            color: (colors?.divider ?? Colors.white24).withValues(alpha: 0.55),
          ),
        ),
        child: content,
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
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;
    return SizedBox(
      height: widget.maxHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: FlowRadii.radiusXl,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors?.quoteFrame.withValues(alpha: 0.95) ??
                  Colors.white.withValues(alpha: 0.08),
              colors?.surface.withValues(alpha: 0.78) ??
                  Colors.black.withValues(alpha: 0.24),
            ],
          ),
          border: Border.all(
            color:
                colors?.quoteFrameBorder.withValues(alpha: 0.88) ??
                Colors.white.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  colors?.quoteFrameGlow.withValues(alpha: 0.24) ??
                  Colors.black.withValues(alpha: 0.22),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
            ...?flow?.shadows.level2,
          ],
        ),
        child: ClipRRect(
          borderRadius: FlowRadii.radiusXl,
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
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (colors?.surface ?? Colors.black).withValues(
                            alpha: 0.24,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          (colors?.surface ?? Colors.black).withValues(
                            alpha: 0.3,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
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
                      child: PremiumSurface(
                        radius: 999,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FlowSpace.sm,
                          vertical: FlowSpace.xs,
                        ),
                        child: Text(
                          'Drag up once more for next quote',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
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
            color: colors?.surface.withValues(alpha: 0.85),
            border: Border.all(
              color:
                  colors?.divider.withValues(alpha: 0.95) ??
                  Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: tint ?? colors?.textPrimary ?? Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}
