class QuoteModel {
  const QuoteModel({
    required this.id,
    required this.quote,
    required this.author,
    required this.revisedTags,
  });

  final String id;
  final String quote;
  final String author;
  final List<String> revisedTags;

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    final tags = _extractTags(json);

    return QuoteModel(
      id: (json['id'] ?? '').toString().trim(),
      quote: (json['quote'] ?? json['text'] ?? '').toString().trim(),
      author: (json['author'] ?? 'Unknown').toString().trim(),
      revisedTags: tags,
    );
  }

  static List<String> _extractTags(Map<String, dynamic> json) {
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
