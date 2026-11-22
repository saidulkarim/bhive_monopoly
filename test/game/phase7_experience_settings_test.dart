import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/experience/game_experience_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('defaults, saves, reloads, and resets independently', () async {
    final first = GameExperienceSettings();
    await first.ensureLoaded();
    expect(first.effectsEnabled, isTrue);
    expect(first.volume, .65);
    expect(first.reducedMotion, isFalse);

    await first.setEffectsEnabled(false);
    await first.setVolume(.25);
    await first.setReducedMotion(true);
    final second = GameExperienceSettings();
    await second.ensureLoaded();
    expect(second.effectsEnabled, isFalse);
    expect(second.volume, .25);
    expect(second.reducedMotion, isTrue);

    await second.restoreDefaults();
    final third = GameExperienceSettings();
    await third.ensureLoaded();
    expect(third.effectsEnabled, isTrue);
    expect(third.volume, .65);
    expect(third.reducedMotion, isFalse);
  });

  test('clamps invalid stored volumes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      GameExperienceSettings.volumeKey: 15.0,
    });
    final settings = GameExperienceSettings();
    await settings.ensureLoaded();
    expect(settings.volume, 1.0);
    await settings.setVolume(-10.0);
    expect(settings.volume, 0.0);
  });
}
