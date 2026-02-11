import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

import 'package:quoteoftheday/models/quote_model.dart';
import 'package:quoteoftheday/services/quote_service.dart';

void main() {
  test('readingDurationInSeconds uses one second per word', () {
    final service = QuoteService();
    expect(service.readingDurationInSeconds('Be yourself always'), 3);
    expect(service.readingDurationInSeconds(''), 1);
  });

  test('quotes.json can be decoded into QuoteModel list', () {
    final raw = File('assets/quotes.json').readAsStringSync();
    final decoded = jsonDecode(raw) as List<dynamic>;
    final quotes = decoded
        .map((entry) => QuoteModel.fromJson(entry as Map<String, dynamic>))
        .toList();

    expect(quotes, isNotEmpty);
    expect(quotes.first.quote, isNotEmpty);
    expect(quotes.first.revisedTags, isNotEmpty);
  });
}
