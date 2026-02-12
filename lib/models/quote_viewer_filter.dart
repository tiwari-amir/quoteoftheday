class QuoteViewerFilter {
  const QuoteViewerFilter({required this.type, required this.tag});

  final String type;
  final String tag;

  bool get isMood => type.toLowerCase() == 'mood';
}
