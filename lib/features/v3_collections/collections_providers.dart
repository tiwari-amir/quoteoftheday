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
      : super(const CollectionsState(
          collections: [],
          memberships: {},
          selectedCollectionId: allSavedCollectionId,
        )) {
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

  Future<void> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final item = QuoteCollection(
      id: _newId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );

    final next = [...state.collections, item];
    state = state.copyWith(collections: next, selectedCollectionId: item.id);
    await _repo.saveCollections(next);
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

  bool containsQuote(String collectionId, String quoteId) {
    if (collectionId == allSavedCollectionId) return true;
    return state.memberships[collectionId]?.contains(quoteId) ?? false;
  }

  void selectCollection(String id) {
    state = state.copyWith(selectedCollectionId: id);
  }

  List<String> quoteIdsForCollection(String collectionId) {
    return state.memberships[collectionId] ?? const <String>[];
  }

  String _newId() {
    final random = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$ts-${random.nextInt(1 << 32)}';
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, CollectionsState>((ref) {
  return CollectionsNotifier(ref);
});
