// ignore_for_file: avoid_relative_lib_imports

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';
import '../../lib/game/network/lan_action_dispatcher.dart';

void main() {
  late GameEngine game;
  late LanActionDispatcher server;

  setUp(() {
    game = GameEngine(playerNames: ['Host', 'Guest']);
    server = LanActionDispatcher(random: Random(42));
  });

  test('rejects guest controlling host turn', () {
    expect(
      () => server.apply(game, 1, 'roll'),
      throwsA(isA<GameRuleException>()),
    );
    expect(game.turnNumber, 1);
    expect(game.currentPlayer.position, 0);
  });

  test('host supplies the dice: client cannot inject dice values', () {
    final dice = server.apply(game, 0, 'roll')!;
    expect(dice.first, inInclusiveRange(1, 6));
    expect(dice.second, inInclusiveRange(1, 6));
    expect(game.lastRoll!.sum, dice.sum);
    expect(game.currentPlayer.position, dice.sum);
  });

  test('auction bid is restricted to current bidder', () {
    game.roll(1, 2);
    game.declinePurchase();
    expect(
      () => server.apply(game, 1, 'bid', amount: 10),
      throwsA(isA<GameRuleException>()),
    );
    server.apply(game, 0, 'bid', amount: 10);
    expect(game.auction!.bidderId, 1);
    expect(
      () => server.apply(game, 0, 'passBid'),
      throwsA(isA<GameRuleException>()),
    );
    server.apply(game, 1, 'passBid');
    expect(game.properties[3].ownerId, 0);
  });

  test('server refuses unsupported actions', () {
    expect(
      () => server.apply(game, 0, 'setBalance', amount: 1000000),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('property management cannot target invalid index', () {
    expect(
      () => server.apply(game, 0, 'mortgage', index: 100),
      throwsA(isA<GameRuleException>()),
    );
  });
}
