class QuoteModel {
  const QuoteModel({
    required this.id,
    required this.quote,
    required this.author,
    required this.revisedTags,
    this.categories = const <String>[],
    this.moods = const <String>[],
    this.sourceUrl,
    this.license,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.likesCount = 0,
    this.popularityScore = 0,
    this.authorScore = 0,
    this.viralityScore = 0,
    this.lengthTier = '',
    this.canonicalAuthor = '',
    this.createdAt,
    this.hash = '',
  });

  final String id;
  final String quote;
  final String author;
  final List<String> revisedTags;
  final List<String> categories;
  final List<String> moods;
  final String? sourceUrl;
  final String? license;
  final int viewsCount;
  final int sharesCount;
  final int savesCount;
  final int likesCount;
  final int popularityScore;
  final double authorScore;
  final double viralityScore;
  final String lengthTier;
  final String canonicalAuthor;
  final DateTime? createdAt;
  final String hash;

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    final text = (json['quote'] ?? json['text'] ?? '').toString().trim();
    final categories = _normalizeTags(
      json['categories'] ?? json['category_tags'] ?? json['categoryTags'],
    );
    final moods = _normalizeTags(json['moods'] ?? json['mood_tags']);
    final tags = _mergeTagLists(<List<String>>[
      categories,
      moods,
      _extractLegacyTags(json),
    ]);

    return QuoteModel(
      id: (json['id'] ?? '').toString().trim(),
      quote: text,
      author: (json['author'] ?? 'Unknown').toString().trim(),
      revisedTags: tags,
      categories: categories,
      moods: moods,
      sourceUrl: _normalizeOptionalText(
        json['source_url'] ?? json['sourceUrl'],
      ),
      license: _normalizeOptionalText(json['license']),
      viewsCount: _toInt(json['views_count'] ?? json['viewsCount']),
      sharesCount: _toInt(json['shares_count'] ?? json['sharesCount']),
      savesCount: _toInt(json['saves_count'] ?? json['savesCount']),
      likesCount: _toInt(json['likes_count'] ?? json['likesCount']),
      popularityScore: _toInt(
        json['popularity_score'] ?? json['popularityScore'],
      ),
      authorScore: _toDouble(json['author_score'] ?? json['authorScore']),
      viralityScore: _toDouble(json['virality_score'] ?? json['viralityScore']),
      lengthTier:
          (_normalizeOptionalText(json['length_tier'] ?? json['lengthTier']) ??
                  '')
              .toLowerCase(),
      canonicalAuthor:
          (_normalizeOptionalText(
                    json['canonical_author'] ?? json['canonicalAuthor'],
                  ) ??
                  '')
              .toLowerCase(),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      hash: (json['hash'] ?? json['quote_hash'] ?? '').toString().trim(),
    );
  }

  QuoteModel copyWith({
    String? id,
    String? quote,
    String? author,
    List<String>? revisedTags,
    List<String>? categories,
    List<String>? moods,
    String? sourceUrl,
    String? license,
    int? viewsCount,
    int? sharesCount,
    int? savesCount,
    int? likesCount,
    int? popularityScore,
    double? authorScore,
    double? viralityScore,
    String? lengthTier,
    String? canonicalAuthor,
    DateTime? createdAt,
    String? hash,
  }) {
    return QuoteModel(
      id: id ?? this.id,
      quote: quote ?? this.quote,
      author: author ?? this.author,
      revisedTags: revisedTags ?? this.revisedTags,
      categories: categories ?? this.categories,
      moods: moods ?? this.moods,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      license: license ?? this.license,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      likesCount: likesCount ?? this.likesCount,
      popularityScore: popularityScore ?? this.popularityScore,
      authorScore: authorScore ?? this.authorScore,
      viralityScore: viralityScore ?? this.viralityScore,
      lengthTier: lengthTier ?? this.lengthTier,
      canonicalAuthor: canonicalAuthor ?? this.canonicalAuthor,
      createdAt: createdAt ?? this.createdAt,
      hash: hash ?? this.hash,
    );
  }

  static List<String> _extractLegacyTags(Map<String, dynamic> json) {
    final rawTags = json['revised_tags'] ?? json['revisedTags'];
    final directTags = _normalizeTags(rawTags);
    if (directTags.isNotEmpty) {
      return directTags;
    }

    final quoteTagsRaw = json['quote_tags'];
    if (quoteTagsRaw is! List) {
      return const [];
    }

    final tags = <String>[];
    for (final item in quoteTagsRaw) {
      if (item is! Map<String, dynamic>) continue;
      final nested = item['tags'] ?? item['tag'];
      if (nested is Map<String, dynamic>) {
        final slug = (nested['slug'] ?? '').toString().trim().toLowerCase();
        if (slug.isNotEmpty) tags.add(slug);
      }
    }

    return tags.toSet().toList(growable: false);
  }

  static List<String> _mergeTagLists(List<List<String>> parts) {
    final output = <String>[];
    final seen = <String>{};

    for (final list in parts) {
      for (final item in list) {
        final normalized = item.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (!seen.add(normalized)) continue;
        output.add(normalized);
      }
    }

    return output;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String? _normalizeOptionalText(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _normalizeTags(dynamic raw) {
    final values = <String>[];

    if (raw is List) {
      for (final item in raw) {
        final tag = item.toString().trim().toLowerCase();
        if (tag.isNotEmpty) values.add(tag);
      }
    } else if (raw is String) {
      final source = raw.trim();
      if (source.isNotEmpty) {
        final parts = source.split(RegExp(r'[,|/]'));
        for (final part in parts) {
          final tag = part.trim().toLowerCase();
          if (tag.isNotEmpty) values.add(tag);
        }
      }
    }

    return values.toSet().toList(growable: false);
  }
}
