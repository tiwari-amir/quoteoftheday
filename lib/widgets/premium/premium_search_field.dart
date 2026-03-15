import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';

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
        final layout = FlowLayoutInfo.of(context);
        final compact = layout.isCompact;
        final searchRadius = BorderRadius.circular(compact ? 10 : 12);

        return Container(
          decoration: BoxDecoration(
            borderRadius: searchRadius,
            boxShadow: [
              BoxShadow(
                color: (colors?.accent ?? Colors.white).withValues(
                  alpha: focused ? 0.16 : 0.08,
                ),
                blurRadius: focused ? 34 : 24,
                spreadRadius: focused ? 1 : 0,
              ),
              ...?flow?.shadows.level1,
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: searchRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (colors?.elevatedSurface ?? Colors.black).withValues(
                    alpha: 0.94,
                  ),
                  (colors?.surface ?? Colors.black).withValues(alpha: 0.86),
                ],
              ),
              border: Border.all(
                color:
                    (focused
                        ? colors?.accent.withValues(alpha: 0.52)
                        : colors?.divider.withValues(alpha: 0.72)) ??
                    Colors.white24,
                width: focused ? 1.15 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 46 : 50),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? FlowSpace.xs : FlowSpace.sm,
                  compact ? 5 : 6,
                  FlowSpace.xs,
                  compact ? 5 : 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 28 : 30,
                      height: compact ? 28 : 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: focused ? 0.14 : 0.1,
                        ),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: compact ? 14 : 16,
                        color: focused
                            ? colors?.accent
                            : colors?.textSecondary.withValues(alpha: 0.94),
                      ),
                    ),
                    SizedBox(width: compact ? FlowSpace.xs : FlowSpace.sm),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: compact ? 14.5 : 15,
                          color: colors?.textPrimary,
                        ),
                        cursorColor: colors?.accent,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: compact ? 13.5 : 14,
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
