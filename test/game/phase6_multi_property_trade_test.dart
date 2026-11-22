// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';
import '../../lib/game/network/lan_trade_coordinator.dart';

void main() {
  test(
    'one LAN transaction exchanges multiple properties in both directions',
    () {
      final game = GameEngine(
        playerNames: <String>['Host', 'Guest'],
        cardSeed: 11,
      );
      // Both owners have undeveloped, unmortgaged eligible properties.
      for (final index in <int>[1, 3]) {
        game.properties[index].ownerId = 0;
      }
      for (final index in <int>[6, 8]) {
        game.properties[index].ownerId = 1;
      }
      final trades = LanTradeCoordinator();
      final pending = trades.propose(
        game,
        0,
        const TradeOffer(
          fromPlayerId: 0,
          toPlayerId: 1,
          cashFrom: 100,
          cashTo: 75,
          propertiesFrom: <int>[1, 3],
          propertiesTo: <int>[6, 8],
        ),
      );
      expect(game.properties[1].ownerId, 0);
      trades.respond(game, 1, pending.id, accept: true);
      for (final index in <int>[1, 3]) {
        expect(game.properties[index].ownerId, 1);
      }
      for (final index in <int>[6, 8]) {
        expect(game.properties[index].ownerId, 0);
      }
      expect(game.players[0].balance, 1475);
      expect(game.players[1].balance, 1525);
    },
  );
}
