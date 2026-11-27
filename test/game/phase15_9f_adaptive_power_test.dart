import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/game/experience/adaptive_power_policy.dart';
import 'package:monopoly/game/experience/battery_monitor.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/experience/performance_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('thresholds, charging, unavailable readings and manual ceiling', () {
    const selected = GamePowerProfile.balanced;
    GamePowerProfile at(int level, {bool charging = false}) =>
        adaptivePowerProfile(
          selected,
          BatteryReading(level, charging: charging),
          enabled: true,
        );
    expect(at(31), selected);
    expect(at(30), GamePowerProfile.batterySaver);
    expect(at(16), GamePowerProfile.batterySaver);
    expect(at(15), GamePowerProfile.ultraSaver);
    expect(at(0), GamePowerProfile.ultraSaver);
    expect(at(5, charging: true), selected);
    expect(at(-1), selected);
    expect(at(101), selected);
    expect(adaptivePowerProfile(selected, null, enabled: true), selected);
    expect(
      adaptivePowerProfile(
        selected,
        const BatteryReading(5, charging: false),
        enabled: false,
      ),
      selected,
    );
    expect(
      adaptivePowerProfile(
        GamePowerProfile.ultraSaver,
        const BatteryReading(25, charging: false),
        enabled: true,
      ),
      GamePowerProfile.ultraSaver,
    );
  });

  test('effective profile never overwrites persisted manual profile', () async {
    final settings = GameExperienceSettings();
    await settings.ensureLoaded();
    await settings.setPowerProfile(GamePowerProfile.performance);
    await settings.setAutomaticPowerEnabled(true);
    settings.updateBatteryReading(const BatteryReading(10, charging: false));
    expect(settings.powerProfile, GamePowerProfile.ultraSaver);
    await settings.setVolume(.4);
    final restored = GameExperienceSettings();
    await restored.ensureLoaded();
    expect(restored.automaticPowerEnabled, isTrue);
    expect(restored.selectedPowerProfile, GamePowerProfile.performance);
    expect(restored.powerProfile, GamePowerProfile.performance);
    await settings.setAutomaticPowerEnabled(false);
    expect(settings.powerProfile, GamePowerProfile.performance);
    expect(settings.batteryReading, isNull);
    await restored.restoreDefaults();
    expect(restored.automaticPowerEnabled, isFalse);
    expect(restored.powerProfile, GamePowerProfile.balanced);
    settings.dispose();
    restored.dispose();
  });

  testWidgets(
    'hidden or disabled monitor makes no reads and ignores stale results',
    (tester) async {
      final settings = GameExperienceSettings()..automaticPowerEnabled = true;
      final pending = Completer<BatteryReading?>();
      var reads = 0;
      final monitor = BatteryMonitor(
        settings,
        reader: () {
          reads++;
          return reads == 1
              ? pending.future
              : Future.value(const BatteryReading(80, charging: false));
        },
      );
      monitor.configure(foreground: false, enabled: true);
      await tester.pump();
      expect(reads, 0);
      monitor.configure(foreground: true, enabled: true);
      expect(reads, 1);
      monitor.configure(foreground: false, enabled: true);
      pending.complete(const BatteryReading(5, charging: false));
      await tester.pump();
      expect(settings.batteryReading, isNull);
      monitor.configure(foreground: true, enabled: true);
      await tester.pump();
      expect(reads, 2);
      expect(settings.batteryReading?.level, 80);
      monitor.configure(foreground: true, enabled: false);
      await tester.pump(const Duration(minutes: 3));
      expect(reads, 2);
      monitor.dispose();
      settings.dispose();
    },
  );

  testWidgets('diagnostics stops on hide and can start again', (tester) async {
    final diagnostics = PerformanceDiagnostics();
    diagnostics.start();
    expect(diagnostics.active, isTrue);
    diagnostics.setForeground(false);
    expect(diagnostics.active, isFalse);
    diagnostics.start();
    expect(diagnostics.active, isFalse);
    diagnostics.setForeground(true);
    diagnostics.start();
    expect(diagnostics.active, isTrue);
    diagnostics.stop();
    expect(diagnostics.active, isFalse);
    diagnostics.dispose();
  });
}
