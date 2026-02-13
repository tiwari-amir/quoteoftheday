import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections_model.dart';
import '../collections_providers.dart';
import '../../../widgets/neon_chip.dart';

class CollectionChipsBar extends ConsumerWidget {
  const CollectionChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);

    final items = [
      QuoteCollection(
        id: allSavedCollectionId,
        name: 'All Saved',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      ...state.collections,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final collection in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: collection.id == allSavedCollectionId
                    ? null
                    : () => _showCollectionActions(context, ref, collection),
                child: NeonChip(
                  label: collection.name,
                  selected: state.selectedCollectionId == collection.id,
                  onTap: () => notifier.selectCollection(collection.id),
                ),
              ),
            ),
          NeonChip(
            label: '+ New',
            onTap: () => _showCreateCollectionDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCollectionDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Collection name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref.read(collectionsProvider.notifier).createCollection(controller.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCollectionActions(
    BuildContext context,
    WidgetRef ref,
    QuoteCollection collection,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController(text: collection.name);
                  await showDialog<void>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Rename Collection'),
                        content: TextField(controller: controller),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(collectionsProvider.notifier)
                                  .renameCollection(collection.id, controller.text);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  await ref.read(collectionsProvider.notifier).deleteCollection(collection.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
