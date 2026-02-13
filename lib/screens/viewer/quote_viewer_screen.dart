import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../models/quote_model.dart';
import '../../models/quote_viewer_filter.dart';
import '../../providers/quote_providers.dart';
import '../../providers/saved_quotes_provider.dart';
import '../../services/quote_service.dart';
import '../../widgets/animated_gradient_background.dart';
import '../../widgets/glass_icon_button.dart';

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

  final Set<String> _likedIds = <String>{};
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
    Share.share(
      '"${quote.quote}"\n\n- ${quote.author}',
      subject: 'Quote of the Day',
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

  Future<_AuthorInfo?> _fetchAuthorInfo(String author) async {
    final candidates = _authorSearchCandidates(author);
    if (candidates.isEmpty) {
      return null;
    }

    _WikipediaCandidate? bestCandidate;
    String? bestCandidateAuthor;
    var bestScore = -9999;

    for (final candidateAuthor in candidates.take(5)) {
      final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': '"$candidateAuthor"',
        'srlimit': '8',
        'format': 'json',
        'origin': '*',
      });

      final searchResponse = await http.get(searchUri);
      if (searchResponse.statusCode != 200) continue;

      final searchJson = jsonDecode(searchResponse.body);
      final searchRows =
          (((searchJson as Map<String, dynamic>)['query'] ?? {})
                  as Map<String, dynamic>)['search']
              as List<dynamic>? ??
          const [];

      final normalizedAuthor = _normalizeIdentity(candidateAuthor);
      final rows = searchRows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => _WikipediaCandidate(
              pageId: row['pageid'] as int? ?? -1,
              title: (row['title'] ?? '').toString(),
              snippet: (row['snippet'] ?? '').toString(),
            ),
          )
          .where((row) => row.pageId > 0 && row.title.isNotEmpty)
          .toList(growable: false);

      if (rows.isEmpty) continue;

      rows.sort((a, b) {
        final aScore = _scoreAuthorCandidate(
          candidate: a,
          normalizedAuthor: normalizedAuthor,
        );
        final bScore = _scoreAuthorCandidate(
          candidate: b,
          normalizedAuthor: normalizedAuthor,
        );
        return bScore.compareTo(aScore);
      });

      final localBest = rows.first;
      final score =
          _scoreAuthorCandidate(
            candidate: localBest,
            normalizedAuthor: normalizedAuthor,
          ) +
          _candidateAuthorQuality(candidateAuthor);

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = localBest;
        bestCandidateAuthor = candidateAuthor;
      }
    }

    if (bestCandidate == null ||
        bestCandidateAuthor == null ||
        bestScore < 22) {
      return null;
    }

    final detailsUri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts|pageimages|info',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'pithumbsize': '700',
      'pageids': '${bestCandidate.pageId}',
      'format': 'json',
      'origin': '*',
    });

    final detailsResponse = await http.get(detailsUri);
    if (detailsResponse.statusCode != 200) return null;

    final detailsJson =
        jsonDecode(detailsResponse.body) as Map<String, dynamic>;
    final pages =
        ((detailsJson['query'] ?? {}) as Map<String, dynamic>)['pages'];
    if (pages is! Map<String, dynamic>) return null;

    final page = pages['${bestCandidate.pageId}'];
    if (page is! Map<String, dynamic>) return null;

    final title = (page['title'] ?? bestCandidate.title).toString();
    final summary = (page['extract'] ?? '').toString().trim();
    final fullUrl = (page['fullurl'] ?? '').toString();
    final thumbnail =
        ((page['thumbnail'] as Map<String, dynamic>?)?['source'] ?? '')
            .toString();

    if (summary.isEmpty && thumbnail.isEmpty && fullUrl.isEmpty) return null;

    return _AuthorInfo(
      author: bestCandidateAuthor,
      wikiTitle: title,
      summary: summary,
      imageUrl: thumbnail.isEmpty ? null : thumbnail,
      url: fullUrl.isEmpty ? null : fullUrl,
    );
  }

  int _scoreAuthorCandidate({
    required _WikipediaCandidate candidate,
    required String normalizedAuthor,
  }) {
    var score = 0;
    final title = _normalizeIdentity(candidate.title);
    final snippet = candidate.snippet.toLowerCase();

    if (title == normalizedAuthor) {
      score += 120;
    }
    if (title.contains(normalizedAuthor) || normalizedAuthor.contains(title)) {
      score += 45;
    }

    final authorTokens = normalizedAuthor
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    final titleTokens = title.split(' ').where((t) => t.isNotEmpty).toSet();
    for (final token in authorTokens) {
      if (titleTokens.contains(token)) {
        score += 8;
      }
    }

    if (candidate.title.toLowerCase().contains('disambiguation') ||
        snippet.contains('may refer to')) {
      score -= 80;
    }

    if (snippet.contains('writer') ||
        snippet.contains('poet') ||
        snippet.contains('author') ||
        snippet.contains('philosopher') ||
        snippet.contains('speaker') ||
        snippet.contains('novelist') ||
        snippet.contains('essayist')) {
      score += 8;
    }

    return score;
  }

  List<String> _authorSearchCandidates(String rawAuthor) {
    final clean = rawAuthor.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'unknown') return const [];

    final candidates = <String>{};
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AuthorInfoSheet(
          author: displayAuthor,
          loader: () => _fetchAuthorInfo(quote.author),
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
    final quotesAsync = _filter.type.toLowerCase() == 'saved'
        ? ref.watch(allQuotesProvider).whenData((all) {
            return all
                .where((q) => savedIds.contains(q.id))
                .toList(growable: false);
          })
        : ref.watch(quotesByFilterProvider(_filter));
    final service = ref.read(quoteServiceProvider);

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
                const AnimatedGradientBackground(),
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
          final isLiked = _likedIds.contains(currentQuote.id);

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
                  physics: const SnappyPageScrollPhysics(),
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
                        AnimatedGradientBackground(
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
                                  const Color(
                                    0xFF79C7B6,
                                  ).withValues(alpha: 0.14),
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
                                  const Color(
                                    0xFF03070D,
                                  ).withValues(alpha: 0.22),
                                  const Color(
                                    0xFF03070D,
                                  ).withValues(alpha: 0.34),
                                  const Color(
                                    0xFF03070D,
                                  ).withValues(alpha: 0.78),
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
                              onTap: () => context.go('/today'),
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
                                    ? const Color(0xFF2FC79F)
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
                          tint: isLiked ? const Color(0xFFFF6B8A) : null,
                          onTap: () {
                            setState(() {
                              if (!_likedIds.add(currentQuote.id)) {
                                _likedIds.remove(currentQuote.id);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _ViewerActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline_rounded,
                          tint: isSaved ? const Color(0xFF3FD6FF) : null,
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
            AnimatedGradientBackground(motionScale: 0.45),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stack) => Stack(
          children: [
            const AnimatedGradientBackground(motionScale: 0.45),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x44E7FFF7), Color(0x2ECAEFE2)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
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
                        ? Scrollbar(
                            radius: const Radius.circular(10),
                            thumbVisibility: true,
                            child: SingleChildScrollView(
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

class _AuthorInfoSheet extends StatelessWidget {
  const _AuthorInfoSheet({required this.author, required this.loader});

  final String author;
  final Future<_AuthorInfo?> Function() loader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF14171D),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if ((details.primaryDelta ?? 0) > 8) {
                      Navigator.of(context).pop();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 220) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_AuthorInfo?>(
                    future: loader(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 46),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final info = snapshot.data;
                      if (info == null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No reliable Wikipedia match found for this author.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (info.imageUrl != null)
                              _AuthorImageCard(imageUrl: info.imageUrl!),
                            if (info.imageUrl != null)
                              const SizedBox(height: 12),
                            Text(
                              info.wikiTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              info.summary.isEmpty
                                  ? 'Wikipedia entry found, but summary is unavailable.'
                                  : info.summary,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorInfo {
  const _AuthorInfo({
    required this.author,
    required this.wikiTitle,
    required this.summary,
    this.imageUrl,
    this.url,
  });

  final String author;
  final String wikiTitle;
  final String summary;
  final String? imageUrl;
  final String? url;
}

class _AuthorImageCard extends StatelessWidget {
  const _AuthorImageCard({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320, minHeight: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0D1620)),
          Image.network(
            imageUrl,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WikipediaCandidate {
  const _WikipediaCandidate({
    required this.pageId,
    required this.title,
    required this.snippet,
  });

  final int pageId;
  final String title;
  final String snippet;
}

class SnappyPageScrollPhysics extends PageScrollPhysics {
  const SnappyPageScrollPhysics({super.parent});

  @override
  SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingDistance => 8.0;

  @override
  double get minFlingVelocity => 80.0;
}
