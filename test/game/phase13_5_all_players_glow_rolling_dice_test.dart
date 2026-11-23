import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/experience/game_experience_settings.dart';
import 'package:monopoly/game/experience/player_palette.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/active_position_glow.dart';
import 'package:monopoly/game/ui/widgets/dice_face.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';

void main() {
  setUp(() => GameExperienceSettings.instance.reducedMotion = false);
  tearDown(() => GameExperienceSettings.instance.reducedMotion = false);

  Widget board(
    GameEngine game, {
    Map<int, int> visiblePositions = const <int, int>{},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 700,
          child: GameBoardView(
            engine: game,
            text: const GameText('en'),
            onSelect: (_) {},
            visiblePositions: visiblePositions,
            perspective: false,
          ),
        ),
      ),
    );
  }

  testWidgets('Every live player tile glows in their own colour', (
    tester,
  ) async {
    final game = GameEngine(
      playerNames: <String>['Human', 'Nova', 'Skye'],
      colorIndices: <int>[0, 2, 7],
    );
    game.players[0].position = 11;
    game.players[1].position = 23;
    game.players[2].position = 36;

    await tester.pumpWidget(board(game));
    expect(find.byType(ActivePositionGlow), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey<String>('active-position-tile-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-position-tile-23')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-position-tile-36')),
      findsOneWidget,
    );
    final marker = tester.widget<ActivePositionGlow>(
      find.byKey(const ValueKey<String>('player-position-tile-23')),
    );
    expect(marker.color, PlayerPalette.at(2));
    expect(marker.isCurrentTurn, false);
    for (var i = 0; i < 3; i++) {
      expect(
        find.byKey(ValueKey<String>('player-token-aura-$i')),
        findsOneWidget,
      );
    }
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shared square shows all occupant colours', (tester) async {
    final game = GameEngine(
      playerNames: <String>['Human', 'Nova'],
      colorIndices: <int>[0, 1],
    );
    game.players[0].position = 25;
    game.players[1].position = 25;
    await tester.pumpWidget(board(game));
    expect(find.byType(ActivePositionGlow), findsOneWidget);
    final highlight = tester.widget<ActivePositionGlow>(
      find.byKey(const ValueKey<String>('active-position-tile-25')),
    );
    expect(highlight.colors, <Color>[PlayerPalette.at(0), PlayerPalette.at(1)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opponent highlight follows intermediate animated position', (
    tester,
  ) async {
    final game = GameEngine(playerNames: <String>['Human', 'Nova']);
    game.players[0].position = 8;
    game.players[1].position = 23;
    await tester.pumpWidget(board(game, visiblePositions: <int, int>{1: 22}));
    expect(
      find.byKey(const ValueKey<String>('player-position-tile-22')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-position-tile-23')),
      findsNothing,
    );
    expect(game.players[1].position, 23);
  });

  Widget dice({required bool rolling, int value = 5, int index = 0}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RollingDiceFace(
              value: value,
              rolling: rolling,
              size: 106,
              dieIndex: index,
            ),
          ),
        ),
      );

  testWidgets('Rolling cube visibly tumbles, then settles on engine result', (
    tester,
  ) async {
    await tester.pumpWidget(dice(rolling: false, value: 2));
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 2);
    await tester.pumpWidget(dice(rolling: true, value: 2));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.byKey(const ValueKey<String>('dice-rolling-cube-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(dice(rolling: false, value: 6));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 6);
    expect(
      find.byKey(const ValueKey<String>('dice-rolling-cube-0')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Two dice have separate rolling painter identifiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: const [
              RollingDiceFace(value: 3, rolling: true, dieIndex: 0),
              RollingDiceFace(value: 3, rolling: true, dieIndex: 1),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey<String>('dice-rolling-cube-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dice-rolling-cube-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion leaves a static die and steady player frame', (
    tester,
  ) async {
    GameExperienceSettings.instance.reducedMotion = true;
    await tester.pumpWidget(dice(rolling: true, value: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey<String>('dice-rolling-cube-0')),
      findsNothing,
    );
    expect(tester.widget<DiceFace>(find.byType(DiceFace)).value, 4);
    expect(tester.takeException(), isNull);
  });
}
