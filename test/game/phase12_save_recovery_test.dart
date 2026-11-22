import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/persistence/offline_game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recovers previous valid checkpoint when latest is damaged', () async {
    final game = GameEngine(playerNames: ['Human', 'Computer']);
    const bots = <int, BotDifficulty>{1: BotDifficulty.medium};
    await OfflineGameStore.save(game, bots, matchId: 'match-A');
    game.roll(1, 2);
    await OfflineGameStore.save(game, bots, matchId: 'match-A');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OfflineGameStore.storageKey, '{invalid json');

    final recovered = await OfflineGameStore.load();
    expect(recovered, isNotNull);
    expect(recovered!.recoveredFromBackup, true);
    expect(recovered.matchId, 'match-A');
    expect(recovered.game.currentPlayer.position, 0);
    expect(recovered.botDifficulties[1], BotDifficulty.medium);
    // A new valid save after recovery remains playable.
    await OfflineGameStore.save(
      recovered.game,
      recovered.botDifficulties,
      matchId: recovered.matchId,
    );
    final fresh = await OfflineGameStore.load();
    expect(fresh!.recoveredFromBackup, false);
  });

  test('never restores previous match when newer match is damaged', () async {
    final a = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(a, const {}, matchId: 'match-A');
    a.roll(1, 2);
    await OfflineGameStore.save(a, const {}, matchId: 'match-A');

    final b = GameEngine(playerNames: ['C', 'D']);
    await OfflineGameStore.save(b, const {}, matchId: 'match-B');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OfflineGameStore.storageKey, 'damaged');
    expect(OfflineGameStore.load(), throwsFormatException);
  });

  test('older match completion cannot erase a newer checkpoint', () async {
    final game = GameEngine(playerNames: ['C', 'D']);
    await OfflineGameStore.save(game, const {}, matchId: 'newer');
    await OfflineGameStore.clearIfMatchId('older');
    expect((await OfflineGameStore.load())!.matchId, 'newer');
    await OfflineGameStore.clearIfMatchId('newer');
    expect(await OfflineGameStore.load(), isNull);
  });

  test('legacy Phase 5–11 primary save still loads', () async {
    final game = GameEngine(playerNames: ['Legacy', 'Computer']);
    await OfflineGameStore.save(game, const {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(OfflineGameStore.activeMatchKey);
    final saved = await OfflineGameStore.load();
    expect(saved, isNotNull);
    expect(saved!.recoveredFromBackup, false);
  });

  test('clear removes primary and recovery metadata', () async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(game, const {}, matchId: 'id-1');
    await OfflineGameStore.save(game, const {}, matchId: 'id-1');
    await OfflineGameStore.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(OfflineGameStore.storageKey), false);
    expect(prefs.containsKey(OfflineGameStore.backupKey), false);
    expect(prefs.containsKey(OfflineGameStore.activeMatchKey), false);
    expect(prefs.containsKey(OfflineGameStore.backupMatchKey), false);
  });
}
