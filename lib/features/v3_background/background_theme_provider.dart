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
}

extension AppBackgroundThemeX on AppBackgroundTheme {
  String get id => switch (this) {
    AppBackgroundTheme.oceanFloor => 'ocean_floor',
    AppBackgroundTheme.spaceGalaxies => 'space_galaxies',
    AppBackgroundTheme.rainyCity => 'rainy_city',
    AppBackgroundTheme.deepForest => 'deep_forest',
    AppBackgroundTheme.sunsetCity => 'sunset_city',
  };

  String get label => switch (this) {
    AppBackgroundTheme.oceanFloor => 'Ocean Floor',
    AppBackgroundTheme.spaceGalaxies => 'Space Galaxies',
    AppBackgroundTheme.rainyCity => 'Rainy City',
    AppBackgroundTheme.deepForest => 'Deep Forest',
    AppBackgroundTheme.sunsetCity => 'Sunset City',
  };

  String get subtitle => switch (this) {
    AppBackgroundTheme.oceanFloor =>
      'Tap to send ripples through fish schools.',
    AppBackgroundTheme.spaceGalaxies =>
      'Tap to open warp rings in the starfield.',
    AppBackgroundTheme.rainyCity =>
      'Tap to trigger puddle ripples and light flash.',
    AppBackgroundTheme.deepForest => 'Tap to gather fireflies around the glow.',
    AppBackgroundTheme.sunsetCity => 'Tap to bloom cinematic lens flares.',
  };
}

AppBackgroundTheme _themeFromId(String? id) {
  return AppBackgroundTheme.values.firstWhere(
    (theme) => theme.id == id,
    orElse: () => AppBackgroundTheme.oceanFloor,
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
