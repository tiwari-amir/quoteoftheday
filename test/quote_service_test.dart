import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quoteoftheday/models/quote_model.dart';
import 'package:quoteoftheday/services/quote_service.dart';

void main() {
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
}
