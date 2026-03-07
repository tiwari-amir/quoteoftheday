import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/editorial_background.dart';
import '../../widgets/premium/premium_components.dart';
import 'in_app_notification_model.dart';
import 'in_app_notifications_providers.dart';

Future<void> showInAppNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) {
      return const FractionallySizedBox(
        heightFactor: 0.64,
        child: _InAppNotificationsSheet(),
      );
    },
  );
}

class InAppNotificationsScreen extends StatelessWidget {
  const InAppNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const EditorialBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.md,
                FlowSpace.lg,
                FlowSpace.lg,
              ),
              child: _NotificationsPanel(
                compact: false,
                onClose: () => context.pop(),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        color: (colors?.surface ?? Colors.black).withValues(alpha: 0.98),
        border: Border.all(
          color: (colors?.divider ?? Colors.white24).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: (flow?.shadowColor ?? Colors.black).withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
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
                        alpha: 0.95,
                      ),
                      (colors?.surface ?? Colors.black).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -56,
              right: -18,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (colors?.accent ?? Colors.white).withValues(
                          alpha: 0.14,
                        ),
                        blurRadius: 88,
                        spreadRadius: 18,
                      ),
                    ],
                  ),
                  child: const SizedBox.square(dimension: 120),
                ),
              ),
            ),
            Positioned(
              left: -48,
              bottom: 72,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (colors?.quoteFrameGlow ?? Colors.white)
                            .withValues(alpha: 0.12),
                        blurRadius: 76,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: const SizedBox.square(dimension: 112),
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

    final horizontalPadding = widget.compact ? FlowSpace.md : FlowSpace.lg;
    final topPadding = widget.compact ? FlowSpace.sm : FlowSpace.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        FlowSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) ...[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _colors(context).divider.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: FlowSpace.sm),
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
          const SizedBox(height: FlowSpace.md),
          Expanded(
            child: notificationsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyNotificationsState(compact: widget.compact);
                }

                final latest = items.first;
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
                      bottom: widget.compact ? FlowSpace.sm : FlowSpace.md,
                    ),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, index) => SizedBox(
                      height: index == 0
                          ? FlowSpace.md
                          : (widget.compact ? 10 : FlowSpace.md),
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _LatestRunSpotlight(
                          item: latest,
                          compact: widget.compact,
                        );
                      }
                      return _NotificationCard(
                        item: items[index - 1],
                        compact: widget.compact,
                        emphasize: index == 1,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                children: [
                  _SectionEyebrow(
                    label: compact ? 'Notification center' : 'Library updates',
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Text(
                    compact
                        ? 'Fresh arrivals'
                        : 'Fresh arrivals and crawl notes',
                    style: compact
                        ? textTheme.titleLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          )
                        : textTheme.headlineSmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                  ),
                  const SizedBox(height: FlowSpace.xxs),
                  Text(
                    compact
                        ? 'Daily quote additions, library totals, and quiet delivery settings.'
                        : 'A quiet feed of crawler activity, library growth, and delivery controls.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.96),
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
            if (compact)
              PremiumIconPillButton(
                icon: Icons.close_rounded,
                compact: true,
                onTap: onClose,
              ),
          ],
        ),
        const SizedBox(height: FlowSpace.md),
        _MutePreferenceTile(
          compact: compact,
          muted: muted,
          onChanged: onMuteChanged,
        ),
      ],
    );
  }
}

class _MutePreferenceTile extends StatelessWidget {
  const _MutePreferenceTile({
    required this.compact,
    required this.muted,
    required this.onChanged,
  });

