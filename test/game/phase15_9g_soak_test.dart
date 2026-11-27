import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'support/ai_soak_runner.dart';

// Explicit opt-in for the larger matrix. No runtime application overhead.
const extended = bool.fromEnvironment('BHIVE_EXTENDED_SOAK');
const seedsPerCase = extended ? 10 : 1;
const turnLimit = extended ? 500 : 100;
const actionLimit = 40000;
const checkpointEvery = 100;

void main() {
  for (final count in [2, 3, 4, 5, 6]) {
    for (final difficulty in BotDifficulty.values) {
      test(
        'AI soak: $count players / ${difficulty.name}',
        () {
          for (var i = 0; i < seedsPerCase; i++) {
            final runner = AiSoakRunner(
              seed: 150900 + i,
              playerCount: count,
              difficulty: difficulty,
              maximumTurns: turnLimit,
            );
            final watch = Stopwatch()..start();
            try {
              while (!runner.finished && runner.actions < actionLimit) {
                runner.step();
                if (runner.actions % checkpointEvery == 0) {
                  runner.validate();
                  final before = runner.game.exportSave();
                  final restored = GameEngine.importSave(
                    jsonDecode(jsonEncode(before)) as Map<String, dynamic>,
                  );
                  expect(
                    restored.exportSave(),
                    equals(before),
                    reason: runner.context,
                  );
                  runner.game = restored;
                  runner.roundTrips++;
                }
                expect(
                  runner.game.log.length,
                  lessThanOrEqualTo(70),
                  reason: runner.context,
                );
              }
              runner.validate();
              expect(
                runner.finished,
                isTrue,
                reason: 'Action budget exhausted: ${runner.context}',
              );
              expect(runner.game.winnerId, isNotNull, reason: runner.context);
            } catch (error, stack) {
              Error.throwWithStackTrace(
                StateError('${runner.context}: $error'),
                stack,
              );
            } finally {
              watch.stop();
              // ignore: avoid_print
              print(
                jsonEncode({
                  ...runner.report(),
                  'elapsedMs': watch.elapsedMilliseconds,
                }),
              );
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
    }
  }

  test(
    'classic match runs to natural finish or bounded observation horizon',
    () {
      final runner = AiSoakRunner(
        seed: 151001,
        playerCount: 6,
        difficulty: BotDifficulty.expert,
      );
      while (!runner.finished &&
          runner.game.turnNumber <= 500 &&
          runner.actions < actionLimit) {
        runner.step();
        if (runner.actions % checkpointEvery == 0) runner.validate();
      }
      runner.validate();
      expect(
        runner.finished || runner.game.turnNumber > 500,
        isTrue,
        reason: runner.context,
      );
      // Unfinished classic matches are not failures if the horizon was reached.
      expect(runner.game.maximumTurns, isNull);
      // ignore: avoid_print
      print(jsonEncode(runner.report()));
    },
  );
}
