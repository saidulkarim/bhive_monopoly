import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/persistence/match_history_store.dart';
import 'package:monopoly/game/persistence/offline_game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  GameEngine completed(int winnerId, {int turns = 34}) {
    final game = GameEngine(
      playerNames: <String>['Human', 'Bot'],
      cardSeed: 19,
    );
    game.phase = TurnPhase.gameOver;
    game.winnerId = winnerId;
    game.players[1 - winnerId].bankrupt = true;
    game.turnNumber = turns;
    game.properties[1].ownerId = winnerId;
    return game;
  }

  test('match snapshot can be serialized and restored', () {
    final match = MatchRecord.fromFinishedGame(
      completed(0),
      <int, BotDifficulty>{1: BotDifficulty.easy},
      now: DateTime.utc(2026, 11, 22),
    );
    expect(match.winnerName, 'Human');
    expect(match.playerOneWon, isTrue);
    expect(match.players[0].properties, 1);
    expect(match.players[1].isBot, isTrue);
    final restored = MatchRecord.fromJson(match.toJson());
    expect(restored.id, match.id);
    expect(restored.completedAt, DateTime.utc(2026, 11, 22));
  });

  test('history stores match once even with repeated callbacks', () async {
    final match = MatchRecord.fromFinishedGame(
      completed(0),
      <int, BotDifficulty>{1: BotDifficulty.medium},
    );
    final duplicate = MatchRecord.fromFinishedGame(
      completed(0),
      <int, BotDifficulty>{1: BotDifficulty.medium},
    );
    expect(match.id, duplicate.id);
    final results = await Future.wait(<Future<bool>>[
      MatchHistoryStore.record(match),
      MatchHistoryStore.record(duplicate),
    ]);
    expect(results.where((result) => result).length, 1);
    final restored = await MatchHistoryStore.load();
    expect(restored.length, 1);
    expect(restored.single.id, match.id);
  });

  test(
    'independent games have distinct persisted ids even if state matches',
    () async {
      final game = completed(0);
      final bots = <int, BotDifficulty>{1: BotDifficulty.medium};
      await OfflineGameStore.save(game, bots, matchId: 'session-alpha');
      final restored = await OfflineGameStore.load();
      expect(restored?.matchId, 'session-alpha');
      final first = MatchRecord.fromFinishedGame(
        game,
        bots,
        matchId: restored!.matchId,
      );
      final second = MatchRecord.fromFinishedGame(
        game,
        bots,
        matchId: 'session-beta',
      );
      expect(first.id, isNot(second.id));
      expect(await MatchHistoryStore.record(first), isTrue);
      expect(await MatchHistoryStore.record(second), isTrue);
      expect((await MatchHistoryStore.load()).length, 2);
    },
  );

  test('statistics and achievements reflect Player 1, not arbitrary bots', () {
    final won = MatchRecord.fromFinishedGame(
      completed(0, turns: 100),
      <int, BotDifficulty>{1: BotDifficulty.medium},
    );
    final lost = MatchRecord.fromFinishedGame(
      completed(1, turns: 5),
      <int, BotDifficulty>{1: BotDifficulty.easy},
    );
    final stats = MatchStatistics(<MatchRecord>[won, lost]);
    expect(stats.matches, 2);
    expect(stats.playerOneVictories, 1);
    expect(stats.winRate, 50);
    expect(stats.totalTurns, 105);
    expect(stats.marathon, isTrue);
    expect(stats.firstVictory, isTrue);
    expect(stats.veteran, isFalse);
    expect(stats.champion, isFalse);
  });

  test('completed match cannot erase a newer in-progress save', () async {
    final active = completed(0);
    final bots = <int, BotDifficulty>{1: BotDifficulty.easy};
    await OfflineGameStore.save(active, bots, matchId: 'new-game');
    await OfflineGameStore.clearIfMatchId('previous-game');
    expect((await OfflineGameStore.load())?.matchId, 'new-game');
    await OfflineGameStore.clearIfMatchId('new-game');
    expect(await OfflineGameStore.load(), isNull);
  });

  test('history clear does not change the active autosave key', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bhive.monopoly.offline.match.v1', 'in-progress');
    await MatchHistoryStore.record(
      MatchRecord.fromFinishedGame(completed(0), <int, BotDifficulty>{
        1: BotDifficulty.hard,
      }),
    );
    await MatchHistoryStore.clear();
    expect(await MatchHistoryStore.load(), isEmpty);
    expect(prefs.getString('bhive.monopoly.offline.match.v1'), 'in-progress');
  });

  test('unfinished game is not recorded', () {
    final game = GameEngine(playerNames: <String>['A', 'B']);
    expect(
      () => MatchRecord.fromFinishedGame(game, const <int, BotDifficulty>{}),
      throwsStateError,
    );
  });
}