  final bool compact;
  final bool muted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FlowSpace.sm : FlowSpace.md,
        vertical: compact ? FlowSpace.sm : FlowSpace.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 20 : FlowRadii.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.elevatedSurface.withValues(alpha: 0.86),
            colors.surface.withValues(alpha: 0.86),
          ],
        ),
        border: Border.all(color: colors.divider.withValues(alpha: 0.88)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (muted ? colors.textSecondary : colors.accent).withValues(
                alpha: 0.14,
              ),
              border: Border.all(
                color: (muted ? colors.divider : colors.accent).withValues(
                  alpha: 0.55,
                ),
              ),
            ),
            child: Icon(
              muted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              size: compact ? 17 : 19,
              color: muted ? colors.textSecondary : colors.accent,
            ),
          ),
          const SizedBox(width: FlowSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  muted ? 'Quiet mode on' : 'Phone alerts on',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  muted
                      ? 'Updates stay in this panel and the bell keeps the unread dot.'
                      : 'New crawl summaries can also reach the device notification tray.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.96),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FlowSpace.sm),
          Switch.adaptive(value: !muted, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LatestRunSpotlight extends StatelessWidget {
  const _LatestRunSpotlight({required this.item, required this.compact});

  final InAppNotificationModel item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;

    return PremiumSurface(
      radius: compact ? 24 : FlowRadii.xl,
      elevation: 2,
      padding: EdgeInsets.fromLTRB(
        compact ? FlowSpace.md : FlowSpace.lg,
        compact ? FlowSpace.md : FlowSpace.lg,
        compact ? FlowSpace.md : FlowSpace.lg,
        compact ? FlowSpace.md : FlowSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionEyebrow(label: 'Latest crawl'),
              const Spacer(),
              Text(
                _formatNotificationTimestamp(item.createdAt),
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(
            item.title,
            style: (compact ? textTheme.titleMedium : textTheme.titleLarge)
                ?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: FlowSpace.xs),
          Text(
            item.body,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary.withValues(alpha: 0.98),
              height: 1.45,
            ),
          ),
          const SizedBox(height: FlowSpace.md),
          Row(
            children: [
              Expanded(
                child: _SpotlightMetric(
                  label: 'Added',
                  value: '${item.quotesAdded}',
                  compact: compact,
                  highlight: item.quotesAdded > 0,
                  icon: Icons.auto_awesome_rounded,
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: _SpotlightMetric(
                  label: 'Library',
                  value: '${item.totalQuotes}',
                  compact: compact,
                  highlight: false,
                  icon: Icons.layers_rounded,
                ),
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: _SpotlightMetric(
                  label: 'Trimmed',
                  value: '${item.prunedQuotes}',
                  compact: compact,
                  highlight: false,
                  icon: Icons.filter_alt_off_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightMetric extends StatelessWidget {
  const _SpotlightMetric({
    required this.label,
    required this.value,
    required this.compact,
    required this.highlight,
    required this.icon,
  });

  final String label;
  final String value;
  final bool compact;
  final bool highlight;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FlowSpace.sm : FlowSpace.md,
        vertical: compact ? FlowSpace.sm : FlowSpace.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        color: (highlight ? colors.accent : colors.elevatedSurface).withValues(
          alpha: highlight ? 0.14 : 0.52,
        ),
        border: Border.all(
          color: (highlight ? colors.accent : colors.divider).withValues(
            alpha: highlight ? 0.52 : 0.7,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: compact ? 14 : 16,
            color: highlight ? colors.accent : colors.textSecondary,
          ),
          const SizedBox(height: FlowSpace.xs),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
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
      radius: compact ? 24 : FlowRadii.xl,
      padding: const EdgeInsets.all(FlowSpace.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 52 : 60,
              height: compact ? 52 : 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.82),
                ),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: colors.accent,
                size: compact ? 24 : 28,
              ),
            ),
            const SizedBox(height: FlowSpace.md),
            Text(
              'Nothing new yet',
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FlowSpace.xs),
            Text(
              'Fresh crawler summaries will land here once the library gains new standout quotes.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary.withValues(alpha: 0.96),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.compact,
    required this.emphasize,
  });

  final InAppNotificationModel item;
  final bool compact;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final textTheme = Theme.of(context).textTheme;
    final accentColor = item.quotesAdded > 0
        ? colors.accent
        : colors.textSecondary;

    return PremiumSurface(
      radius: compact ? 20 : FlowRadii.xl,
      elevation: emphasize ? 2 : 1,
      padding: EdgeInsets.fromLTRB(
        compact ? FlowSpace.sm : FlowSpace.md,
        compact ? FlowSpace.sm : FlowSpace.md,
        compact ? FlowSpace.sm : FlowSpace.md,
        compact ? FlowSpace.sm : FlowSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(width: FlowSpace.xs),
              Text(
                item.quotesAdded > 0 ? 'Fresh quotes' : 'Discovery check',
                style: textTheme.labelMedium?.copyWith(
                  color: accentColor.withValues(alpha: 0.96),
                  letterSpacing: 0.45,
                ),
              ),
              const Spacer(),
              Text(
                _formatNotificationTimestamp(item.createdAt),
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(
            item.title,
            style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                ?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: FlowSpace.xs),
          Text(
            item.body,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary.withValues(alpha: 0.98),
              height: compact ? 1.4 : 1.48,
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineMetric(
                label: '${item.quotesAdded} added',
                icon: Icons.auto_awesome_rounded,
                highlight: item.quotesAdded > 0,
              ),
              _InlineMetric(
                label: '${item.totalQuotes} total',
                icon: Icons.layers_rounded,
                highlight: false,
              ),
              if (item.prunedQuotes > 0)
                _InlineMetric(
                  label: '${item.prunedQuotes} trimmed',
                  icon: Icons.filter_alt_off_rounded,
                  highlight: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.icon,
    required this.highlight,
  });

  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final foreground = highlight ? colors.accent : colors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.sm,
        vertical: FlowSpace.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (highlight ? colors.accent : colors.elevatedSurface).withValues(
          alpha: highlight ? 0.12 : 0.4,
        ),
        border: Border.all(
          color: (highlight ? colors.accent : colors.divider).withValues(
            alpha: highlight ? 0.42 : 0.72,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground.withValues(alpha: 0.96),
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.accent.withValues(alpha: 0.12),
        border: Border.all(color: colors.divider.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.accent.withValues(alpha: 0.96),
          letterSpacing: 0.6,
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
