import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';
import 'package:monopoly/game/ui/widgets/smart_board_focus_controller.dart';
import 'package:monopoly/game/ui/widgets/animated_board_tokens.dart';

void main() {
  test('Smart camera centers the selected square for all four corners', () {
    const side = 400.0;
    for (final tile in <int>[0, 10, 20, 30]) {
      final matrix = SmartBoardCamera.matrixForTile(tile, side);
      final (row, column) = BoardTokenGeometry.gridPosition(tile);
      final centerX = (column + .5) * side / 11;
      final centerY = (row + .5) * side / 11;
      final zoom = matrix.getMaxScaleOnAxis();
      expect(zoom, closeTo(1.75, .001));
      expect(
        matrix.getTranslation().x + centerX * zoom,
        closeTo(side / 2, .001),
      );
      expect(
        matrix.getTranslation().y + centerY * zoom,
        closeTo(side / 2, .001),
      );
    }
  });

  testWidgets('Purchase status itself reopens the decision', (tester) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.roll(1, 2); // Unowned property -> purchase decision.
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BoardCenterAction(
              engine: game,
              text: const GameText('en'),
              canReviewDecision: true,
              onReviewDecision: () => requests++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('BUY OR AUCTION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('board-pending-decision-button')),
      findsOneWidget,
    );
    expect(find.text('REVIEW OPTIONS'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('board-pending-decision-button')),
    );
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending decision button is unavailable to spectators', (
    tester,
  ) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    game.roll(1, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardCenterAction(
            engine: game,
            text: const GameText('en'),
            onReviewDecision: () {},
            canReviewDecision: false,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('board-pending-decision-button')),
      findsNothing,
    );
  });

  testWidgets('Full screen has a manual Find Current Player control', (
    tester,
  ) async {
    final game = GameEngine(playerNames: <String>['Player', 'Nova']);
    await tester.pumpWidget(
      MaterialApp(
        home: BoardExplorerScreen(
          game: game,
          text: const GameText('en'),
          onSelect: (_) {},
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('board-smart-focus-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('board-exit-fullscreen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
