import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/experience/adaptive_power_policy.dart';
import 'package:monopoly/game/experience/battery_monitor.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/experience/performance_diagnostics.dart';
import 'package:monopoly/game/persistence/offline_game_store.dart';
import 'support/ai_soak_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'repeated distinct and identical checkpoints retain correct state',
    () async {
      final runner = AiSoakRunner(
        seed: 150910,
        playerCount: 4,
        difficulty: BotDifficulty.hard,
        maximumTurns: 100,
      );
      final prefs = await SharedPreferences.getInstance();
      const match = 'soak-checkpoint';
      for (var cycle = 0; cycle < 30; cycle++) {
        for (var i = 0; i < 10 && !runner.finished; i++) {
          runner.step();
        }
        await OfflineGameStore.save(runner.game, const {}, matchId: match);
        final primary = prefs.getString(OfflineGameStore.storageKey);
        final backup = prefs.getString(OfflineGameStore.backupKey);
        await OfflineGameStore.save(runner.game, const {}, matchId: match);
        expect(prefs.getString(OfflineGameStore.storageKey), primary);
        expect(prefs.getString(OfflineGameStore.backupKey), backup);
        final loaded = await OfflineGameStore.load();
        expect(loaded, isNotNull);
        expect(loaded!.game.exportSave(), equals(runner.game.exportSave()));
        runner.game = loaded.game;
      }
      await OfflineGameStore.clearIfMatchId(match);
      expect(await OfflineGameStore.load(), isNull);
    },
  );

  testWidgets('eight simulated foreground hours with repeated hide/resume', (
    tester,
  ) async {
    final settings = GameExperienceSettings()..automaticPowerEnabled = true;
    var reads = 0;
    final monitor = BatteryMonitor(
      settings,
      reader: () async {
        reads++;
        return const BatteryReading(25, charging: false);
      },
    );
    final interval = Duration(seconds: GameConfig.batterySampleIntervalSeconds);
    // 8 virtual hours, no wall-clock delay; default interval is 120 seconds.
    final samples = const Duration(hours: 8).inSeconds ~/ interval.inSeconds;
    try {
      monitor.configure(foreground: true, enabled: true);
      await tester.pump();
      expect(reads, 1);
      for (var i = 0; i < samples; i++) {
        final before = reads;
        await tester.pump(interval);
        expect(reads, before + 1);
        if (i % 20 == 0) {
          monitor.configure(foreground: false, enabled: true);
          final hidden = reads;
          await tester.pump(interval * 3);
          expect(reads, hidden);
          monitor.configure(foreground: true, enabled: true);
          await tester.pump();
          expect(reads, hidden + 1);
        }
      }
      monitor.configure(foreground: true, enabled: false);
      final stopped = reads;
      await tester.pump(interval * 3);
      expect(reads, stopped);
    } finally {
      monitor.dispose();
      settings.dispose();
    }
  });

  testWidgets(
    'diagnostics repeatedly expires or stops without active sessions',
    (tester) async {
      final diagnostics = PerformanceDiagnostics();
      try {
        for (var i = 0; i < 30; i++) {
          diagnostics.start();
          expect(diagnostics.active, isTrue);
          if (i.isEven) {
            await tester.pump(
              const Duration(
                seconds: GameConfig.performanceDiagnosticsSessionSeconds,
              ),
            );
          } else {
            diagnostics.setForeground(false);
          }
          expect(diagnostics.active, isFalse);
          diagnostics.setForeground(true);
        }
      } finally {
        diagnostics.dispose();
      }
    },
  );
}
