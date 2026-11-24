import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/network/lan_game_codec.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';
import 'package:monopoly/game/ui/widgets/compact_players_strip.dart';

void main() {
  test('A purchase debits exactly its price; rejection changes no money', () {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.roll(1, 2); // Canal Street (index 3), price 60.
    expect(game.phase, TurnPhase.purchase);
    game.buyProperty();
    expect(game.players[0].balance, 1440);
    expect(game.properties[3].ownerId, 0);
    expect(game.players[1].balance, 1500);
    expect(() => game.buyProperty(), throwsA(isA<GameRuleException>()));
    expect(game.players[0].balance, 1440);
  });

  test('Auction debits the winner once; losing bidder pays nothing', () {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.roll(1, 2);
    game.declinePurchase();
    game.bid(110); // Alice
    game.bid(120); // Bob
    game.passBid(); // Alice passes: Bob wins
    expect(game.properties[3].ownerId, 1);
    expect(game.players[0].balance, 1500);
    expect(game.players[1].balance, 1380);
  });

  test('A house, hotel, building sale and mortgage affect cash precisely', () {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.players[0].balance = 5000;
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;

    final houseCost = game.spaces[1].buildCost;
    expect(houseCost, greaterThan(0));
    for (var level = 1; level <= 4; level++) {
      game.build(1);
      game.build(3);
      expect(game.properties[1].development, level);
      expect(game.properties[3].development, level);
      expect(game.players[0].balance, 5000 - 2 * level * houseCost);
    }
    expect(game.housesInUse, 8);
    game.build(1); // First hotel: pays one additional build cost.
    game.build(3); // Second hotel.
    expect(game.properties[1].development, 5);
    expect(game.properties[3].development, 5);
    expect(game.players[0].balance, 5000 - 10 * houseCost);
    expect(game.housesInUse, 0);
    expect(game.hotelsInUse, 2);
    expect(game.bankHotels, 10);

    game.sellBuilding(3); // Hotel back to four houses.
    expect(game.players[0].balance, 5000 - 10 * houseCost + houseCost ~/ 2);
    expect(game.properties[3].development, 4);

    // Station mortgages are independent of developed street groups.
    game.properties[5].ownerId = 0;
    final beforeMortgage = game.players[0].balance;
    game.mortgage(5);
    expect(game.players[0].balance, beforeMortgage + game.spaces[5].price ~/ 2);
    final cost = game.unmortgageCost(5);
    game.unmortgage(5);
    expect(
      game.players[0].balance,
      beforeMortgage + game.spaces[5].price ~/ 2 - cost,
    );
  });

  test(
    'Rent transfers exact amount between players, conserving total cash',
    () {
      final game = GameEngine(playerNames: ['Alice', 'Bob']);
      game.properties[3].ownerId = 1;
      final totalBefore = game.players.fold<int>(0, (n, p) => n + p.balance);
      game.roll(1, 2);
      expect(game.players[0].balance, 1496);
      expect(game.players[1].balance, 1504);
      expect(game.players.fold<int>(0, (n, p) => n + p.balance), totalBefore);
    },
  );

  test('Save and restore preserve exact cash after transactions', () {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.roll(1, 2);
    game.buyProperty();
    game.properties[1].ownerId = 0;
    game.build(1);
    final restored = GameEngine.importSave(game.exportSave());
    expect(restored.players[0].balance, 1390);
    expect(restored.players[1].balance, 1500);
    expect(restored.properties[3].ownerId, 0);
    expect(restored.properties[1].development, 1);
  });

  test('LAN snapshots transmit the updated cash and development', () {
    final host = GameEngine(playerNames: ['Host', 'Guest']);
    host.roll(1, 2);
    host.buyProperty();
    host.properties[1].ownerId = 0;
    host.build(1);

    final guest = LanGameCodec.decode(LanGameCodec.encode(host));
    expect(guest.players[0].balance, 1390);
    expect(guest.players[1].balance, 1500);
    expect(guest.properties[3].ownerId, 0);
    expect(guest.properties[1].development, 1);
  });

  testWidgets(
    'Main board and player cards refresh immediately after a purchase and build',
    (tester) async {
      final game = GameEngine(playerNames: ['Alice', 'Bob']);
      game.roll(1, 2);
      late StateSetter repaint;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                repaint = update;
                return Column(
                  children: [
                    CompactPlayersStrip(game: game, text: const GameText('en')),
                    Expanded(
                      child: BoardCenterAction(
                        engine: game,
                        text: const GameText('en'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      String currentCard() => tester
          .widget<Text>(find.byKey(const ValueKey<String>('player-cash-0')))
          .data!;
      String currentHud() => tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('board-current-cash')),
          )
          .data!;

      expect(currentCard(), r'$1,500');
      expect(currentHud(), r'$1,500');
      repaint(game.buyProperty);
      await tester.pump();
      expect(currentCard(), r'$1,440');
      expect(currentHud(), r'$1,440');

      game.properties[1].ownerId = 0;
      repaint(() => game.build(1));
      await tester.pump();
      expect(currentCard(), r'$1,390');
      expect(currentHud(), r'$1,390');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
