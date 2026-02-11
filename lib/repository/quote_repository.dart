import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../models/quote_model.dart';

class QuoteRepository {
  Future<List<QuoteModel>> loadQuotes() async {
    final rawJson = await rootBundle.loadString(quotesAssetPath);
    final decoded = jsonDecode(rawJson) as List<dynamic>;

    return decoded
        .map((entry) => QuoteModel.fromJson(entry as Map<String, dynamic>))
        .where((quote) => quote.quote.isNotEmpty)
        .toList(growable: false);
  }
}
