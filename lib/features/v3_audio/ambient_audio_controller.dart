import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants.dart';
import '../../providers/storage_provider.dart';
import '../v3_background/background_theme_provider.dart';

class AmbientAudioState {
  const AmbientAudioState({
    required this.muted,
    required this.currentTheme,
    required this.ready,
  });

  const AmbientAudioState.initial()
    : muted = false,
      currentTheme = AppBackgroundTheme.quoteflowGlow,
      ready = false;

  final bool muted;
  final AppBackgroundTheme currentTheme;
  final bool ready;

  AmbientAudioState copyWith({
    bool? muted,
    AppBackgroundTheme? currentTheme,
    bool? ready,
  }) {
    return AmbientAudioState(
      muted: muted ?? this.muted,
      currentTheme: currentTheme ?? this.currentTheme,
      ready: ready ?? this.ready,
    );
  }
}

class AmbientAudioController extends StateNotifier<AmbientAudioState>
    with WidgetsBindingObserver {
  AmbientAudioController(this._ref) : super(const AmbientAudioState.initial());

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _startupPlayer = AudioPlayer();
  String? _activeAssetPath;
  bool _disposed = false;
  bool _startupPlayed = false;
  bool _needsUserGesturePlay = false;
  int _switchToken = 0;

  Future<void> initialize(AppBackgroundTheme initialTheme) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final muted = prefs.getBool(prefAmbientAudioMuted) ?? false;
    state = state.copyWith(
      muted: muted,
      currentTheme: initialTheme,
      ready: false,
    );
    WidgetsBinding.instance.addObserver(this);
    if (!muted) {
      await _playStartupSound();
    }
    await _loadThemeTrack(initialTheme, force: true);
  }

  Future<void> applyTheme(AppBackgroundTheme theme) async {
    await _loadThemeTrack(theme, force: true);
  }

  Future<void> toggleMute() async {
    final nextMuted = !state.muted;
    state = state.copyWith(muted: nextMuted);
    await _ref
        .read(sharedPreferencesProvider)
        .setBool(prefAmbientAudioMuted, nextMuted);

    if (nextMuted) {
      await _player.pause();
      return;
    }
    if (state.ready) {
      await _startAmbientPlayback(userInitiated: true);
    } else {
      await _loadThemeTrack(state.currentTheme, force: true);
    }
  }

  Future<void> _loadThemeTrack(
    AppBackgroundTheme theme, {
    bool force = false,
  }) async {
    final requestToken = ++_switchToken;
    final track = _trackForTheme(theme);
    final assetPath = track.assetPath;
    state = state.copyWith(currentTheme: theme);

    if (!force && assetPath == _activeAssetPath) {
      if (!state.muted && state.ready) {
        await _player.play();
      }
      return;
    }

    try {
      await _player.stop();
      if (_disposed || requestToken != _switchToken) return;

      _activeAssetPath = assetPath;
      await _player.setAudioSource(AudioSource.asset(assetPath));
      if (_disposed || requestToken != _switchToken) return;
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(track.volume);
      // Start from a gentle offset so ambience feels less repetitive.
      final duration = _player.duration;
      if (duration != null && duration.inSeconds > 18) {
        final startSeconds = ((theme.index * 7) % 16) + 3;
        await _player.seek(Duration(seconds: startSeconds));
      }
      state = state.copyWith(ready: true);
      debugPrint('[AmbientAudio] Theme ${theme.name} -> $assetPath');
      if (!state.muted) {
        await _startAmbientPlayback(userInitiated: false);
      } else {
        await _player.pause();
      }
    } catch (error) {
      debugPrint('[AmbientAudio] Failed to load $assetPath: $error');
      state = state.copyWith(ready: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_player.pause());
      unawaited(_startupPlayer.pause());
      return;
    }
    if (state == AppLifecycleState.resumed &&
        !this.state.muted &&
        this.state.ready) {
      unawaited(_startAmbientPlayback(userInitiated: false));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_player.dispose());
    unawaited(_startupPlayer.dispose());
    super.dispose();
  }

  Future<void> _playStartupSound() async {
    if (_startupPlayed) return;
    _startupPlayed = true;
    try {
      await _startupPlayer.setAudioSource(
        AudioSource.asset('assets/audio/app_startup_chime.mp3'),
      );
      await _startupPlayer.setVolume(0.56);
      unawaited(_startupPlayer.play());
      await _startupPlayer.playerStateStream.firstWhere((state) {
        return state.processingState == ProcessingState.completed ||
            (state.processingState == ProcessingState.ready && !state.playing);
      });
      await _startupPlayer.stop();
    } catch (error) {
      debugPrint('[AmbientAudio] Startup sound failed: $error');
    }
  }

  Future<void> _startAmbientPlayback({required bool userInitiated}) async {
    if (state.muted || !state.ready) return;
    try {
      await _player.play();
      _needsUserGesturePlay = false;
    } catch (error) {
      debugPrint('[AmbientAudio] Play failed: $error');
      if (kIsWeb && !userInitiated) {
        // Browser autoplay policies require a user gesture.
        _needsUserGesturePlay = true;
      }
    }

    if (_needsUserGesturePlay && userInitiated) {
      try {
        await _player.play();
        _needsUserGesturePlay = false;
      } catch (error) {
        debugPrint('[AmbientAudio] Retry play failed: $error');
      }
    }
  }

  Future<void> onUserInteraction() async {
    if (!_needsUserGesturePlay || state.muted || !state.ready) return;
    await _startAmbientPlayback(userInitiated: true);
  }

  static _ThemeAudioTrack _trackForTheme(AppBackgroundTheme theme) {
    return switch (theme) {
      AppBackgroundTheme.oceanFloor => const _ThemeAudioTrack(
        assetPath: 'assets/audio/ocean_underwater_ambience.mp3',
        volume: 0.28,
      ),
      AppBackgroundTheme.spaceGalaxies => const _ThemeAudioTrack(
        assetPath: 'assets/audio/space_serene_cosmic_ambience.mp3',
        volume: 0.19,
      ),
      AppBackgroundTheme.rainyCity => const _ThemeAudioTrack(
        assetPath: 'assets/audio/rain_soft_city_garden_ambience.mp3',
        volume: 0.2,
      ),
      AppBackgroundTheme.deepForest => const _ThemeAudioTrack(
        assetPath: 'assets/audio/forest_birds_ambience.mp3',
        volume: 0.31,
      ),
      AppBackgroundTheme.sunsetCity => const _ThemeAudioTrack(
        assetPath: 'assets/audio/sunset_evening_city_ambience.mp3',
        volume: 0.2,
      ),
      AppBackgroundTheme.quoteflowGlow => const _ThemeAudioTrack(
        assetPath: 'assets/audio/glow_post_rain_morning_ambience.mp3',
        volume: 0.29,
      ),
    };
  }
}

class _ThemeAudioTrack {
  const _ThemeAudioTrack({required this.assetPath, required this.volume});

  final String assetPath;
  final double volume;
}

final ambientAudioProvider =
    StateNotifierProvider<AmbientAudioController, AmbientAudioState>((ref) {
      final controller = AmbientAudioController(ref);
      final initialTheme = ref.read(appBackgroundThemeProvider);
      unawaited(controller.initialize(initialTheme));
      return controller;
    });
