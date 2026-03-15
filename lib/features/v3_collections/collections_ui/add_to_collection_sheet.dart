import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/saved_quotes_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/premium/premium_components.dart';
import '../collections_providers.dart';

Future<void> showSaveQuoteSheet(
  BuildContext context,
  WidgetRef ref,
  String quoteId,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _SaveQuoteSheet(quoteId: quoteId);
    },
  );
}

Future<void> showAddToCollectionSheet(
  BuildContext context,
  WidgetRef ref,
  String quoteId,
) {
  return showSaveQuoteSheet(context, ref, quoteId);
}

Future<String?> showCreateCollectionSheet(
  BuildContext context,
  WidgetRef ref, {
  String? quoteId,
  String title = 'Create a new collection',
  String description =
      'Name a dedicated space for the lines you want to keep together.',
  String hintText = 'Collection name',
}) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _CreateCollectionSheet(
        quoteId: quoteId,
        title: title,
        description: description,
        hintText: hintText,
      );
    },
  );
}

class _SaveQuoteSheet extends ConsumerStatefulWidget {
  const _SaveQuoteSheet({required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<_SaveQuoteSheet> createState() => _SaveQuoteSheetState();
}

class _SaveQuoteSheetState extends ConsumerState<_SaveQuoteSheet> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;
    final savedIds = ref.watch(savedQuoteIdsProvider);
    final isSaved = savedIds.contains(widget.quoteId);
    final collections = ref.watch(collectionsProvider);
    final collectionsNotifier = ref.read(collectionsProvider.notifier);
    final savedNotifier = ref.read(savedQuoteIdsProvider.notifier);
    final membershipIds = collectionsNotifier.collectionIdsForQuote(
      widget.quoteId,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FlowSpace.md,
          FlowSpace.sm,
          FlowSpace.md,
          FlowSpace.md,
        ),
        child: PremiumSurface(
          blurSigma: 14,
          radius: FlowRadii.xl,
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.lg,
            FlowSpace.sm,
            FlowSpace.lg,
            FlowSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors?.divider.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: FlowSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Save quote',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: FlowSpace.xs),
                        Text(
                          'Place this line in your archive or save it into a collection.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  PremiumIconPillButton(
                    icon: Icons.close_rounded,
                    compact: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: FlowSpace.sm),
              Text(
                'DESTINATIONS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors?.accent.withValues(alpha: 0.84),
                  letterSpacing: 0.62,
                ),
              ),
              const SizedBox(height: FlowSpace.xs),
              _SaveDestinationTile(
                icon: Icons.bookmark_rounded,
                title: 'All Saved',
                subtitle: 'Keep it in your main archive',
                selected: isSaved,
                onTap: () async {
                  await savedNotifier.save(widget.quoteId);
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                },
              ),
              if (collections.collections.isNotEmpty) ...[
                const SizedBox(height: FlowSpace.sm),
                Text(
                  'Collections',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors?.textSecondary.withValues(alpha: 0.96),
                    letterSpacing: 0.32,
                  ),
                ),
                const SizedBox(height: FlowSpace.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: collections.collections.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: FlowSpace.xs),
                    itemBuilder: (context, index) {
                      final collection = collections.collections[index];
                      final isInCollection = membershipIds.contains(
                        collection.id,
                      );
                      return _SaveDestinationTile(
                        icon: Icons.folder_open_rounded,
                        title: collection.name,
                        subtitle: isInCollection
                            ? 'Already saved here'
                            : 'Save into this collection',
                        selected: isInCollection,
                        onTap: () async {
                          await savedNotifier.save(widget.quoteId);
                          if (isInCollection) {
                            await collectionsNotifier.toggleQuoteInCollection(
                              collectionId: collection.id,
                              quoteId: widget.quoteId,
                            );
                          } else {
                            await collectionsNotifier.addQuoteToCollection(
                              collectionId: collection.id,
                              quoteId: widget.quoteId,
                            );
                          }
                          if (!mounted) return;
                          Navigator.of(this.context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: FlowSpace.sm),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final collectionId = await showCreateCollectionSheet(
                        context,
                        ref,
                        quoteId: widget.quoteId,
                        title: 'Create a new collection',
                        description:
                            'Give this quote a new place to live in your archive.',
                        hintText: 'Collection name',
                      );
                      if (!mounted || collectionId == null) return;
                      navigator.pop();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New collection'),
                  ),
                  const Spacer(),
                  if (isSaved)
                    PremiumIconPillButton(
                      icon: Icons.bookmark_remove_rounded,
                      label: 'Remove',
                      compact: true,
                      onTap: () async {
                        await savedNotifier.remove(widget.quoteId);
                        await collectionsNotifier.removeQuoteFromAllCollections(
                          widget.quoteId,
                        );
                        if (!mounted) return;
                        Navigator.of(this.context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCollectionSheet extends ConsumerStatefulWidget {
  const _CreateCollectionSheet({
    this.quoteId,
    required this.title,
    required this.description,
    required this.hintText,
  });

  final String? quoteId;
  final String title;
  final String description;
  final String hintText;

  @override
  ConsumerState<_CreateCollectionSheet> createState() =>
      _CreateCollectionSheetState();
}

class _CreateCollectionSheetState
    extends ConsumerState<_CreateCollectionSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_submitting;

    return Padding(
      padding: EdgeInsets.only(
        left: FlowSpace.md,
        right: FlowSpace.md,
        top: FlowSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + FlowSpace.md,
      ),
      child: SingleChildScrollView(
        child: PremiumSurface(
          blurSigma: 16,
          radius: FlowRadii.xl,
          padding: const EdgeInsets.fromLTRB(
            FlowSpace.lg,
            FlowSpace.md,
            FlowSpace.lg,
            FlowSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FlowSpace.xs),
              Text(
                widget.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: FlowSpace.md),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canSubmit) {
                    unawaited(_submit());
                  }
                },
                decoration: InputDecoration(hintText: widget.hintText),
              ),
              const SizedBox(height: FlowSpace.md),
              Row(
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (_submitting) return;
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a collection name')),
        );
      return;
    }

    setState(() => _submitting = true);
    final collectionsNotifier = ref.read(collectionsProvider.notifier);

    try {
      final collectionId = widget.quoteId == null
          ? await collectionsNotifier.createCollection(trimmed)
          : await collectionsNotifier.createCollectionWithQuote(
              name: trimmed,
              quoteId: widget.quoteId!,
            );

      if (widget.quoteId != null &&
          collectionId != null &&
          collectionId.isNotEmpty) {
        await ref.read(savedQuoteIdsProvider.notifier).save(widget.quoteId!);
      }

      if (!mounted) return;
      Navigator.of(context).pop(collectionId);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _SaveDestinationTile extends StatelessWidget {
  const _SaveDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FlowThemeTokens>()?.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FlowRadii.radiusLg,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: FlowRadii.radiusLg,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (selected
                        ? colors?.accent ?? Colors.white
                        : colors?.elevatedSurface ?? Colors.white)
                    .withValues(alpha: selected ? 0.18 : 0.82),
                (colors?.surface ?? Colors.black).withValues(
                  alpha: selected ? 0.86 : 0.76,
                ),
              ],
            ),
            border: Border.all(
              color:
                  (selected
                          ? colors?.accent ?? Colors.white
                          : colors?.divider ?? Colors.white24)
                      .withValues(alpha: selected ? 0.65 : 0.88),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (selected
                              ? colors?.accent ?? Colors.white
                              : colors?.surface ?? Colors.black)
                          .withValues(alpha: 0.14),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? colors?.accent : colors?.textSecondary,
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors?.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors?.textSecondary.withValues(alpha: 0.94),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: selected ? 20 : 14,
                color: selected ? colors?.accent : colors?.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
