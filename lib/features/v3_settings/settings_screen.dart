import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../v3_background/background_theme_provider.dart';
import '../v3_notifications/notification_providers.dart';
import 'settings_providers.dart';

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dataset License (MIT)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundTheme = ref.watch(appBackgroundThemeProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final settingsActions = ref.read(settingsActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('App background'),
            subtitle: Text(backgroundTheme.label),
            leading: Icon(_backgroundIcon(backgroundTheme)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const _BackgroundThemeSheet(),
            ),
          ),
          const Divider(height: 20),
          SwitchListTile(
            title: const Text('Daily quote reminder'),
            subtitle: const Text('Mobile only, disabled on web'),
            value: settings.enabled,
            onChanged: kIsWeb
                ? null
                : (value) => ref
                      .read(notificationSettingsProvider.notifier)
                      .update(settings.copyWith(enabled: value)),
          ),
          ListTile(
            title: const Text('Reminder time'),
            subtitle: Text(
              '${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')}',
            ),
            onTap: kIsWeb
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.hour,
                        minute: settings.minute,
                      ),
                    );
                    if (selected == null) return;
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .update(
                          settings.copyWith(
                            hour: selected.hour,
                            minute: selected.minute,
                          ),
                        );
                  },
          ),
          ListTile(
            title: const Text('Reminder source'),
            subtitle: Text(settings.source),
            trailing: DropdownButton<String>(
              value: settings.source,
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'saved', child: Text('Saved')),
                DropdownMenuItem(value: 'random', child: Text('Random')),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(notificationSettingsProvider.notifier)
                    .update(settings.copyWith(source: value));
              },
            ),
          ),
          const Divider(height: 28),
          ListTile(
            title: const Text('Reset personalization preferences'),
            onTap: settingsActions.resetPersonalization,
          ),
          ListTile(
            title: const Text('Reset streak'),
            onTap: settingsActions.resetStreak,
          ),
          ListTile(
            title: const Text('Clear recent history'),
            onTap: settingsActions.clearRecentHistory,
          ),
          ListTile(
            title: const Text('Export saved quotes'),
            subtitle: Text(kIsWeb ? 'Copy to clipboard' : 'Share as text'),
            onTap: () => settingsActions.exportSavedQuotes(isWeb: kIsWeb),
          ),
          ListTile(
            title: const Text('Dataset license (MIT)'),
            subtitle: const Text('View third-party attribution'),
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose app background',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Each scene keeps the same aesthetic but reacts differently to taps.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: AppBackgroundTheme.values.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final theme = AppBackgroundTheme.values[index];
                  final isSelected = selected == theme;
                  return ListTile(
                    leading: Icon(_iconFor(theme)),
                    title: Text(theme.label),
                    subtitle: Text(theme.subtitle),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () async {
                      await notifier.setTheme(theme);
                      if (context.mounted) context.pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AppBackgroundTheme theme) {
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => Icons.waves_rounded,
      AppBackgroundTheme.spaceGalaxies => Icons.auto_awesome_rounded,
      AppBackgroundTheme.rainyCity => Icons.umbrella_rounded,
      AppBackgroundTheme.deepForest => Icons.forest_rounded,
      AppBackgroundTheme.sunsetCity => Icons.wb_sunny_rounded,
    };
  }
}
