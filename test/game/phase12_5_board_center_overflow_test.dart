import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';

void main() {
  testWidgets('Board center fits a 600px-high viewport with recent activity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    engine.roll(1, 2); // Generate a purchase event and an occupied center HUD.
    engine.buyProperty();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: BoardCenterAction(
            engine: engine,
            text: const GameText('en'),
            onViewActivity: () {},
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey<String>('board-cash-scoreboard')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('board-latest-activity')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dice stay tappable when the HUD must scale down', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    var rolls = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: BoardCenterAction(
            engine: engine,
            text: const GameText('en'),
            canAct: true,
            onRoll: () => rolls++,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('board-dice-action')));
    await tester.pump();
    expect(rolls, 1);
    expect(tester.takeException(), isNull);
  });
}
