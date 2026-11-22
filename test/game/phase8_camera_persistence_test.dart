import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/experience/board_camera_preset.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('loads defaults and persists camera and vibration', () async {
    final settings = GameExperienceSettings();
    await settings.ensureLoaded();
    expect(settings.effectsEnabled, isTrue);
    expect(settings.reducedMotion, isFalse);
    expect(settings.cameraPreset, BoardCameraPreset.tabletop);
    expect(settings.vibrationEnabled, isTrue);

    await settings.setCameraPreset(BoardCameraPreset.cinematic);
    await settings.setVibrationEnabled(false);

    final reloaded = GameExperienceSettings();
    await reloaded.ensureLoaded();
    expect(reloaded.cameraPreset, BoardCameraPreset.cinematic);
    expect(reloaded.vibrationEnabled, isFalse);
    await reloaded.restoreDefaults();
    expect(reloaded.cameraPreset, BoardCameraPreset.tabletop);
    expect(reloaded.vibrationEnabled, isTrue);
  });

  test(
    'unknown camera values fall back safely without breaking old saves',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        GameExperienceSettings.cameraKey: 'unrecognized-camera',
        GameExperienceSettings.soundKey: false,
      });
      final settings = GameExperienceSettings();
      await settings.ensureLoaded();
      expect(settings.cameraPreset, BoardCameraPreset.tabletop);
      expect(settings.effectsEnabled, isFalse);
      expect(settings.vibrationEnabled, isTrue);
      expect(BoardCameraPreset.topDown.tilt, 0.0);
    },
  );
}
