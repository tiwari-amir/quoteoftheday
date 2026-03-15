import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/storage_provider.dart';

const _kBackgroundTheme = 'v3.app_background_theme';

enum AppBackgroundTheme {
  oceanFloor,
  spaceGalaxies,
  rainyCity,
  deepForest,
  sunsetCity,
  quoteflowGlow,
}

extension AppBackgroundThemeX on AppBackgroundTheme {
  String get id => switch (this) {
    AppBackgroundTheme.oceanFloor => 'ethereal',
    AppBackgroundTheme.spaceGalaxies => 'midnight',
    AppBackgroundTheme.rainyCity => 'classic',
    AppBackgroundTheme.deepForest => 'zen',
    AppBackgroundTheme.sunsetCity => 'solar',
    AppBackgroundTheme.quoteflowGlow => 'cyber',
  };

  String get label => switch (this) {
    AppBackgroundTheme.oceanFloor => 'Ethereal',
    AppBackgroundTheme.spaceGalaxies => 'Midnight',
    AppBackgroundTheme.rainyCity => 'Classic',
    AppBackgroundTheme.deepForest => 'Zen',
    AppBackgroundTheme.sunsetCity => 'Solar',
    AppBackgroundTheme.quoteflowGlow => 'Cyber',
  };

  String get subtitle => switch (this) {
    AppBackgroundTheme.oceanFloor =>
      'Pearled glass, silvery haze, and floating chrome light.',
    AppBackgroundTheme.spaceGalaxies =>
      'Midnight noir with champagne-gold light and black glass depth.',
    AppBackgroundTheme.rainyCity =>
      'Editorial noir with champagne highlights and restrained depth.',
    AppBackgroundTheme.deepForest =>
      'Soft sage diffusion with calm spacing and quieter motion.',
    AppBackgroundTheme.sunsetCity =>
      'Sun-warmed gradients with amber glass and radiant highlights.',
    AppBackgroundTheme.quoteflowGlow =>
      'Electric cyan glass with denser blur and futuristic contrast.',
  };
}

AppBackgroundTheme _themeFromId(String? id) {
  return AppBackgroundTheme.values.firstWhere(
    (theme) => theme.id == id,
    orElse: () => AppBackgroundTheme.spaceGalaxies,
  );
}

final appBackgroundThemeProvider =
    StateNotifierProvider<AppBackgroundThemeNotifier, AppBackgroundTheme>((
      ref,
    ) {
      final prefs = ref.read(sharedPreferencesProvider);
      return AppBackgroundThemeNotifier(prefs);
    });

class AppBackgroundThemeNotifier extends StateNotifier<AppBackgroundTheme> {
  AppBackgroundThemeNotifier(this._prefs)
    : super(_themeFromId(_prefs.getString(_kBackgroundTheme)));

  final SharedPreferences _prefs;

  Future<void> setTheme(AppBackgroundTheme theme) async {
    if (state == theme) return;
    state = theme;
    await _prefs.setString(_kBackgroundTheme, theme.id);
  }
}
