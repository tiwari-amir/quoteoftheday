import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/v3_explore/discovery_category_utils.dart';
import '../../providers/quote_providers.dart';
import '../../theme/design_tokens.dart';
import '../../theme/flow_responsive.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import 'in_app_notification_model.dart';
import 'in_app_notifications_providers.dart';

Future<void> showInAppNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) {
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      final layout = FlowLayoutInfo.of(context);
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: layout.isTablet ? 640 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                FlowSpace.xs,
                0,
                FlowSpace.xs,
                bottomInset + FlowSpace.xs,
              ),
              child: const FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.42,
                child: _InAppNotificationsSheet(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class InAppNotificationsScreen extends StatelessWidget {
  const InAppNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = FlowLayoutInfo.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding + 2,
                    layout.horizontalPadding,
                    FlowSpace.lg,
                  ),
                  child: _NotificationsPanel(
                    compact: false,
                    onClose: () => context.pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InAppNotificationsSheet extends StatelessWidget {
  const _InAppNotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final flow = Theme.of(context).extension<FlowThemeTokens>();
    final colors = flow?.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        color: (colors?.surface ?? Colors.black).withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: (flow?.shadowColor ?? Colors.black).withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (colors?.elevatedSurface ?? Colors.black).withValues(
                        alpha: 0.92,
                      ),
                      (colors?.surface ?? Colors.black).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),
            _NotificationsPanel(
              compact: true,
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsPanel extends ConsumerStatefulWidget {
  const _NotificationsPanel({required this.compact, required this.onClose});

  final bool compact;
  final VoidCallback onClose;

  @override
  ConsumerState<_NotificationsPanel> createState() =>
      _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<_NotificationsPanel> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(inAppNotificationsProvider);
    final prefs = ref.watch(inAppNotificationPreferencesProvider);

    ref.listen<AsyncValue<List<InAppNotificationModel>>>(
      inAppNotificationsProvider,
      (previous, next) {
        final latestId = next.valueOrNull?.isNotEmpty == true
            ? next.valueOrNull!.first.id
            : 0;
        if (latestId <= 0) return;
        unawaited(
          ref
              .read(inAppNotificationPreferencesProvider.notifier)
              .markSeenUpTo(latestId),
        );
      },
    );

    final horizontalPadding = widget.compact ? 12.0 : FlowSpace.lg;
    final topPadding = widget.compact ? 10.0 : FlowSpace.md;
    final bottomPadding = widget.compact
        ? MediaQuery.viewPaddingOf(context).bottom + 10
        : FlowSpace.lg;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) ...[
            Center(
              child: Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _colors(context).divider.withValues(alpha: 0.84),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _NotificationsHeader(
            compact: widget.compact,
            muted: prefs.muted,
            onClose: widget.onClose,
            onMuteChanged: (value) {
              unawaited(
                ref
                    .read(inAppNotificationPreferencesProvider.notifier)
                    .setMuted(!value),
              );
            },
          ),
          SizedBox(height: widget.compact ? 10 : FlowSpace.sm),
          Expanded(
            child: notificationsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyNotificationsState(compact: widget.compact);
                }
                return RefreshIndicator.adaptive(
                  onRefresh: () async {
                    ref.invalidate(inAppNotificationsProvider);
                    await ref.read(inAppNotificationsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      bottom:
                          (widget.compact ? FlowSpace.sm : FlowSpace.lg) +
                          MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, index) =>
                        SizedBox(height: widget.compact ? 6 : FlowSpace.sm),
                    itemBuilder: (context, index) {
                      return _NotificationCard(
                        item: items[index],
                        compact: widget.compact,
                        emphasize: index == 0,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => PremiumSurface(
                radius: FlowRadii.xl,
                padding: const EdgeInsets.all(FlowSpace.lg),
                child: Text(
                  'Failed to load updates: $error',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _colors(context).textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.compact,
    required this.muted,
    required this.onClose,
    required this.onMuteChanged,
  });

  final bool compact;
  final bool muted;
  final VoidCallback onClose;
  final ValueChanged<bool> onMuteChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        if (!compact) ...[
          PremiumIconPillButton(
            icon: Icons.arrow_back_rounded,
            compact: true,
            onTap: onClose,
          ),
          const SizedBox(width: FlowSpace.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compact ? 'Updates' : 'Updates',
                style: compact
                    ? textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      )
                    : textTheme.headlineSmall?.copyWith(
                        color: colors.textPrimary,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                muted ? 'Only shown here.' : 'Daily crawl notes and refreshes.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.96),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: FlowSpace.xs),
        _HeaderActionButton(
          icon: muted
              ? Icons.notifications_off_rounded
              : Icons.notifications_active_rounded,
          tooltip: muted ? 'Notifications muted' : 'Notifications active',
          onTap: () => onMuteChanged(!muted),
        ),
        if (compact) ...[
          const SizedBox(width: FlowSpace.xs),
          _HeaderActionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: onClose,
          ),
        ],
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.elevatedSurface.withValues(alpha: 0.84),
            ),
            child: Icon(icon, size: 17, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;

    return PremiumSurface(
      radius: compact ? 18 : FlowRadii.xl,
      padding: EdgeInsets.all(compact ? FlowSpace.md : FlowSpace.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 38 : 52,
              height: compact ? 38 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: colors.accent,
                size: compact ? 18 : 24,
              ),
            ),
            SizedBox(height: compact ? 10 : FlowSpace.sm),
            Text(
              'Nothing new yet',
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FlowSpace.xs),
            Text(
              'Fresh crawl notes will show up here.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary.withValues(alpha: 0.96),
                height: 1.28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.item,
    required this.compact,
    required this.emphasize,
  });

  final InAppNotificationModel item;
  final bool compact;
  final bool emphasize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;
    final accentColor = item.quotesAdded > 0
        ? colors.accent
        : colors.textSecondary;
    final leadingIcon = item.quotesAdded > 0
        ? Icons.auto_awesome_rounded
        : item.prunedQuotes > 0
        ? Icons.layers_clear_rounded
        : Icons.update_rounded;
    final quotes = ref.watch(allQuotesProvider).valueOrNull ?? const [];
    final recentCategory = _isDiscoveryNotification(item)
        ? pickRecentDiscoveryCategory(quotes)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        color: (colors.elevatedSurface).withValues(
          alpha: compact ? 0.64 : 0.72,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: accentColor.withValues(alpha: emphasize ? 0.92 : 0.72),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      leadingIcon,
                      size: compact ? 14 : 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _notificationHeadline(item),
                        style:
                            (compact
                                    ? textTheme.titleSmall
                                    : textTheme.titleMedium)
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                      ),
                    ),
                    const SizedBox(width: FlowSpace.xs),
                    Text(
                      _formatNotificationTimestamp(item.createdAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _notificationSummary(item),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.94),
                    height: 1.28,
                  ),
                ),
                if (recentCategory != null) ...[
                  const SizedBox(height: 8),
                  _NotificationActionChip(
                    label: 'Open newly added list',
                    onTap: () => context.push(
                      '/categories/${Uri.encodeComponent(discoveryCategoryRouteTag(recentCategory))}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _notificationHeadline(InAppNotificationModel item) {
  if (item.quotesAdded > 0) {
    return '${item.quotesAdded} new ${item.quotesAdded == 1 ? 'quote' : 'quotes'} added';
  }
  if (item.prunedQuotes > 0) {
    return 'Library refreshed';
  }
  return 'No new quotes this round';
}

String _notificationSummary(InAppNotificationModel item) {
  if (item.totalQuotes > 0) {
    final parts = <String>['Library now at ${item.totalQuotes}'];
    if (item.prunedQuotes > 0) {
      parts.add('${item.prunedQuotes} trimmed');
    }
    return '${parts.join(' · ')}.';
  }

  if (item.body.trim().isNotEmpty) {
    return item.body.trim();
  }

  return 'The crawler checked the latest pages.';
}

bool _isDiscoveryNotification(InAppNotificationModel item) {
  return item.type.trim().toLowerCase() == 'discovery_summary';
}

class _NotificationActionChip extends StatelessWidget {
  const _NotificationActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: colors.accent.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

String _formatNotificationTimestamp(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);

  final hourValue = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minuteValue = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  if (day == today) {
    return 'Today, $hourValue:$minuteValue $suffix';
  }

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, $hourValue:$minuteValue $suffix';
}

FlowColorTokens _colors(BuildContext context) {
  return Theme.of(context).extension<FlowThemeTokens>()!.colors;
}
