import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';
import 'package:monopoly/game/ui/widgets/jail_tile_marker.dart';

void main() {
  test('Latest activity skips plain and curly apostrophe turn messages', () {
    expect(
      GameText.latestMeaningfulActivity([
        'Player’s turn.',
        "Computer 1's turn.",
        'Player paid 18 rent to Nova.',
      ]),
      'Player paid 18 rent to Nova.',
    );
    expect(
      GameText.latestMeaningfulActivity([
        'Player’s turn.',
        "Computer 1's turn.",
      ]),
      isNull,
    );
  });

  testWidgets('Board activity shows the most recent meaningful event', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Nova']);
    game.log
      ..clear()
      ..addAll(['Player’s turn.', 'Player paid 18 rent to Nova.']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardCenterAction(engine: game, text: const GameText('en')),
        ),
      ),
    );
    expect(find.text('Player paid \$18 rent to Nova.'), findsOneWidget);
    expect(find.text('Player’s turn.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Board renders accessible jail markers on 10 and 30', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Nova']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBoardView(
            engine: game,
            text: const GameText('en'),
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('board-jail-icon-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-jail-icon-30')), findsOneWidget);
    expect(find.byType(JailTileMarker), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
