import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'board_camera_preset.dart';

enum GamePowerProfile {
  performance,
  balanced,
  batterySaver,
  ultraSaver;

  static GamePowerProfile fromStored(String? value) => values.firstWhere(
    (profile) => profile.name == value,
    orElse: () => balanced,
  );

  int get glowCycles => switch (this) {
    performance => 2,
    balanced => 1,
    batterySaver || ultraSaver => 0,
  };
}

/// Device-local presentation preferences; NEVER synchronized as game state.
/// Existing Phase 7 preference keys are deliberately preserved.
class GameExperienceSettings extends ChangeNotifier {
  GameExperienceSettings();

  static final GameExperienceSettings instance = GameExperienceSettings();
  static const String soundKey = 'bhive_p7_sfx_enabled';
  static const String volumeKey = 'bhive_p7_sfx_volume';
  static const String reducedMotionKey = 'bhive_p7_reduced_motion';
  static const String vibrationKey = 'bhive_p8_vibration_enabled';
  static const String cameraKey = 'bhive_p8_board_camera';

  static const String powerProfileKey = 'bhive_power_profile';

  GamePowerProfile powerProfile = GamePowerProfile.balanced;
  bool get effectiveReducedMotion =>
      reducedMotion || powerProfile == GamePowerProfile.ultraSaver;

  bool effectsEnabled = true;
  double volume = .65;
  bool reducedMotion = false;
  bool vibrationEnabled = true;
  BoardCameraPreset cameraPreset = BoardCameraPreset.tabletop;
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      powerProfile = GamePowerProfile.fromStored(
        prefs.getString(powerProfileKey),
      );
      effectsEnabled = prefs.getBool(soundKey) ?? true;
      final stored = prefs.getDouble(volumeKey) ?? .65;
      volume = stored.isFinite ? stored.clamp(0.0, 1.0).toDouble() : .65;
      reducedMotion = prefs.getBool(reducedMotionKey) ?? false;
      vibrationEnabled = prefs.getBool(vibrationKey) ?? true;
      cameraPreset = BoardCameraPreset.fromStored(prefs.getString(cameraKey));
    } catch (error) {
      debugPrint('Game experience settings load failed: $error');
    }
    notifyListeners();
  }

  Future<void> setEffectsEnabled(bool value) async {
    await ensureLoaded();
    effectsEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setVolume(double value) async {
    await ensureLoaded();
    volume = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    await _persist();
  }

  Future<void> setReducedMotion(bool value) async {
    await ensureLoaded();
    reducedMotion = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setVibrationEnabled(bool value) async {
    await ensureLoaded();
    vibrationEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setCameraPreset(BoardCameraPreset value) async {
    await ensureLoaded();
    cameraPreset = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setPowerProfile(GamePowerProfile value) async {
    await ensureLoaded();
    if (powerProfile == value) return;
    powerProfile = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(powerProfileKey, value.name)) {
      throw StateError('Could not save power profile.');
    }
  }

  Future<void> restoreDefaults() async {
    await ensureLoaded();
    powerProfile = GamePowerProfile.balanced;
    effectsEnabled = true;
    volume = .65;
    reducedMotion = false;
    vibrationEnabled = true;
    cameraPreset = BoardCameraPreset.tabletop;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(powerProfileKey, powerProfile.name);
    await prefs.setBool(soundKey, effectsEnabled);
    await prefs.setDouble(volumeKey, volume);
    await prefs.setBool(reducedMotionKey, reducedMotion);
    await prefs.setBool(vibrationKey, vibrationEnabled);
    await prefs.setString(cameraKey, cameraPreset.name);
  }
}
