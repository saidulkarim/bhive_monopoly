// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';

void main() {
  test('Save restores pending purchase and exact private deck/turn data', () {
    final game = GameEngine(playerNames: <String>['One', 'Two'], cardSeed: 11);
    game.roll(1, 2); // tile 3 — purchase required.
    expect(game.phase, TurnPhase.purchase);
    final snapshot = game.exportSave();
    final resumed = GameEngine.importSave(snapshot);
    expect(resumed.exportSave(), snapshot);
    resumed.buyProperty();
    expect(resumed.properties[3].ownerId, 0);
  });

  test('Save restores an active auction and its bidders', () {
    final game = GameEngine(playerNames: <String>['One', 'Two'], cardSeed: 31);
    game.roll(1, 2);
    game.declinePurchase();
    expect(game.phase, TurnPhase.auction);
    final resumed = GameEngine.importSave(game.exportSave());
    expect(resumed.phase, TurnPhase.auction);
    expect(resumed.auction!.spaceIndex, 3);
    resumed.bid(20);
    expect(resumed.auction, isNotNull);
  });

  test('Refuses tampered saved player and unsupported schema', () {
    final game = GameEngine(playerNames: ['One', 'Two'], cardSeed: 4);
    final snapshot = game.exportSave();
    final players = (snapshot['players'] as List).cast<Map<String, dynamic>>();
    players[0]['position'] = 300;
    expect(() => GameEngine.importSave(snapshot), throwsFormatException);
    snapshot['schema'] = 999;
    expect(() => GameEngine.importSave(snapshot), throwsFormatException);
  });
}
