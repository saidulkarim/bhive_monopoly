import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_center_action.dart';
import 'package:monopoly/game/ui/widgets/ownership_corner_badge.dart';
import 'package:monopoly/game/experience/token_preferences.dart';

void main() {
  testWidgets('The board center has one tappable pair of dice', (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    var rolls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: BoardCenterAction(
        engine: engine,
        text: const GameText('en'),
        canAct: true,
        onRoll: () => rolls++,
      ))),
    ));
    expect(find.byKey(const ValueKey<String>('board-dice-action')), findsOneWidget);
    expect(find.text('TAP THE DICE TO ROLL'), findsOneWidget);
    expect(find.text('ROLL DICE'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('board-dice-action')));
    await tester.pump();
    expect(rolls, 1);
  });

  testWidgets('Dice remain disabled while a purchase is pending', (tester) async {
    final engine = GameEngine(playerNames: <String>['Player', 'Computer 1']);
    engine.roll(1, 2);
    expect(engine.phase, TurnPhase.purchase);
    var rolls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: BoardCenterAction(
        engine: engine,
        text: const GameText('en'),
        canAct: true,
        onRoll: () => rolls++,
      ))),
    ));
    await tester.tap(find.byKey(const ValueKey<String>('board-dice-action')));
    await tester.pump();
    expect(rolls, 0);
    expect(find.text('BUY OR AUCTION'), findsOneWidget);
  });

  testWidgets('Owned properties show a coloured player icon, not a number', (tester) async {
    final icon = TokenPreferences.instance.styleFor(1).icon;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OwnershipCornerBadge(ownerId: 1)),
    ));
    expect(find.byType(OwnershipCornerBadge), findsOneWidget);
    expect(find.byIcon(icon), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
