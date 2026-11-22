// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';

// Relative imports avoid requiring the app package name in pubspec.yaml.
import '../../lib/game/core/board_data.dart';
import '../../lib/game/engine/game_engine.dart';
import '../../lib/game/models/game_models.dart';

void main() {
  late GameEngine game;
  setUp(() => game = GameEngine(playerNames: ['Alice', 'Bob'], cardSeed: 42));

  test('board has 40 unique spaces with correct category totals', () {
    expect(BoardData.spaces.length, 40);
    expect(BoardData.spaces.map((s) => s.index).toSet().length, 40);
    expect(
      BoardData.spaces.where((s) => s.kind == SpaceKind.street).length,
      22,
    );
    expect(
      BoardData.spaces.where((s) => s.kind == SpaceKind.station).length,
      4,
    );
    expect(
      BoardData.spaces.where((s) => s.kind == SpaceKind.utility).length,
      2,
    );
    expect(BoardData.spaces.where((s) => s.kind == SpaceKind.tax).length, 2);
    expect(
      BoardData.spaces
          .where(
            (s) => s.kind == SpaceKind.chance || s.kind == SpaceKind.community,
          )
          .length,
      6,
    );
  });

  test('initial economy and inventory', () {
    expect(game.players.length, 2);
    expect(game.players.every((p) => p.balance == 1500), true);
    expect(game.bankHouses, 32);
    expect(game.bankHotels, 12);
    expect(game.phase, TurnPhase.roll);
  });

  test('invalid player counts are rejected', () {
    expect(
      () => GameEngine(playerNames: ['Only one']),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('rolling and purchasing property reduces cash', () {
    game.roll(1, 2); // position 3, 60
    expect(game.phase, TurnPhase.purchase);
    expect(game.pendingPurchaseIndex, 3);
    game.buyProperty();
    expect(game.properties[3].ownerId, 0);
    expect(game.players[0].balance, 1440);
    expect(game.phase, TurnPhase.complete);
  });

  test('invalid dice cannot move players', () {
    expect(() => game.roll(0, 8), throwsA(isA<GameRuleException>()));
    expect(game.currentPlayer.position, 0);
  });

  test('passing START awards 200', () {
    game.currentPlayer.position = 38;
    game.roll(1, 2); // position 1
    expect(game.currentPlayer.position, 1);
    expect(game.currentPlayer.balance, 1700);
    expect(game.phase, TurnPhase.purchase);
  });

  test('rent moves cash from tenant to landlord', () {
    game.properties[3].ownerId = 1;
    game.roll(1, 2);
    expect(game.players[0].balance, 1496);
    expect(game.players[1].balance, 1504);
    expect(game.phase, TurnPhase.complete);
  });

  test('complete color set doubles vacant rent', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    expect(game.ownsFullGroup(0, ColorGroup.brown), true);
    expect(game.rentFor(1, 7), 4); // base 2 × 2
    expect(game.rentFor(3, 7), 8); // base 4 × 2
  });

  test('mortgaged title collects no rent', () {
    game.properties[1].ownerId = 0;
    game.mortgage(1);
    expect(game.properties[1].mortgaged, true);
    expect(game.currentPlayer.balance, 1530);
    expect(game.rentFor(1, 6), 0);
    game.unmortgage(1);
    expect(game.currentPlayer.balance, 1497); // 30 + 10% = 33
    expect(game.properties[1].mortgaged, false);
  });

  test('buildings must be built and sold evenly', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    game.build(1);
    expect(game.bankHouses, 31);
    expect(() => game.build(1), throwsA(isA<GameRuleException>()));
    game.build(3);
    expect(game.rentFor(1, 7), 10);
    expect(() => game.sellBuilding(3), returnsNormally);
    expect(() => game.sellBuilding(3), throwsA(isA<GameRuleException>()));
  });

  test('cannot mortgage a developed color group', () {
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    game.build(1);
    expect(() => game.mortgage(3), throwsA(isA<GameRuleException>()));
  });

  test('declined purchase auctions to highest bidder', () {
    game.roll(1, 2); // index 3, 60
    game.declinePurchase();
    expect(game.phase, TurnPhase.auction);
    game.bid(40); // Alice
    expect(game.auction!.bidderId, 1);
    game.passBid(); // Bob
    expect(game.phase, TurnPhase.complete);
    expect(game.properties[3].ownerId, 0);
    expect(game.players[0].balance, 1460);
  });

  test('auction with no bids leaves title at bank', () {
    game.roll(1, 2);
    game.declinePurchase();
    game.passBid();
    game.passBid();
    expect(game.phase, TurnPhase.complete);
    expect(game.properties[3].ownerId, isNull);
  });

  test('rolling double gets extra roll, triple double sends to Jail', () {
    game.currentPlayer.position = 5;
    game.roll(2, 2); // 9
    game.buyProperty();
    expect(game.phase, TurnPhase.roll);
    game.roll(2, 2); // 13
    game.buyProperty();
    expect(game.phase, TurnPhase.roll);
    game.roll(2, 2); // triple doubles
    expect(game.players[0].inJail, true);
    expect(game.players[0].position, 10);
    expect(game.currentPlayerId, 1);
  });

  test('jail failure ends turn and fines release the player', () {
    game.currentPlayer.inJail = true;
    game.currentPlayer.position = 10;
    game.phase = TurnPhase.jailDecision;
    game.tryJailRoll(1, 2);
    expect(game.currentPlayer.jailFailedRolls, 1);
    expect(game.phase, TurnPhase.complete);
    game.endTurn();
    expect(game.currentPlayerId, 1);
    // Bob finishes a simple turn on an owned tile.
    game.properties[3].ownerId = 1;
    game.roll(1, 2);
    game.endTurn();
    expect(game.currentPlayerId, 0);
    expect(game.phase, TurnPhase.jailDecision);
    game.payJailFine();
    expect(game.players[0].inJail, false);
    expect(game.phase, TurnPhase.roll);
  });

  test('a sale trade swaps ownership and cash on consent', () {
    game.properties[1].ownerId = 0;
    game.acceptTrade(
      const TradeOffer(
        fromPlayerId: 0,
        toPlayerId: 1,
        propertiesFrom: [1],
        cashTo: 90,
      ),
    );
    expect(game.properties[1].ownerId, 1);
    expect(game.players[0].balance, 1590);
    expect(game.players[1].balance, 1410);
  });

  test('debt can be resolved by mortgaging a title', () {
    game.properties[1].ownerId = 0;
    game.currentPlayer.position = 36;
    game.currentPlayer.balance = 80;
    game.roll(1, 1); // luxury tax 100
    expect(game.phase, TurnPhase.debt);
    expect(game.currentPlayer.balance, -20);
    game.mortgage(1); // +30
    expect(game.phase, TurnPhase.roll); // double earns bonus roll
    expect(game.currentPlayer.balance, 10);
  });

  test('last solvent player wins after bankruptcy', () {
    game.currentPlayer.position = 36;
    game.currentPlayer.balance = 10;
    game.roll(1, 2); // 39: unowned title
    game.declinePurchase();
    game.passBid();
    game.passBid();
    game.endTurn();
    // Bob is unable to pay tax.
    game.players[1].balance = 5;
    game.players[1].position = 35;
    game.roll(1, 2); // Luxury Tax at 38
    expect(game.phase, TurnPhase.debt);
    game.declareBankruptcy();
    expect(game.phase, TurnPhase.gameOver);
    expect(game.winnerId, 0);
  });
}
