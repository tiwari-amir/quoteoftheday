class QuoteCollection {
  const QuoteCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory QuoteCollection.fromJson(Map<String, dynamic> json) {
    return QuoteCollection(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

const String allSavedCollectionId = '__all_saved__';
