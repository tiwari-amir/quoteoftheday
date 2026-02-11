class QuoteModel {
  const QuoteModel({
    required this.id,
    required this.quote,
    required this.author,
    required this.revisedTags,
  });

  final int id;
  final String quote;
  final String author;
  final List<String> revisedTags;

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    final tagsRaw =
        (json['revisedTags'] as List<dynamic>? ?? <dynamic>[])
            .map((tag) => tag.toString().trim().toLowerCase())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return QuoteModel(
      id: (json['id'] as num).toInt(),
      quote: (json['quote'] ?? '').toString().trim(),
      author: (json['author'] ?? 'Unknown').toString().trim(),
      revisedTags: tagsRaw,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quote': quote,
    'author': author,
    'revisedTags': revisedTags,
  };
}
