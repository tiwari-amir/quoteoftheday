import 'package:flutter_test/flutter_test.dart';
import 'package:quoteoftheday/services/quote_service.dart';

void main() {
  test('readingDurationInSeconds uses one second per word', () {
    final service = QuoteService();
    expect(service.readingDurationInSeconds('Be yourself always'), 3);
    expect(service.readingDurationInSeconds(''), 1);
  });
}
