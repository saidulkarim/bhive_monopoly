import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/presentation/match_standings.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/victory_standings_sheet.dart';

void main() {
  test('winner ranks first even when another player has more cash', () {
    final game = GameEngine(playerNames: ['Ada', 'Bala', 'Cora']);
    game.winnerId = 1;
    game.players[0].balance = 9000;
    game.players[1].balance = 100;
    game.players[2].balance = 500;
    game.players[0].bankrupt = true;
    final rows = MatchStandings.fromGame(game);
    expect(rows.map((row) => row.playerId).toList(), [1, 2, 0]);
  });

  test(
    'houses and hotels are counted without counting hotel as five houses',
    () {
      final game = GameEngine(playerNames: ['Ada', 'Bala']);
      game.properties[1].ownerId = 0;
      game.properties[1].development = 3;
      game.properties[3].ownerId = 0;
      game.properties[3].development = 5;
      game.properties[5].ownerId = 0;
      game.properties[5].mortgaged = true;
      final row = MatchStandings.fromGame(game).first;
      expect(row.properties, 3);
      expect(row.houses, 3);
      expect(row.hotels, 1);
      expect(row.mortgaged, 1);
    },
  );

  testWidgets('final standings can be read in English and Bangla', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.winnerId = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VictoryStandingsSheet(game: game, text: const GameText('en')),
        ),
      ),
    );
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
    expect(find.text('Alice wins!'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VictoryStandingsSheet(game: game, text: const GameText('bn')),
        ),
      ),
    );
    expect(find.text('চূড়ান্ত ফলাফল'), findsOneWidget);
    expect(find.text('Alice বিজয়ী!'), findsOneWidget);
  });
}
