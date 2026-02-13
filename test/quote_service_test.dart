import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteoftheday/models/quote_model.dart';
import 'package:quoteoftheday/services/quote_service.dart';

void main() {
  final quotes = List.generate(
    4,
    (index) => QuoteModel(
      id: 'id_$index',
      quote: 'quote_$index',
      author: 'author_$index',
      revisedTags: const ['motivated'],
    ),
  );

  test('readingDurationInSeconds uses one second per word', () {
    final service = QuoteService();
    expect(service.readingDurationInSeconds('Be yourself always'), 3);
    expect(service.readingDurationInSeconds(''), 1);
  });

  test('toTitleCase formats tags for display', () {
    final service = QuoteService();
    expect(service.toTitleCase('self-growth'), 'Self Growth');
    expect(service.toTitleCase('hopeful'), 'Hopeful');
  });

  test('QuoteModel parses revised_tags list or string', () {
    final fromList = QuoteModel.fromJson({
      'id': 1,
      'quote': 'q',
      'author': 'a',
      'revised_tags': ['happy', ' calm '],
    });

    final fromString = QuoteModel.fromJson({
      'id': 2,
      'quote': 'q',
      'author': 'a',
      'revised_tags': 'happy,calm',
    });

    expect(fromList.revisedTags, containsAll(['happy', 'calm']));
    expect(fromString.revisedTags, containsAll(['happy', 'calm']));
  });

  test('quotes.json can be decoded into QuoteModel list', () {
    final raw = File('assets/quotes.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    final quotes = decoded
        .map((entry) => QuoteModel.fromJson(entry as Map<String, dynamic>))
        .toList();

    expect(quotes.length, greaterThanOrEqualTo(12));
    expect(quotes.first.quote, isNotEmpty);
    expect(quotes.first.revisedTags, isNotEmpty);
  });

  test('pickQuoteForDate returns a stable quote for the same day', () {
    final service = QuoteService();
    final date = DateTime(2026, 2, 13, 8, 30);

    final firstPick = service.pickQuoteForDate(quotes, date);
    final secondPick = service.pickQuoteForDate(
      quotes,
      DateTime(2026, 2, 13, 23, 59),
    );

    expect(firstPick.id, secondPick.id);
  });

  test('pickQuoteForDate rotates quote on consecutive days', () {
    final service = QuoteService();
    final dayOne = service.pickQuoteForDate(quotes, DateTime(2026, 2, 13));
    final dayTwo = service.pickQuoteForDate(quotes, DateTime(2026, 2, 14));

    expect(dayOne.id, isNot(dayTwo.id));
  });
}
