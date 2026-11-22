// ignore_for_file: avoid_relative_lib_imports

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/ai/bot_controller.dart';
import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';

void main() {
  late GameEngine game;
  late BotController bot;
  setUp(() {
    game = GameEngine(playerNames: ['Me', 'Bot'], cardSeed: 42);
    bot = BotController(random: Random(23));
  });

  BotDecision? decide({
    BotDifficulty difficulty = BotDifficulty.medium,
    int playerId = 0,
  }) => bot.choose(game, playerId: playerId, difficulty: difficulty);

  test('bot rolls in roll phase', () {
    expect(decide()!.action, BotAction.roll);
    expect(decide(playerId: 1), isNull);
  });

  test('medium bot buys an affordable title with a \$300 reserve', () {
    game.roll(1, 2); // Canal Street, price 60
    expect(game.phase, TurnPhase.purchase);
    expect(decide()!.action, BotAction.buy);
    game.currentPlayer.balance = 350;
    expect(decide()!.action, BotAction.auction);
  });

  test('hard bot prioritizes completing a color group', () {
    game.properties[1].ownerId = 0;
    game.roll(1, 2); // index 3 completes brown set
    game.currentPlayer.balance = 200;
    expect(decide(difficulty: BotDifficulty.hard)!.action, BotAction.buy);
  });

  test('cannot bid when another bidder has the floor', () {
    game.roll(1, 2);
    game.declinePurchase();
    expect(decide(playerId: 1), isNull);
    expect(decide()!.action, BotAction.bid);
  });

  test('auction agent respects bidder cash and reserve', () {
    game.roll(1, 2);
    game.declinePurchase();
    game.currentPlayer.balance = 310;
    expect(decide()!.action, BotAction.bid); // $10 available
    game.currentPlayer.balance = 309;
    expect(decide()!.action, BotAction.pass);
  });

  test('auction bot gets turn even when current mover is human', () {
    game.roll(1, 2);
    game.declinePurchase();
    game.passBid(); // Alice passes, Bob is bidder
    expect(game.auction!.bidderId, 1);
    expect(decide(), isNull);
    expect(decide(playerId: 1)!.action, BotAction.bid);
  });

  test('jail agent uses release card if available', () {
    game.currentPlayer.inJail = true;
    game.currentPlayer.position = 10;
    game.currentPlayer.jailCardOrigins.add(true);
    game.phase = TurnPhase.jailDecision;
    expect(decide()!.action, BotAction.useJailCard);
    game.currentPlayer.jailCardOrigins.clear();
    expect(decide()!.action, BotAction.jailRoll);
  });

  test('hard agent pays the jail fine when well funded', () {
    game.currentPlayer.inJail = true;
    game.phase = TurnPhase.jailDecision;
    expect(decide(difficulty: BotDifficulty.hard)!.action, BotAction.payFine);
  });

  test('complete turn builds evenly if cash and monopoly permit', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    game.phase = TurnPhase.complete;
    final first = decide()!;
    expect(first.action, BotAction.build);
    game.build(first.spaceIndex!);
    final second = decide()!;
    expect(second.action, BotAction.build);
    expect(second.spaceIndex, isNot(first.spaceIndex));
  });

  test('bots can sell a building and mortgage to raise debt funds', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    game.build(1);
    game.currentPlayer.balance = -100;
    game.phase = TurnPhase.debt;
    expect(decide()!.action, BotAction.sellBuilding);
    game.sellBuilding(1);
    expect(decide()!.action, BotAction.mortgage);
  });

  test('a bot without assets declares bankruptcy', () {
    game.currentPlayer.balance = -5;
    game.phase = TurnPhase.debt;
    expect(decide()!.action, BotAction.bankrupt);
  });

  test('bot never acts when game is over', () {
    game.phase = TurnPhase.gameOver;
    expect(decide(), isNull);
  });
}
