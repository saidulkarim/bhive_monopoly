// ignore_for_file: unnecessary_overrides

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/persistence/offline_game_store.dart';

/// One-shot fault after the balance and first transfer have already changed.
class _FailingProperty extends PropertyState {
  bool failNextTransfer = false;

  @override
  set ownerId(int? value) {
    if (failNextTransfer) {
      failNextTransfer = false;
      throw StateError('Injected transfer failure');
    }
    super.ownerId = value;
  }

  @override
  int? get ownerId => super.ownerId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'partial trade restores cash, cards, properties and original objects',
    () {
      final game = GameEngine(playerNames: ['A', 'B']);
      final player = game.players[0];
      game.properties[1].ownerId = 0;
      final failing = _FailingProperty()..ownerId = 1;
      game.properties[3] = failing;
      final before = game.exportSave();
      failing.failNextTransfer = true;
      const offer = TradeOffer(
        fromPlayerId: 0,
        toPlayerId: 1,
        cashFrom: 100,
        propertiesFrom: [1],
        propertiesTo: [3],
      );
      expect(() => game.acceptTrade(offer), throwsStateError);
      expect(game.exportSave(), before);
      expect(identical(game.players[0], player), isTrue);
      expect(identical(game.properties[3], failing), isTrue);
      game.acceptTrade(offer);
      expect(game.properties[3].ownerId, 0);
      expect(game.players[0].balance, 1400);
    },
  );

  test('purchase failure restores pending decision and balance', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    game.roll(1, 2);
    final failing = _FailingProperty();
    game.properties[3] = failing;
    final before = game.exportSave();
    failing.failNextTransfer = true;
    expect(game.buyProperty, throwsStateError);
    expect(game.exportSave(), before);
    game.buyProperty();
    expect(game.properties[3].ownerId, 0);
  });

  test('rejected action leaves the complete engine state unchanged', () {
    final game = GameEngine(playerNames: ['A', 'B']);
    final before = game.exportSave();
    expect(() => game.roll(0, 2), throwsA(isA<GameRuleException>()));
    expect(game.exportSave(), before);
  });

  test('invalid incoming save preserves both distinct checkpoints', () async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(game, const {}, matchId: 'A');
    game.roll(1, 2);
    await OfflineGameStore.save(game, const {}, matchId: 'A');
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString(OfflineGameStore.storageKey);
    final backup = prefs.getString(OfflineGameStore.backupKey);
    game.players[0].position = 99;
    await expectLater(
      OfflineGameStore.save(game, const {}, matchId: 'A'),
      throwsFormatException,
    );
    expect(prefs.getString(OfflineGameStore.storageKey), primary);
    expect(prefs.getString(OfflineGameStore.backupKey), backup);
    expect((await OfflineGameStore.load())!.game.players[0].position, 3);
  });

  test('missing primary recovers only the matching active backup', () async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await OfflineGameStore.save(game, const {}, matchId: 'A');
    game.roll(1, 2);
    await OfflineGameStore.save(game, const {}, matchId: 'A');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(OfflineGameStore.storageKey);
    final recovered = await OfflineGameStore.load();
    expect(recovered!.recoveredFromBackup, isTrue);
    expect(recovered.game.players[0].position, 0);
    await prefs.setString(OfflineGameStore.activeMatchKey, 'B');
    await expectLater(OfflineGameStore.load(), throwsFormatException);
    await OfflineGameStore.clearIfMatchId('B');
    expect(await OfflineGameStore.load(), isNull);
  });

  test(
    'queued reads observe the preceding save, not the following clear',
    () async {
      final game = GameEngine(playerNames: ['A', 'B']);
      final save = OfflineGameStore.save(game, const {}, matchId: 'A');
      final load = OfflineGameStore.load();
      final clear = OfflineGameStore.clear();
      await save;
      expect((await load)!.matchId, 'A');
      await clear;
      expect(await OfflineGameStore.load(), isNull);
    },
  );
}
