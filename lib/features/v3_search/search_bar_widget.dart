import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/premium/premium_search_field.dart';
import 'search_providers.dart';

class V3SearchBarWidget extends ConsumerStatefulWidget {
  const V3SearchBarWidget({super.key});

  @override
  ConsumerState<V3SearchBarWidget> createState() => _V3SearchBarWidgetState();
}

class _V3SearchBarWidgetState extends ConsumerState<V3SearchBarWidget> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryState = ref.watch(searchQueryProvider);
    if (_controller.text != queryState.query) {
      _controller.value = TextEditingValue(
        text: queryState.query,
        selection: TextSelection.collapsed(offset: queryState.query.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSearchField(
          controller: _controller,
          focusNode: _focusNode,
          hintText: 'Search quotes, author, tags',
          onChanged: (value) =>
              ref.read(searchQueryProvider.notifier).setQueryDebounced(value),
          onClear: () {
            _controller.clear();
            ref.read(searchQueryProvider.notifier).setQueryDebounced('');
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Any'),
              selected: queryState.lengthFilter == null,
              onSelected: (_) =>
                  ref.read(searchQueryProvider.notifier).setLengthFilter(null),
            ),
            ChoiceChip(
              label: const Text('Short'),
              selected: queryState.lengthFilter == 'short',
              onSelected: (_) => ref
                  .read(searchQueryProvider.notifier)
                  .setLengthFilter('short'),
            ),
            ChoiceChip(
              label: const Text('Medium'),
              selected: queryState.lengthFilter == 'medium',
              onSelected: (_) => ref
                  .read(searchQueryProvider.notifier)
                  .setLengthFilter('medium'),
            ),
            ChoiceChip(
              label: const Text('Long'),
              selected: queryState.lengthFilter == 'long',
              onSelected: (_) => ref
                  .read(searchQueryProvider.notifier)
                  .setLengthFilter('long'),
            ),
          ],
        ),
      ],
    );
  }
}
