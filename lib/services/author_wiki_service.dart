import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthorWikiProfile {
  const AuthorWikiProfile({
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

class AuthorWikiService {
  static const Map<String, String> _aliases = {
    'osho': 'Rajneesh',
    'ghandi': 'Mahatma Gandhi',
    'lao tzu': 'Laozi',
    'rumi': 'Jalal ad-Din Muhammad Rumi',
    'plato, the republic': 'Plato',
  };

  static const List<String> _biographyHints = [
    'writer',
    'poet',
    'author',
    'philosopher',
    'novelist',
    'essayist',
    'teacher',
    'mystic',
    'spiritual',
    'born',
  ];

  Future<AuthorWikiProfile?> fetchAuthor(String author) async {
    final candidates = searchCandidates(author);
    if (candidates.isEmpty) return null;

    _WikiCandidate? best;
    var bestAuthor = '';
    var bestScore = -99999;

    for (final candidateAuthor in candidates.take(5)) {
      final rows = await _searchWikipedia(candidateAuthor);
      if (rows.isEmpty) continue;

      final normalized = _normalize(candidateAuthor);
      rows.sort((a, b) {
        final aScore = _scoreCandidate(a, normalized);
        final bScore = _scoreCandidate(b, normalized);
        return bScore.compareTo(aScore);
      });

      final current = rows.first;
      final score =
          _scoreCandidate(current, normalized) +
          _candidateQuality(candidateAuthor);
      if (score > bestScore) {
        bestScore = score;
        best = current;
        bestAuthor = candidateAuthor;
      }
    }

    if (best == null || bestScore < 25) return null;

    final detailsUri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts|pageimages|info|categories',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'pithumbsize': '700',
      'cllimit': '12',
      'pageids': '${best.pageId}',
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

    final page = pages['${best.pageId}'];
    if (page is! Map<String, dynamic>) return null;

    final title = (page['title'] ?? best.title).toString();
    final summary = (page['extract'] ?? '').toString().trim();
    final fullUrl = (page['fullurl'] ?? '').toString();
    final thumbnail =
        ((page['thumbnail'] as Map<String, dynamic>?)?['source'] ?? '')
            .toString();

    final categories = ((page['categories'] ?? const []) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['title'] ?? '').toString().toLowerCase())
        .toList(growable: false);

    if (!_isLikelyPerson(
      title: title,
      summary: summary,
      categories: categories,
      normalizedAuthor: _normalize(bestAuthor),
    )) {
      return null;
    }

    if (summary.isEmpty && thumbnail.isEmpty && fullUrl.isEmpty) return null;

    return AuthorWikiProfile(
      author: bestAuthor,
      wikiTitle: title,
      summary: summary,
      imageUrl: thumbnail.isEmpty ? null : thumbnail,
      url: fullUrl.isEmpty ? null : fullUrl,
    );
  }

  List<String> searchCandidates(String rawAuthor) {
    final clean = rawAuthor.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'unknown') return const [];

    final alias = _aliases[_normalize(clean)];
    final seeded = alias ?? clean;

    final candidates = <String>{};
    candidates.add(_sanitize(seeded));

    for (final sep in [',', ' & ', ' and ', ' - ', '|', ';', ':']) {
      if (!seeded.contains(sep)) continue;
      final left = seeded.split(sep).first.trim();
      if (left.isNotEmpty) candidates.add(_sanitize(left));
    }

    final withoutParens = seeded.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    if (withoutParens.isNotEmpty) {
      candidates.add(_sanitize(withoutParens));
    }

    final list = candidates.where((c) => c.isNotEmpty).toList(growable: false)
      ..sort((a, b) => _candidateQuality(b).compareTo(_candidateQuality(a)));
    return list;
  }

  Future<List<_WikiCandidate>> _searchWikipedia(String author) async {
    final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': '"$author"',
      'srlimit': '8',
      'format': 'json',
      'origin': '*',
    });

    final response = await http.get(searchUri);
    if (response.statusCode != 200) return const [];

    final searchJson = jsonDecode(response.body);
    final rows =
        (((searchJson as Map<String, dynamic>)['query'] ?? {})
                as Map<String, dynamic>)['search']
            as List<dynamic>? ??
        const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => _WikiCandidate(
            pageId: row['pageid'] as int? ?? -1,
            title: (row['title'] ?? '').toString(),
            snippet: (row['snippet'] ?? '').toString(),
          ),
        )
        .where((row) => row.pageId > 0 && row.title.isNotEmpty)
        .toList(growable: false);
  }

  int _scoreCandidate(_WikiCandidate candidate, String normalizedAuthor) {
    var score = 0;
    final title = _normalize(candidate.title);
    final snippet = candidate.snippet.toLowerCase();

    if (title == normalizedAuthor) score += 120;
    if (title.contains(normalizedAuthor) || normalizedAuthor.contains(title)) {
      score += 40;
    }

    final authorTokens = normalizedAuthor
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    final titleTokens = title.split(' ').where((t) => t.isNotEmpty).toSet();
    for (final token in authorTokens) {
      if (titleTokens.contains(token)) score += 8;
    }

    if (candidate.title.toLowerCase().contains('disambiguation') ||
        snippet.contains('may refer to')) {
      score -= 80;
    }

    for (final hint in _biographyHints) {
      if (snippet.contains(hint)) score += 7;
    }

    return score;
  }

  bool _isLikelyPerson({
    required String title,
    required String summary,
    required List<String> categories,
    required String normalizedAuthor,
  }) {
    final normalizedTitle = _normalize(title);
    if (normalizedTitle.isEmpty || normalizedAuthor.isEmpty) return false;

    if (normalizedTitle.contains('disambiguation')) return false;

    final summaryLower = summary.toLowerCase();
    if (summaryLower.contains('may refer to')) return false;

    final hasBioHint = _biographyHints.any(summaryLower.contains);
    final hasPeopleCategory = categories.any(
      (c) =>
          c.contains(' births') ||
          c.contains(' deaths') ||
          c.contains('people') ||
          c.contains('writers') ||
          c.contains('philosophers') ||
          c.contains('poets'),
    );

    final authorTokens = normalizedAuthor
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    final titleTokens = normalizedTitle
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    final overlap = authorTokens.where(titleTokens.contains).length;

    if (overlap == 0) return false;
    return hasBioHint || hasPeopleCategory || overlap >= 2;
  }

  int _candidateQuality(String candidate) {
    final normalized = _normalize(candidate);
    if (normalized.isEmpty) return -100;

    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    var score = 0;
    if (tokens.length >= 2 && tokens.length <= 5) {
      score += 12;
    } else if (tokens.length == 1 || tokens.length > 7) {
      score -= 8;
    }

    if (RegExp(r'\d').hasMatch(normalized)) score -= 20;

    const noise = {
      'the',
      'a',
      'an',
      'of',
      'book',
      'novel',
      'quotes',
      'collection',
    };
    for (final token in tokens) {
      if (noise.contains(token)) score -= 5;
    }

    return score;
  }

  String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-\s]+'), '')
        .replaceAll(RegExp(r'[\-\s]+$'), '')
        .trim();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _WikiCandidate {
  const _WikiCandidate({
    required this.pageId,
    required this.title,
    required this.snippet,
  });

  final int pageId;
  final String title;
  final String snippet;
}
