import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class PremiumSearchField extends StatelessWidget {
  const PremiumSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[controller];
    if (focusNode != null) {
      listenables.add(focusNode!);
    }

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final flow = Theme.of(context).extension<FlowThemeTokens>();
        final colors = flow?.colors;
        final focused = focusNode?.hasFocus ?? false;
        final hasText = controller.text.trim().isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            borderRadius: FlowRadii.radiusXl,
            boxShadow: [
              BoxShadow(
                color: (colors?.accent ?? Colors.white).withValues(
                  alpha: focused ? 0.22 : 0.12,
                ),
                blurRadius: focused ? 30 : 22,
                spreadRadius: focused ? 1 : 0,
              ),
              ...?flow?.shadows.level1,
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: FlowRadii.radiusXl,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (colors?.elevatedSurface ?? Colors.black).withValues(
                    alpha: 0.9,
                  ),
                  (colors?.surface ?? Colors.black).withValues(alpha: 0.82),
                ],
              ),
              border: Border.all(
                color:
                    (focused
                        ? colors?.accent.withValues(alpha: 0.65)
                        : colors?.divider.withValues(alpha: 0.82)) ??
                    Colors.white24,
                width: focused ? 1.15 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FlowSpace.sm,
                  7,
                  FlowSpace.xs,
                  7,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.15,
                        ),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: colors?.textPrimary.withValues(alpha: 0.94),
                      ),
                    ),
                    const SizedBox(width: FlowSpace.sm),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors?.textPrimary,
                        ),
                        cursorColor: colors?.accent,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors?.textSecondary.withValues(
                                  alpha: 0.88,
                                ),
                              ),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.only(bottom: 1),
                        ),
                      ),
                    ),
                    if (hasText)
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
