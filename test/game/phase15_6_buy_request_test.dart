import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/ui/widgets/property_buy_request.dart';

void main() {
  late GameEngine game;
  setUp(() {
    game = GameEngine(playerNames: ['ROOO', 'Cleo']);
    game.phase = TurnPhase.complete;
    game.properties[31].ownerId = 0;
    game.properties[32].ownerId = 0;
    game.properties[34].ownerId = 1;
  });
  test('purchase request completes green group and transfers cash', () {
    expect(canRequestProperty(game, 0, 34), isTrue);
    expect(completesPurchaseGroup(game, 0, 34), isTrue);
    final beforeBuyer = game.players[0].balance;
    final beforeSeller = game.players[1].balance;
    final offer = propertyBuyOffer(0, 1, 34, 500);
    game.validateTrade(offer);
    expect(game.properties[34].ownerId, 1);
    game.acceptTrade(offer);
    expect(game.ownsFullGroup(0, ColorGroup.green), isTrue);
    expect(game.players[0].balance, beforeBuyer - 500);
    expect(game.players[1].balance, beforeSeller + 500);
  });
  test('invalid price or stale ownership leaves cash unchanged', () {
    expect(
      () => propertyBuyOffer(0, 1, 34, 0),
      throwsA(isA<GameRuleException>()),
    );
    final before = game.players[0].balance;
    expect(
      () => game.acceptTrade(propertyBuyOffer(0, 1, 34, before + 1)),
      throwsA(isA<GameRuleException>()),
    );
    game.properties[34].ownerId = 0;
    expect(
      () => game.acceptTrade(propertyBuyOffer(0, 1, 34, 500)),
      throwsA(isA<GameRuleException>()),
    );
    expect(game.players[0].balance, before);
  });
  test('mortgage and unresolved decisions block requests', () {
    game.properties[34].mortgaged = true;
    expect(canRequestProperty(game, 0, 34), isFalse);
    game.properties[34].mortgaged = false;
    game.phase = TurnPhase.purchase;
    expect(canRequestProperty(game, 0, 34), isFalse);
  });
}
