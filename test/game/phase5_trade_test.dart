// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';
import '../../lib/game/network/lan_trade_coordinator.dart';

void main() {
  late GameEngine game;
  late LanTradeCoordinator trades;

  setUp(() {
    game = GameEngine(
      playerNames: <String>['Host', 'Guest', 'Observer'],
      cardSeed: 22,
    );
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 1;
    trades = LanTradeCoordinator();
  });

  test('Two-party consent transfers property and cash exactly once', () {
    final offer = TradeOffer(
      fromPlayerId: 0,
      toPlayerId: 1,
      propertiesFrom: const [1],
      propertiesTo: const [3],
      cashFrom: 120,
      cashTo: 60,
    );
    final pending = trades.propose(game, 0, offer);
    expect(game.properties[1].ownerId, 0); // Proposing does not change state.
    expect(game.players[0].balance, 1500);
    expect(
      () => trades.respond(game, 2, pending.id, accept: true),
      throwsA(isA<GameRuleException>()),
    );
    trades.respond(game, 1, pending.id, accept: true);
    expect(trades.pending, isNull);
    expect(game.properties[1].ownerId, 1);
    expect(game.properties[3].ownerId, 0);
    expect(game.players[0].balance, 1440);
    expect(game.players[1].balance, 1560);
    expect(
      () => trades.respond(game, 1, pending.id, accept: true),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('Decline never transfers assets', () {
    final trade = trades.propose(
      game,
      0,
      const TradeOffer(fromPlayerId: 0, toPlayerId: 1, cashFrom: 20),
    );
    trades.respond(game, 1, trade.id, accept: false);
    expect(trades.pending, isNull);
    expect(game.players[0].balance, 1500);
  });

  test('Only proposer can cancel', () {
    final trade = trades.propose(
      game,
      0,
      const TradeOffer(fromPlayerId: 0, toPlayerId: 1, cashFrom: 20),
    );
    expect(() => trades.cancel(1, trade.id), throwsA(isA<GameRuleException>()));
    trades.cancel(0, trade.id);
    expect(trades.pending, isNull);
  });

  test('No phantom trades or unauthorized requests', () {
    expect(
      () => trades.propose(
        game,
        1,
        const TradeOffer(fromPlayerId: 1, toPlayerId: 0, cashFrom: 15),
      ),
      throwsA(isA<GameRuleException>()),
    );
    expect(
      () => trades.propose(
        game,
        0,
        const TradeOffer(fromPlayerId: 0, toPlayerId: 1),
      ),
      throwsA(isA<GameRuleException>()),
    );
    game.properties[1].mortgaged = true;
    expect(
      () => trades.propose(
        game,
        0,
        const TradeOffer(fromPlayerId: 0, toPlayerId: 1, propertiesFrom: [1]),
      ),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('Wire state round trips with request ID', () {
    final trade = trades.propose(
      game,
      0,
      const TradeOffer(
        fromPlayerId: 0,
        toPlayerId: 1,
        propertiesFrom: [1],
        cashTo: 33,
      ),
    );
    final decoded = LanPendingTrade.fromWire(trade.toWire());
    expect(decoded.id, trade.id);
    expect(decoded.offer.propertiesFrom, <int>[1]);
    expect(decoded.offer.cashTo, 33);
  });

  test('Second proposal rejected while recipient deciding', () {
    trades.propose(
      game,
      0,
      const TradeOffer(fromPlayerId: 0, toPlayerId: 1, cashTo: 15),
    );
    expect(
      () => trades.propose(
        game,
        0,
        const TradeOffer(fromPlayerId: 0, toPlayerId: 2, cashTo: 19),
      ),
      throwsA(isA<GameRuleException>()),
    );
  });
}
