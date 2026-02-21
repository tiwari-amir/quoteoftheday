import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/quote_model.dart';

class FreeMediaQuotesService {
  FreeMediaQuotesService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<QuoteModel>> _cacheByCategorySet =
      <String, List<QuoteModel>>{};
  final Map<String, Future<List<QuoteModel>>> _inFlightByCategorySet =
      <String, Future<List<QuoteModel>>>{};

  static const Map<String, List<String>> _wikiquotePagesByCategory = {
    'movies': [
      'The Matrix',
      'The Dark Knight',
      'Interstellar (film)',
      'The Godfather',
      'Gladiator (2000 film)',
    ],
    'series': [
      'Friends',
      'Breaking Bad',
      'Game of Thrones',
      'The Office (American TV series)',
      'Sherlock (TV series)',
    ],
  };

  Future<List<QuoteModel>> fetchQuotesForCategories({
    required Set<String> categories,
    int maxPerCategory = 14,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final normalized = categories.map((c) => c.trim().toLowerCase()).toSet();
    final mediaCategories = normalized.where(
      _wikiquotePagesByCategory.containsKey,
    );
    if (mediaCategories.isEmpty) return const <QuoteModel>[];

    final key = _setKey(mediaCategories);
    final cached = _cacheByCategorySet[key];
    if (cached != null) {
      return cached;
    }

    final inFlight = _inFlightByCategorySet[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchQuotesForCategoriesInternal(
      categories: mediaCategories.toSet(),
      maxPerCategory: maxPerCategory,
      timeout: timeout,
    );
    _inFlightByCategorySet[key] = future;

    try {
      final quotes = await future;
      _cacheByCategorySet[key] = quotes;
      return quotes;
    } finally {
      _inFlightByCategorySet.remove(key);
    }
  }

  Future<List<QuoteModel>> _fetchQuotesForCategoriesInternal({
    required Set<String> categories,
    required int maxPerCategory,
    required Duration timeout,
  }) async {
    final mediaCategories = categories.where(_wikiquotePagesByCategory.containsKey);

    final output = <QuoteModel>[];
    for (final category in mediaCategories) {
      final pages = _wikiquotePagesByCategory[category] ?? const <String>[];
      if (pages.isEmpty) continue;

      final pageResults = await Future.wait(
        pages.map(
          (page) => _fetchWikiquotePage(
            page: page,
            category: category,
            timeout: timeout,
          ),
        ),
      );

      final categoryQuotes = <QuoteModel>[
        for (final quotes in pageResults) ...quotes,
      ];
      output.addAll(categoryQuotes.take(maxPerCategory));
    }

    return _dedupeQuotes(output);
  }

  String _setKey(Iterable<String> values) {
    final sorted = values
        .map((v) => v.trim().toLowerCase())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return sorted.join('|');
  }

  Future<List<QuoteModel>> _fetchWikiquotePage({
    required String page,
    required String category,
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.https('en.wikiquote.org', '/w/api.php', {
        'action': 'parse',
        'page': page,
        'prop': 'text',
        'format': 'json',
        'origin': '*',
      });

      final response = await _client
          .get(
            uri,
            headers: const {'User-Agent': 'QuoteFlow/1.4 (Wikiquote source)'},
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return const <QuoteModel>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const <QuoteModel>[];
      }

      final parse = decoded['parse'];
      if (parse is! Map<String, dynamic>) {
        return const <QuoteModel>[];
      }

      final textMap = parse['text'];
      if (textMap is! Map<String, dynamic>) {
        return const <QuoteModel>[];
      }

      final html = (textMap['*'] ?? '').toString();
      if (html.isEmpty) return const <QuoteModel>[];

      final pageTitle = (parse['title'] ?? page).toString().trim();
      final lines = _extractQuoteLines(html);
      if (lines.isEmpty) return const <QuoteModel>[];

      final models = <QuoteModel>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final split = _splitSpeaker(line);
        final quoteText = split.quote;
        if (quoteText.isEmpty) continue;
        final author = split.speaker == null
            ? pageTitle
            : '${split.speaker} - $pageTitle';

        final id = _quoteId(
          source: 'wikiquote',
          page: pageTitle,
          index: i,
          text: quoteText,
        );

        models.add(
          QuoteModel(
            id: id,
            quote: quoteText,
            author: author,
            revisedTags: <String>[category],
          ),
        );
      }

      return models;
    } catch (error, stack) {
      debugPrint('Wikiquote fetch failed for $page: $error');
      debugPrint('$stack');
      return const <QuoteModel>[];
    }
  }

  List<String> _extractQuoteLines(String html) {
    final area = _extractLikelyQuotesArea(html);
    final itemRegex = RegExp(
      r'<li(?:\s[^>]*)?>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final nestedListRegex = RegExp(
      r'<(ul|ol)(?:\s[^>]*)?>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    );
    final supRegex = RegExp(
      r'<sup(?:\s[^>]*)?>.*?</sup>',
      caseSensitive: false,
      dotAll: true,
    );

    final output = <String>[];
    for (final match in itemRegex.allMatches(area)) {
      var line = match.group(1) ?? '';
      line = line.replaceAll(nestedListRegex, ' ');
      line = line.replaceAll(supRegex, ' ');
      line = _stripHtml(line);
      line = _decodeHtmlEntities(line);
      line = line.replaceAll(RegExp(r'\[[0-9]+\]'), ' ');
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (_isLikelyQuoteLine(line)) {
        output.add(line);
      }
      if (output.length >= 40) break;
    }

    return output;
  }

  String _extractLikelyQuotesArea(String html) {
    final heading = RegExp(
      r'<h2(?:\s[^>]*)?>.*?(quote|dialogue|episode|saying).*?</h2>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (heading == null) return html;
    final afterHeading = html.substring(heading.end);
    final nextHeading = RegExp(
      r'<h2(?:\s[^>]*)?>',
      caseSensitive: false,
    ).firstMatch(afterHeading);
    if (nextHeading == null) return afterHeading;
    return afterHeading.substring(0, nextHeading.start);
  }

  bool _isLikelyQuoteLine(String value) {
    final clean = value.trim();
    if (clean.length < 16 || clean.length > 280) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(clean)) return false;

    final lowered = clean.toLowerCase();
    if (lowered.startsWith('see also') ||
        lowered.startsWith('external links') ||
        lowered.startsWith('source:') ||
        lowered.contains('http://') ||
        lowered.contains('https://') ||
        lowered.contains('wikipedia') ||
        lowered.contains('imdb') ||
        lowered.contains('season ') ||
        lowered.contains('episode ')) {
      return false;
    }

    if (clean.endsWith(':')) return false;
    return true;
  }

  _QuoteSpeakerSplit _splitSpeaker(String raw) {
    final index = raw.indexOf(':');
    if (index <= 0 || index > 30) {
      return _QuoteSpeakerSplit(quote: raw.trim(), speaker: null);
    }
    final speaker = raw.substring(0, index).trim();
    final quote = raw.substring(index + 1).trim();
    if (quote.length < 10 || speaker.length < 2 || speaker.length > 30) {
      return _QuoteSpeakerSplit(quote: raw.trim(), speaker: null);
    }
    if (!RegExp(r"^[A-Za-z0-9 .'\-]+$").hasMatch(speaker)) {
      return _QuoteSpeakerSplit(quote: raw.trim(), speaker: null);
    }
    return _QuoteSpeakerSplit(quote: quote, speaker: speaker);
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _decodeHtmlEntities(String input) {
    return input.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
      match,
    ) {
      final code = match.group(1) ?? '';
      if (code.startsWith('#x') || code.startsWith('#X')) {
        final value = int.tryParse(code.substring(2), radix: 16);
        return value == null ? match.group(0)! : String.fromCharCode(value);
      }
      if (code.startsWith('#')) {
        final value = int.tryParse(code.substring(1));
        return value == null ? match.group(0)! : String.fromCharCode(value);
      }
      return switch (code) {
        'amp' => '&',
        'quot' => '"',
        'apos' => "'",
        'lt' => '<',
        'gt' => '>',
        'nbsp' => ' ',
        'hellip' => '...',
        'ndash' => '-',
        'mdash' => '-',
        _ => match.group(0)!,
      };
    });
  }

  String _quoteId({
    required String source,
    required String page,
    required int index,
    required String text,
  }) {
    final normalized = '$source|$page|$index|$text';
    final hash = normalized.codeUnits.fold<int>(
      0,
      (previous, codeUnit) => (previous * 31 + codeUnit) & 0x7fffffff,
    );
    return 'free-$hash';
  }

  List<QuoteModel> _dedupeQuotes(List<QuoteModel> input) {
    final seen = <String>{};
    final output = <QuoteModel>[];
    for (final quote in input) {
      final key = '${quote.quote}|${quote.author}'.toLowerCase();
      if (!seen.add(key)) continue;
      output.add(quote);
    }
    return output;
  }
}

class _QuoteSpeakerSplit {
  const _QuoteSpeakerSplit({required this.quote, required this.speaker});

  final String quote;
  final String? speaker;
}
