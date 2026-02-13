import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections_providers.dart';

Future<void> showAddToCollectionSheet(
  BuildContext context,
  WidgetRef ref,
  String quoteId,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return _AddToCollectionSheet(quoteId: quoteId);
    },
  );
}

class _AddToCollectionSheet extends ConsumerWidget {
  const _AddToCollectionSheet({required this.quoteId});

  final String quoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Add to Collections')),
          for (final collection in state.collections)
            CheckboxListTile(
              value: notifier.containsQuote(collection.id, quoteId),
              title: Text(collection.name),
              onChanged: (_) {
                notifier.toggleQuoteInCollection(
                  collectionId: collection.id,
                  quoteId: quoteId,
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
