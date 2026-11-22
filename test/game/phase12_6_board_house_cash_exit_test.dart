import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/board_explorer_screen.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';

void main() {
  testWidgets('Building houses and hotels cannot overflow board cells', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = GameEngine(playerNames: ['Player', 'Computer 1']);
    for (final index in <int>[1, 3, 6, 8, 9, 11, 13, 14, 16]) {
      engine.properties[index].ownerId = 0;
    }
    for (final (i, development) in <(int, int)>[
      (1, 1),
      (3, 2),
      (6, 3),
      (8, 4),
      (9, 5),
    ]) {
      engine.properties[i].development = development;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: GameBoardView(
                engine: engine,
                text: const GameText('en'),
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('tile-development-badge')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cash and lead are updated after the engine spends on a house', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = GameEngine(playerNames: ['Player', 'Computer 1']);
    game.players[0].balance = 890;
    game.players[1].balance = 465;
    // Complete the brown group to allow a real house purchase.
    game.properties[1].ownerId = 0;
    game.properties[3].ownerId = 0;
    final updates = ChangeNotifier();
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BoardExplorerScreen(
          game: game,
          boardUpdates: updates,
          text: const GameText('en'),
          onSelect: (_) {},
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('board-current-cash')),
          )
          .data,
      r'$890',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('board-leader-cash')))
          .data,
      r'+$425',
    );
    game.build(1);
    updates.notifyListeners();
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('board-current-cash')),
          )
          .data,
      r'$840',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('board-leader-cash')))
          .data,
      r'+$375',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Zoom toolbar exit button returns to the game page', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Computer 1']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BoardExplorerScreen(
                    game: game,
                    text: const GameText('en'),
                    onSelect: (_) {},
                  ),
                ),
              ),
              child: const Text('Open board'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open board'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardExplorerScreen), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('board-exit-fullscreen')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BoardExplorerScreen), findsNothing);
    expect(find.text('Open board'), findsOneWidget);
  });

  testWidgets('Different cash leader displays actual highest balance', (
    tester,
  ) async {
    final engine = GameEngine(playerNames: ['Player', 'Computer 1']);
    engine.players[1].balance = 2250;
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BoardCenterAction(
              engine: engine,
              text: const GameText('en'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('board-leader-cash')))
          .data,
      r'$2,250',
    );
  });
}
