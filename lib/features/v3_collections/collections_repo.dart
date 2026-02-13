import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'collections_model.dart';

class CollectionsRepo {
  CollectionsRepo(this._prefs);

  final SharedPreferences _prefs;

  static const collectionsKey = 'v3.collections';
  static const membershipsKey = 'v3.collection_memberships';

  List<QuoteCollection> loadCollections() {
    final raw = _prefs.getString(collectionsKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(QuoteCollection.fromJson)
        .toList(growable: false);
  }

  Map<String, List<String>> loadMemberships() {
    final raw = _prefs.getString(membershipsKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, List<String>>{};
    }

    final out = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is List) {
        out[entry.key] = value.map((e) => e.toString()).toSet().toList();
      }
    }
    return out;
  }

  Future<void> saveCollections(List<QuoteCollection> collections) async {
    final data = collections.map((c) => c.toJson()).toList(growable: false);
    await _prefs.setString(collectionsKey, jsonEncode(data));
  }

  Future<void> saveMemberships(Map<String, List<String>> memberships) async {
    await _prefs.setString(membershipsKey, jsonEncode(memberships));
  }
}
