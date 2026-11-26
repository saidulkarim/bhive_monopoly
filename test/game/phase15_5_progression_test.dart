import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/config/game_config.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/progression/match_progress.dart';

void main() {
  test('default human auto-end is disabled and timing is coherent', () {
    expect(GameConfig.humanAutoEndTurnEnabled, isFalse);
    expect(
      GameConfig.autoEndTurnSeconds - GameConfig.autoEndTurnCountdownSeconds,
      greaterThanOrEqualTo(GameConfig.endTurnReminderSeconds),
    );
  });
  test('deadlock requires observed stable turns and respects cooldown', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    for (final s in game.spaces.where((s) => s.purchasable)) {
      game.properties[s.index].ownerId = s.index % 2;
    }
    final progress = MatchProgress();
    game.turnNumber = 80;
    expect(progress.observe(game), isFalse);
    game.turnNumber += GameConfig.deadlockObservationTurns;
    expect(progress.observe(game), isTrue);
    expect(progress.observe(game), isFalse);
    game.turnNumber++;
    expect(progress.observe(game), isFalse);
    game.properties[1].ownerId = 1 - game.properties[1].ownerId!;
    game.turnNumber++;
    expect(progress.observe(game), isFalse);
    expect(progress.stagnant, isFalse);
  });
  test(
    'reciprocal bot trade completes two groups only with legal ownership',
    () {
      final game = GameEngine(playerNames: ['A', 'B']);
      game.phase = TurnPhase.complete;
      game.properties[1].ownerId = 0;
      game.properties[3].ownerId = 1;
      game.properties[6].ownerId = 1;
      game.properties[8].ownerId = 1;
      game.properties[9].ownerId = 0;
      expect(findReciprocalBotTrade(game, {0}), isNull);
      final offer = findReciprocalBotTrade(game, {0, 1});
      expect(offer, isNotNull);
      expect(offer!.propertiesFrom, [9]);
      expect(offer.propertiesTo, [3]);
      game.acceptTrade(offer);
      expect(game.ownsFullGroup(0, ColorGroup.brown), isTrue);
      expect(game.ownsFullGroup(1, ColorGroup.sky), isTrue);
    },
  );
  test('same-group swap is not a reciprocal completion', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.phase = TurnPhase.complete;
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 1;
    expect(findReciprocalBotTrade(game, {0, 1}), isNull);
    expect(game.properties[1].ownerId, 0);
    expect(game.properties[3].ownerId, 1);
  });
  test('mortgaged property cannot be transferred by autonomous exchange', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.phase = TurnPhase.complete;
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 1;
    game.properties[3].mortgaged = true;
    game.properties[6].ownerId = 1;
    game.properties[8].ownerId = 1;
    game.properties[9].ownerId = 0;
    expect(findReciprocalBotTrade(game, {0, 1}), isNull);
  });
  test(
    'limited match finishes at legal end turn and survives save validation',
    () {
      final game = GameEngine(playerNames: ['A', 'B'], maximumTurns: 100);
      game.turnNumber = 100;
      game.phase = TurnPhase.complete;
      game.players[1].balance = 2000;
      game.endTurn();
      expect(game.winnerId, 1);
      expect(game.finishedByTurnLimit, isTrue);
      final restored = GameEngine.importSave(game.exportSave());
      expect(restored.maximumTurns, 100);
      expect(restored.winnerId, 1);
      expect(restored.finishedByTurnLimit, isTrue);
    },
  );
  test('classic match stays unlimited and its save has no new key', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.turnNumber = 500;
    game.phase = TurnPhase.complete;
    game.endTurn();
    expect(game.phase, TurnPhase.roll);
    expect(game.exportSave().containsKey('maximumTurns'), isFalse);
  });
}
