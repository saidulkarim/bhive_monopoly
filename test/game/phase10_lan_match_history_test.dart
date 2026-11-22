import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/persistence/match_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  GameEngine finished() {
    final game = GameEngine(playerNames: ['Host', 'Guest'], cardSeed: 7);
    game.phase = TurnPhase.gameOver;
    game.winnerId = 1;
    game.players[0].bankrupt = true;
    game.turnNumber = 25;
    return game;
  }

  test('LAN match ID is deterministic for host and guest', () async {
    final game = finished();
    final host = MatchRecord.fromFinishedLanGame(
      game,
      roomPin: '431265',
      now: DateTime.utc(2026, 11, 22),
    );
    final guest = MatchRecord.fromFinishedLanGame(
      game,
      roomPin: '431265',
      now: DateTime.utc(2026, 11, 22, 1),
    );
    expect(host.id, guest.id);
    expect(host.id, startsWith('lan-'));
    expect(host.id, isNot(contains('431265')));
    expect(host.isLan, isTrue);
    expect(host.vsComputer, isFalse);
    expect(await MatchHistoryStore.record(host), isTrue);
    expect(await MatchHistoryStore.record(guest), isFalse);
    expect((await MatchHistoryStore.load()).length, 1);
  });

  test('distinct PIN and finished game produce a distinct ID', () {
    final game = finished();
    final a = MatchRecord.fromFinishedLanGame(game, roomPin: '111222');
    final b = MatchRecord.fromFinishedLanGame(game, roomPin: '333444');
    expect(a.id, isNot(b.id));
  });

  test('old Phase 9 records load without LAN field', () {
    final original = MatchRecord.fromFinishedLanGame(
      finished(),
      roomPin: '100001',
    );
    final json = original.toJson()..remove('isLan');
    final decoded = MatchRecord.fromJson(json);
    expect(decoded.isLan, isFalse);
    expect(decoded.winnerName, 'Guest');
  });

  test('statistics separate offline and LAN results', () {
    final game = finished();
    final lan = MatchRecord.fromFinishedLanGame(game, roomPin: '567890');
    final offline = MatchRecord.fromFinishedGame(game, const {});
    final stats = MatchStatistics([lan, offline]);
    expect(stats.matches, 2);
    expect(stats.lanMatches, 1);
    expect(stats.offlineMatches, 1);
    expect(stats.playerOneVictories, 0);
    expect(stats.lanPioneer, isTrue);
    expect(stats.lanVeteran, isFalse);
    expect(stats.propertyMagnate, isFalse);
    expect(stats.endurance, isFalse);
  });

  test('unfinished LAN match cannot be recorded', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    expect(
      () => MatchRecord.fromFinishedLanGame(game, roomPin: '100001'),
      throwsStateError,
    );
  });
}
