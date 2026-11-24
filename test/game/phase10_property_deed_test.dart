import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/property_deed_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('street rent reflects monopoly, development and mortgage', () {
    final game = GameEngine(playerNames: ['Alice', 'Bob'], cardSeed: 1);
    game.properties[1].ownerId = 0;
    expect(game.rentFor(1, 7), 2);
    game.properties[3].ownerId = 0;
    expect(game.ownsFullGroup(0, ColorGroup.brown), isTrue);
    expect(game.rentFor(1, 7), 4);
    game.properties[1].development = 2;
    expect(game.rentFor(1, 7), game.spaces[1].rents[2]);
    game.properties[1].mortgaged = true;
    expect(game.rentFor(1, 7), 0);
  });

  test('station and utility rent grows with group ownership', () {
    final game = GameEngine(playerNames: ['A', 'B'], cardSeed: 2);
    game.properties[5].ownerId = 0;
    expect(game.rentFor(5, 7), 25);
    game.properties[15].ownerId = 0;
    expect(game.rentFor(5, 7), 50);
    game.properties[12].ownerId = 1;
    expect(game.rentFor(12, 7), 28);
    game.properties[28].ownerId = 1;
    expect(game.rentFor(12, 7), 70);
  });

  testWidgets('property deed displays full rent schedule and ownership', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    game.properties[1].ownerId = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PropertyDeedCard(
              game: game,
              text: const GameText('en'),
              spaceIndex: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('TITLE DEED'), findsOneWidget);
    expect(find.text('River Walk'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Site only'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Current charge'), findsOneWidget);
  });

  testWidgets('Bangla deed uses translated board names', (tester) async {
    final game = GameEngine(playerNames: ['A', 'B']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PropertyDeedCard(
              game: game,
              text: const GameText('bn'),
              spaceIndex: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('সদরঘাট'), findsOneWidget);
    expect(find.text('সম্পত্তির দলিল'), findsOneWidget);
  });
}
