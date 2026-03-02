import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/quote_providers.dart';
import '../../services/author_wiki_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium/premium_components.dart';
import '../v3_background/background_theme_provider.dart';
import '../v3_notifications/notification_providers.dart';
import 'settings_providers.dart';

final _notificationAuthorProfileProvider =
    FutureProvider.family<AuthorWikiProfile?, String>((ref, author) async {
      return ref.read(authorWikiServiceProvider).fetchAuthor(author);
    });

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showDatasetLicense(BuildContext context) async {
    final licenseText = await rootBundle.loadString(
      'assets/licenses/dataset_mit_license.txt',
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FlowSpace.md),
            child: PremiumSurface(
              blurSigma: 10,
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8,
                maxChildSize: 0.95,
                minChildSize: 0.45,
                builder: (context, controller) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 42,
                          child: Divider(thickness: 3),
                        ),
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      Text(
                        'Dataset License (MIT)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: FlowSpace.sm),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: controller,
                          child: SelectableText(
                            licenseText,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundTheme = ref.watch(appBackgroundThemeProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final tagOptionsAsync = ref.watch(notificationTagOptionsProvider);
    final settingsActions = ref.read(settingsActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(FlowSpace.md),
        physics: const BouncingScrollPhysics(),
        children: [
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Theme and visual personalization',
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSettingsTile(
            title: 'App background',
            subtitle: backgroundTheme.label,
            leading: Icon(_backgroundIcon(backgroundTheme)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _BackgroundThemeSheet(),
            ),
          ),
          const SizedBox(height: FlowSpace.xl),
          const SectionHeader(
            title: 'Notifications',
            subtitle: 'Daily reminders and personalized delivery',
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preview',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: FlowSpace.xs),
                Text(
                  'Mobile only, disabled on web',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: FlowSpace.sm),
                const _NotificationPreviewCard(),
              ],
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSurface(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily quote'),
                  value: settings.dailyEnabled,
                  onChanged: kIsWeb
                      ? null
                      : (value) => ref
                            .read(notificationSettingsProvider.notifier)
                            .update(settings.copyWith(dailyEnabled: value)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Time'),
                  subtitle: Text(
                    _timeLabel(settings.dailyHour, settings.dailyMinute),
                  ),
                  onTap: kIsWeb
                      ? null
                      : () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: settings.dailyHour,
                              minute: settings.dailyMinute,
                            ),
                          );
                          if (selected == null) return;
                          await ref
                              .read(notificationSettingsProvider.notifier)
                              .update(
                                settings.copyWith(
                                  dailyHour: selected.hour,
                                  dailyMinute: selected.minute,
                                ),
                              );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Extra quote notification'),
                  value: settings.extraEnabled,
                  onChanged: kIsWeb
                      ? null
                      : (value) => ref
                            .read(notificationSettingsProvider.notifier)
                            .update(settings.copyWith(extraEnabled: value)),
                ),
                if (settings.extraEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time'),
                    subtitle: Text(
                      _timeLabel(settings.extraHour, settings.extraMinute),
                    ),
                    onTap: kIsWeb
                        ? null
                        : () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: settings.extraHour,
                                minute: settings.extraMinute,
                              ),
                            );
                            if (selected == null) return;
                            await ref
                                .read(notificationSettingsProvider.notifier)
                                .update(
                                  settings.copyWith(
                                    extraHour: selected.hour,
                                    extraMinute: selected.minute,
                                  ),
                                );
                          },
                  ),
                  const SizedBox(height: FlowSpace.xs),
                  Wrap(
                    spacing: FlowSpace.xs,
                    runSpacing: FlowSpace.xs,
                    children: [
                      PremiumPillChip(
                        label: 'Saved quotes',
                        selected: settings.extraSource == 'saved',
                        onTap: kIsWeb
                            ? null
                            : () => ref
                                  .read(notificationSettingsProvider.notifier)
                                  .update(
                                    settings.copyWith(extraSource: 'saved'),
                                  ),
                      ),
                      PremiumPillChip(
                        label: 'Selected tags',
                        selected: settings.extraSource == 'tags',
                        onTap: kIsWeb
                            ? null
                            : () => ref
                                  .read(notificationSettingsProvider.notifier)
                                  .update(
                                    settings.copyWith(extraSource: 'tags'),
                                  ),
                      ),
                    ],
                  ),
                  if (settings.extraSource == 'tags') ...[
                    const SizedBox(height: FlowSpace.sm),
                    Text(
                      'Selected tags: ${_notificationTagsSummary(settings.extraSelectedTags)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: FlowSpace.xs),
                    tagOptionsAsync.when(
                      data: (categories) => Wrap(
                        spacing: FlowSpace.xs,
                        runSpacing: FlowSpace.xs,
                        children: [
                          for (final category in categories)
                            FilterChip(
                              label: Text(_notificationCategoryLabel(category)),
                              selected: settings.extraSelectedTags.contains(
                                category,
                              ),
                              onSelected: kIsWeb
                                  ? null
                                  : (selected) {
                                      final updated = settings.extraSelectedTags
                                          .toSet();
                                      if (selected) {
                                        updated.add(category);
                                      } else {
                                        updated.remove(category);
                                      }
                                      final ordered = _orderedNotificationTags(
                                        updated,
                                        categories,
                                      );
                                      ref
                                          .read(
                                            notificationSettingsProvider
                                                .notifier,
                                          )
                                          .update(
                                            settings.copyWith(
                                              extraSelectedTags: ordered,
                                            ),
                                          );
                                    },
                            ),
                        ],
                      ),
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
                      error: (error, stack) =>
                          Text('Failed to load tags: $error'),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSurface(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Streak reminder'),
              subtitle: const Text(
                'Evening reminder if today\'s goal is not met',
              ),
              value: settings.streakEnabled,
              onChanged: kIsWeb
                  ? null
                  : (value) => ref
                        .read(notificationSettingsProvider.notifier)
                        .update(settings.copyWith(streakEnabled: value)),
            ),
          ),
          const SizedBox(height: FlowSpace.xl),
          const SectionHeader(
            title: 'Data & Utility',
            subtitle: 'Cleanup, export, and attribution',
          ),
          const SizedBox(height: FlowSpace.sm),
          PremiumSettingsTile(
            title: 'Reset personalization preferences',
            onTap: settingsActions.resetPersonalization,
          ),
          const SizedBox(height: FlowSpace.xs),
          PremiumSettingsTile(
            title: 'Reset streak',
            onTap: settingsActions.resetStreak,
          ),
          const SizedBox(height: FlowSpace.xs),
          PremiumSettingsTile(
            title: 'Clear recent history',
            onTap: settingsActions.clearRecentHistory,
          ),
          const SizedBox(height: FlowSpace.xs),
          PremiumSettingsTile(
            title: 'Export saved quotes',
            subtitle: kIsWeb ? 'Copy to clipboard' : 'Share as text',
            onTap: () => settingsActions.exportSavedQuotes(isWeb: kIsWeb),
          ),
          const SizedBox(height: FlowSpace.xs),
          PremiumSettingsTile(
            title: 'Dataset license (MIT)',
            subtitle: 'View third-party attribution',
            onTap: () => _showDatasetLicense(context),
          ),
        ],
      ),
    );
  }

  IconData _backgroundIcon(AppBackgroundTheme theme) {
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => Icons.waves_rounded,
      AppBackgroundTheme.spaceGalaxies => Icons.auto_awesome_rounded,
      AppBackgroundTheme.rainyCity => Icons.umbrella_rounded,
      AppBackgroundTheme.deepForest => Icons.forest_rounded,
      AppBackgroundTheme.sunsetCity => Icons.wb_sunny_rounded,
      AppBackgroundTheme.quoteflowGlow => Icons.auto_awesome_rounded,
    };
  }

  String _timeLabel(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _notificationTagsSummary(List<String> categories) {
    final ordered = _orderedNotificationTags(categories.toSet(), categories);
    if (ordered.isEmpty) return 'No tags selected';
    return ordered.map(_notificationCategoryLabel).join(', ');
  }

  List<String> _orderedNotificationTags(
    Set<String> selectedCategories,
    List<String> availableCategories,
  ) {
    final allowed = availableCategories
        .map((e) => e.trim().toLowerCase())
        .toSet();
    return availableCategories
        .map((e) => e.trim().toLowerCase())
        .where(
          (item) =>
              item.isNotEmpty &&
              item != 'all' &&
              allowed.contains(item) &&
              selectedCategories.contains(item),
        )
        .toList(growable: false);
  }

  String _notificationCategoryLabel(String category) {
    return switch (category) {
      'motivational' => 'Motivational',
      'love' => 'Love',
      'movies' => 'Movies',
      'series' => 'Movies/Series',
      _ => category,
    };
  }
}

