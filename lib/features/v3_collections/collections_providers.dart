import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/storage_provider.dart';
import 'collections_model.dart';
import 'collections_repo.dart';

final collectionsRepoProvider = Provider<CollectionsRepo>((ref) {
  return CollectionsRepo(ref.read(sharedPreferencesProvider));
});

class CollectionsState {
  const CollectionsState({
    required this.collections,
    required this.memberships,
    required this.selectedCollectionId,
  });

  final List<QuoteCollection> collections;
  final Map<String, List<String>> memberships;
  final String selectedCollectionId;

  CollectionsState copyWith({
    List<QuoteCollection>? collections,
    Map<String, List<String>>? memberships,
    String? selectedCollectionId,
  }) {
    return CollectionsState(
      collections: collections ?? this.collections,
      memberships: memberships ?? this.memberships,
      selectedCollectionId: selectedCollectionId ?? this.selectedCollectionId,
    );
  }
}

class CollectionsNotifier extends StateNotifier<CollectionsState> {
  CollectionsNotifier(this._ref)
    : super(
        const CollectionsState(
          collections: [],
          memberships: {},
          selectedCollectionId: allSavedCollectionId,
        ),
      ) {
    _load();
  }

  final Ref _ref;

  CollectionsRepo get _repo => _ref.read(collectionsRepoProvider);

  void _load() {
    state = state.copyWith(
      collections: _repo.loadCollections(),
      memberships: _repo.loadMemberships(),
    );
  }

  Future<String?> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final item = QuoteCollection(
      id: _newId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );

    final next = [...state.collections, item];
    state = state.copyWith(collections: next, selectedCollectionId: item.id);
    await _repo.saveCollections(next);
    return item.id;
  }

  Future<String?> createCollectionWithQuote({
    required String name,
    required String quoteId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final item = QuoteCollection(
      id: _newId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    final nextCollections = [...state.collections, item];
    final nextMemberships = {
      ...state.memberships,
      item.id: <String>[quoteId],
    };

    state = state.copyWith(
      collections: nextCollections,
      memberships: nextMemberships,
      selectedCollectionId: item.id,
    );
    await _repo.saveCollections(nextCollections);
    await _repo.saveMemberships(nextMemberships);
    return item.id;
  }

  Future<void> renameCollection(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || id == allSavedCollectionId) return;

    final next = [
      for (final c in state.collections)
        if (c.id == id)
          QuoteCollection(id: c.id, name: trimmed, createdAt: c.createdAt)
        else
          c,
    ];

    state = state.copyWith(collections: next);
    await _repo.saveCollections(next);
  }

  Future<void> deleteCollection(String id) async {
    if (id == allSavedCollectionId) return;

    final nextCollections = state.collections.where((c) => c.id != id).toList();
    final nextMemberships = {...state.memberships}..remove(id);

    state = state.copyWith(
      collections: nextCollections,
      memberships: nextMemberships,
      selectedCollectionId: allSavedCollectionId,
    );

    await _repo.saveCollections(nextCollections);
    await _repo.saveMemberships(nextMemberships);
  }

  Future<void> toggleQuoteInCollection({
    required String collectionId,
    required String quoteId,
  }) async {
    if (collectionId == allSavedCollectionId) return;

    final next = {...state.memberships};
    final items = [...(next[collectionId] ?? <String>[])];

    if (items.contains(quoteId)) {
      items.remove(quoteId);
    } else {
      items.add(quoteId);
    }

    next[collectionId] = items;
    state = state.copyWith(memberships: next);
    await _repo.saveMemberships(next);
  }

  Future<void> addQuoteToCollection({
    required String collectionId,
    required String quoteId,
  }) async {
    if (collectionId == allSavedCollectionId) return;
    if (containsQuote(collectionId, quoteId)) return;

    final next = {...state.memberships};
    final items = [...(next[collectionId] ?? <String>[])];
    items.add(quoteId);
    next[collectionId] = items;
    state = state.copyWith(memberships: next);
    await _repo.saveMemberships(next);
  }

  Future<void> removeQuoteFromAllCollections(String quoteId) async {
    var changed = false;
    final next = <String, List<String>>{};
    for (final entry in state.memberships.entries) {
      final filtered = entry.value.where((id) => id != quoteId).toList();
      if (filtered.length != entry.value.length) {
        changed = true;
      }
      if (filtered.isNotEmpty) {
        next[entry.key] = filtered;
      }
    }
    if (!changed) return;

    state = state.copyWith(memberships: next);
    await _repo.saveMemberships(next);
  }

  bool containsQuote(String collectionId, String quoteId) {
    if (collectionId == allSavedCollectionId) return true;
    return state.memberships[collectionId]?.contains(quoteId) ?? false;
  }

  Set<String> collectionIdsForQuote(String quoteId) {
    final matched = <String>{};
    for (final entry in state.memberships.entries) {
      if (entry.value.contains(quoteId)) {
        matched.add(entry.key);
      }
    }
    return matched;
  }

  void selectCollection(String id) {
    state = state.copyWith(selectedCollectionId: id);
  }

  List<String> quoteIdsForCollection(String collectionId) {
    return state.memberships[collectionId] ?? const <String>[];
  }

  String _newId() {
    // Keep the random range comfortably inside the web-safe bound for nextInt.
    final random = Random();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = random.nextInt(0x3fffffff).toRadixString(36);
    return '$ts-$entropy';
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, CollectionsState>((ref) {
      return CollectionsNotifier(ref);
    });
