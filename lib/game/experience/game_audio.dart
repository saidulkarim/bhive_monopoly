import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'game_experience_settings.dart';
import 'game_haptics.dart';

/// Original, generated WAV sounds bundled with this patch; no network calls.
enum GameSfx {
  dice('dice_roll.wav'),
  coin('coin.wav'),
  purchase('purchase.wav'),
  build('build.wav'),
  jail('jail.wav'),
  turn('turn.wav'),
  victory('victory.wav');

  const GameSfx(this.filename);
  final String filename;
}

class GameAudio {
  GameAudio._();
  static final GameAudio instance = GameAudio._();

  final Map<GameSfx, AudioPlayer> _players = <GameSfx, AudioPlayer>{};
  final GameExperienceSettings _settings = GameExperienceSettings.instance;

  /// Audio failure never blocks dice, trades, or gameplay. Browser playback
  /// requires an initial user gesture, so early autoplay may be declined.
  Future<void> play(GameSfx effect) async {
    await _settings.ensureLoaded();
    if (!_settings.effectsEnabled || _settings.volume <= 0) return;
    try {
      final player = _players.putIfAbsent(effect, () => AudioPlayer());
      await player.stop();
      await player.play(
        AssetSource('audio/${effect.filename}'),
        volume: _settings.volume,
      );
    } catch (error) {
      debugPrint('Audio effect not played: $effect ($error)');
    }
  }

  void fire(GameSfx effect) {
    // Sound and haptics use independent preferences.
    final haptic = switch (effect) {
      GameSfx.dice => GameHapticEvent.dice,
      GameSfx.coin => GameHapticEvent.coin,
      GameSfx.purchase => GameHapticEvent.purchase,
      GameSfx.build => GameHapticEvent.build,
      GameSfx.jail => GameHapticEvent.jail,
      GameSfx.turn => GameHapticEvent.turn,
      GameSfx.victory => GameHapticEvent.victory,
    };
    GameHaptics.instance.fire(haptic);
    unawaited(play(effect));
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
