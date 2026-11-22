import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'game_experience_settings.dart';

/// Haptics are best-effort. Browsers and devices without vibration support
/// continue playing normally. No extra plugin or platform permissions needed.
enum GameHapticEvent { dice, coin, purchase, build, jail, turn, victory }

class GameHaptics {
  GameHaptics._();
  static final GameHaptics instance = GameHaptics._();

  DateTime? _previous;
  void fire(GameHapticEvent event) => unawaited(play(event));

  Future<void> play(GameHapticEvent event) async {
    final settings = GameExperienceSettings.instance;
    await settings.ensureLoaded();
    if (!settings.vibrationEnabled || kIsWeb) return;
    final now = DateTime.now();
    if (_previous != null && now.difference(_previous!).inMilliseconds < 90) {
      return;
    }
    _previous = now;
    try {
      switch (event) {
        case GameHapticEvent.dice:
        case GameHapticEvent.turn:
          await HapticFeedback.selectionClick();
          break;
        case GameHapticEvent.coin:
        case GameHapticEvent.purchase:
          await HapticFeedback.lightImpact();
          break;
        case GameHapticEvent.build:
        case GameHapticEvent.jail:
          await HapticFeedback.mediumImpact();
          break;
        case GameHapticEvent.victory:
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (error) {
      debugPrint('Haptics unsupported on this device: $error');
    }
  }
}
