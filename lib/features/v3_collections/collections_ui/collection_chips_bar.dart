import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/design_tokens.dart';
import '../../../theme/flow_responsive.dart';
import '../../../widgets/premium/premium_components.dart';
import 'add_to_collection_sheet.dart';
import '../collections_model.dart';
import '../collections_providers.dart';

class CollectionChipsBar extends ConsumerWidget {
  const CollectionChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);
    final layout = FlowLayoutInfo.of(context);

    final items = [
      QuoteCollection(
        id: allSavedCollectionId,
        name: 'All Saved',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      ...state.collections,
    ];

    final chips = <Widget>[
      for (final collection in items)
        GestureDetector(
          onLongPress: collection.id == allSavedCollectionId
              ? null
              : () => _showCollectionActions(context, ref, collection),
          child: PremiumPillChip(
            label: collection.name,
            selected: state.selectedCollectionId == collection.id,
            onTap: () => notifier.selectCollection(collection.id),
          ),
        ),
      PremiumPillChip(
        label: '+ New',
        icon: Icons.add_rounded,
        onTap: () => _showCreateCollectionDialog(context, ref),
      ),
    ];

    if (layout.isTablet) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: FlowSpace.xs,
          runSpacing: FlowSpace.xs,
          children: chips,
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: FlowSpace.xs),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  Future<void> _showCreateCollectionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showCreateCollectionSheet(
      context,
      ref,
      title: 'Create a new collection',
      description: 'Give a group of saved quotes its own identity.',
      hintText: 'Collection name',
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
