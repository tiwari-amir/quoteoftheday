import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/premium/premium_components.dart';
import '../collections_providers.dart';

Future<void> showAddToCollectionSheet(
  BuildContext context,
  WidgetRef ref,
  String quoteId,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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
      child: Padding(
        padding: const EdgeInsets.all(FlowSpace.md),
        child: PremiumSurface(
          blurSigma: 10,
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.md,
            FlowSpace.sm,
            FlowSpace.md,
            FlowSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(width: 42, child: Divider(thickness: 3)),
              ),
              const SizedBox(height: FlowSpace.sm),
              Text(
                'Add to Collections',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FlowSpace.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final collection in state.collections)
                      CheckboxListTile(
                        value: notifier.containsQuote(collection.id, quoteId),
                        title: Text(collection.name),
                        shape: RoundedRectangleBorder(
                          borderRadius: FlowRadii.radiusMd,
                        ),
                        onChanged: (_) {
                          notifier.toggleQuoteInCollection(
                            collectionId: collection.id,
                            quoteId: quoteId,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