class _BackgroundThemeSheet extends ConsumerWidget {
  const _BackgroundThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appBackgroundThemeProvider);
    final notifier = ref.read(appBackgroundThemeProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(FlowSpace.md),
        child: PremiumSurface(
          blurSigma: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(width: 42, child: Divider(thickness: 3)),
              ),
              const SizedBox(height: FlowSpace.sm),
              const SectionHeader(
                title: 'Choose app background',
                subtitle: 'Distinct cinematic themes with subtle interaction',
              ),
              const SizedBox(height: FlowSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: AppBackgroundTheme.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: FlowSpace.xs),
                  itemBuilder: (context, index) {
                    final theme = AppBackgroundTheme.values[index];
                    final isSelected = selected == theme;
                    return InkWell(
                      borderRadius: FlowRadii.radiusMd,
                      onTap: () async {
                        await notifier.setTheme(theme);
                        if (context.mounted) context.pop();
                      },
                      child: Ink(
                        padding: const EdgeInsets.all(FlowSpace.sm),
                        decoration: BoxDecoration(
                          borderRadius: FlowRadii.radiusMd,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                          .extension<FlowThemeTokens>()
                                          ?.colors
                                          .divider ??
                                      Colors.white24,
                          ),
                          color: Theme.of(context)
                              .extension<FlowThemeTokens>()
                              ?.colors
                              .surface
                              .withValues(alpha: 0.82),
                        ),
                        child: Row(
                          children: [
                            _ThemePreviewSwatch(theme: theme),
                            const SizedBox(width: FlowSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    theme.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: FlowSpace.xxs),
                                  Text(
                                    theme.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewSwatch extends StatelessWidget {
  const _ThemePreviewSwatch({required this.theme});

  final AppBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = switch (theme) {
      AppBackgroundTheme.oceanFloor => [
        const Color(0xFF0A2630),
        const Color(0xFF113D48),
      ],
      AppBackgroundTheme.spaceGalaxies => [
        const Color(0xFF0A1222),
        const Color(0xFF1C2750),
      ],
      AppBackgroundTheme.rainyCity => [
        const Color(0xFF111A24),
        const Color(0xFF2C3B4A),
      ],
      AppBackgroundTheme.deepForest => [
        const Color(0xFF0E1E16),
        const Color(0xFF294631),
      ],
      AppBackgroundTheme.sunsetCity => [
        const Color(0xFF47283A),
        const Color(0xFF9A5A59),
      ],
      AppBackgroundTheme.quoteflowGlow => [
        const Color(0xFF2A1634),
        const Color(0xFFC17876),
      ],
    };

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: FlowRadii.radiusSm,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _NotificationPreviewCard extends ConsumerWidget {
  const _NotificationPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyQuoteAsync = ref.watch(dailyQuoteProvider);
    return dailyQuoteAsync.when(
      data: (quote) {
        final isLongQuote = quote.quote.trim().length > 120;
        final authorProfileAsync = ref.watch(
          _notificationAuthorProfileProvider(quote.author),
        );
        return authorProfileAsync.when(
          data: (profile) {
            final imageUrl = profile?.imageUrl?.trim();
            return PremiumSurface(
              radius: FlowRadii.md,
              elevation: 1,
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.sm,
                FlowSpace.sm,
                FlowSpace.sm,
                FlowSpace.sm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.86),
                          )
                        : null,
                  ),
                  const SizedBox(width: FlowSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.author,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.94),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quote.quote,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 13.5,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        if (isLongQuote) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.white.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            onPressed: () {
                              _showFullQuoteSheet(
                                context: context,
                                author: quote.author,
                                quote: quote.quote,
                              );
                            },
                            child: Text(
                              'Read full quote',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const _PreviewFallback(label: 'Loading preview...'),
          error: (error, stack) =>
              const _PreviewFallback(label: 'Preview unavailable'),
        );
      },
      loading: () => const _PreviewFallback(label: 'Loading quote...'),
      error: (error, stack) =>
          const _PreviewFallback(label: 'Preview unavailable'),
    );
  }
}

void _showFullQuoteSheet({
  required BuildContext context,
  required String author,
  required String quote,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FlowSpace.md),
          child: PremiumSurface(
            blurSigma: 10,
            child: Padding(
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
                    child: SizedBox(width: 38, child: Divider(thickness: 3)),
                  ),
                  const SizedBox(height: FlowSpace.sm),
                  Text(author, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: FlowSpace.sm),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        quote,
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
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

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      radius: FlowRadii.md,
      elevation: 1,
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.sm,
        vertical: FlowSpace.sm,
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
