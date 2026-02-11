class QuoteViewerFilter {
  const QuoteViewerFilter({required this.type, required this.tag});

  final String type;
  final String tag;

  bool get isMood => type.toLowerCase() == 'mood';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuoteViewerFilter && other.type == type && other.tag == tag;
  }

  @override
  int get hashCode => Object.hash(type, tag);
}
