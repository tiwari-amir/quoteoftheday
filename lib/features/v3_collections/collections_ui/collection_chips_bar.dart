import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/premium/premium_components.dart';
import '../collections_model.dart';
import '../collections_providers.dart';

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

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: FlowSpace.xs),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return PremiumPillChip(
              label: '+ New',
              icon: Icons.add_rounded,
              onTap: () => _showCreateCollectionDialog(context, ref),
            );
          }
          final collection = items[index];
          return GestureDetector(
            onLongPress: collection.id == allSavedCollectionId
                ? null
                : () => _showCollectionActions(context, ref, collection),
            child: PremiumPillChip(
              label: collection.name,
              selected: state.selectedCollectionId == collection.id,
              onTap: () => notifier.selectCollection(collection.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateCollectionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: FlowRadii.radiusLg),
          title: const Text('New Collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Collection name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(collectionsProvider.notifier)
                    .createCollection(controller.text);
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FlowSpace.md),
            child: PremiumSurface(
              blurSigma: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Rename'),
                    onTap: () async {
                      Navigator.pop(context);
                      final controller = TextEditingController(
                        text: collection.name,
                      );
                      await showDialog<void>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: FlowRadii.radiusLg,
                            ),
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
                                      .renameCollection(
                                        collection.id,
                                        controller.text,
                                      );
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
                      await ref
                          .read(collectionsProvider.notifier)
                          .deleteCollection(collection.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
