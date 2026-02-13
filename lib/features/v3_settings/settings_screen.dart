import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../v3_notifications/notification_providers.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
                    );
                    if (selected == null) return;
                    await ref.read(notificationSettingsProvider.notifier).update(
                          settings.copyWith(hour: selected.hour, minute: selected.minute),
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
        ],
      ),
    );
  }
}
