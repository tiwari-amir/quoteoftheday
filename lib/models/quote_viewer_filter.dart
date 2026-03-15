class QuoteViewerFilter {
  const QuoteViewerFilter({required this.type, required this.tag});

  final String type;
  final String tag;

  String get normalizedType => type.trim().toLowerCase();
  String get normalizedTag => tag.trim().toLowerCase();

  bool get isMood => normalizedType == 'mood';
  bool get isAuthor => normalizedType == 'author';
  bool get isSearch => normalizedType == 'search';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuoteViewerFilter &&
        other.normalizedType == normalizedType &&
        other.normalizedTag == normalizedTag;
  }

  @override
  int get hashCode => Object.hash(normalizedType, normalizedTag);
}
