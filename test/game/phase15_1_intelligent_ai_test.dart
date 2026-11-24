import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/ai/bot_controller.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';

void main() {
  late GameEngine game;
  late BotController bot;
  setUp(() {
    game = GameEngine(playerNames: ['Human', 'Bot'], cardSeed: 42);
    bot = BotController();
  });

  BotDecision? choose() =>
      bot.choose(game, playerId: 0, difficulty: BotDifficulty.expert);

  test('existing difficulty identifiers remain stable', () {
    expect(BotDifficulty.values.map((v) => v.name), [
      'easy',
      'medium',
      'hard',
      'expert',
    ]);
  });

  test('expert completes an affordable group without mutating state', () {
    game.properties[1].ownerId = 0;
    game.roll(1, 2);
    game.currentPlayer.balance = 250;
    expect(choose()!.action, BotAction.buy);
    expect(game.currentPlayer.balance, 250);
    expect(game.properties[3].ownerId, isNull);
  });

  test('expert cannot buy unaffordable property', () {
    game.roll(1, 2);
    game.currentPlayer.balance = 20;
    expect(choose()!.action, BotAction.auction);
    game.declinePurchase();
    expect(choose()!.action, BotAction.pass);
  });

  test('expert restores mortgaged titles when affordable', () {
    game.properties[1].ownerId = 0;
    game.properties[1].mortgaged = true;
    game.phase = TurnPhase.complete;
    final decision = choose()!;
    expect(decision.action, BotAction.unmortgage);
    expect(decision.spaceIndex, 1);
    game.unmortgage(decision.spaceIndex!);
    expect(game.properties[1].mortgaged, isFalse);
    expect(choose()!.action, BotAction.endTurn);
  });

  test('expert builds legally and evenly', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    game.phase = TurnPhase.complete;
    final first = choose()!;
    expect(first.action, BotAction.build);
    game.build(first.spaceIndex!);
    final second = choose()!;
    expect(second.action, BotAction.build);
    expect(second.spaceIndex, isNot(first.spaceIndex));
    game.build(second.spaceIndex!);
  });

  test(
    'computer accepts fair offer and rejects overpriced or invalid trade',
    () {
      game.properties[1].ownerId = 0;
      TradeOffer offer(int cost) => TradeOffer(
        fromPlayerId: 0,
        toPlayerId: 1,
        propertiesFrom: [1],
        cashTo: cost,
      );
      expect(bot.acceptsTrade(game, offer(60), BotDifficulty.expert), isTrue);
      expect(bot.acceptsTrade(game, offer(500), BotDifficulty.expert), isFalse);
      expect(bot.acceptsTrade(game, offer(-1), BotDifficulty.expert), isFalse);
      expect(game.properties[1].ownerId, 0);
    },
  );

  test('expert refuses to give opponent a complete group', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 1;
    const offer = TradeOffer(
      fromPlayerId: 0,
      toPlayerId: 1,
      propertiesTo: [3],
      cashFrom: 400,
    );
    expect(bot.acceptsTrade(game, offer, BotDifficulty.expert), isFalse);
  });
}
