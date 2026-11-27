import '../../core/config/game_config.dart';
import 'game_experience_settings.dart';

/// A device-local reading; null means unavailable, never a fake 100%.
class BatteryReading {
  const BatteryReading(this.level, {required this.charging});
  final int level;
  final bool charging;
  bool get valid => level >= 0 && level <= 100;
}

/// Never override a user's choice with a more expensive profile.
GamePowerProfile adaptivePowerProfile(
  GamePowerProfile selected,
  BatteryReading? reading, {
  required bool enabled,
}) {
  if (!enabled || reading == null || !reading.valid || reading.charging) {
    return selected;
  }
  final recommended = reading.level <= GameConfig.ultraSaverThresholdPercent
      ? GamePowerProfile.ultraSaver
      : reading.level <= GameConfig.batterySaverThresholdPercent
      ? GamePowerProfile.batterySaver
      : selected;
  return recommended.index > selected.index ? recommended : selected;
}
