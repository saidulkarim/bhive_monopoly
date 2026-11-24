import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/models/game_models.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/board_corner_symbol.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';
import 'package:monopoly/game/ui/widgets/jail_tile_marker.dart';

void main() {
  testWidgets('The board shows four and only four corner symbols', (
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

    expect(find.byType(BoardCornerSymbol), findsNWidgets(4));
    for (final tile in [0, 10, 20, 30]) {
      expect(find.byKey(ValueKey('board-corner-icon-$tile')), findsOneWidget);
    }
    expect(find.byType(JailTileMarker), findsNWidgets(2));
    expect(find.byKey(const ValueKey('board-jail-icon-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-jail-icon-30')), findsOneWidget);
    expect(find.byIcon(Icons.sports_score_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_parking_rounded), findsOneWidget);
    // The corner labels are accessible but no longer consume visible tile
    // space; existing numbers are still rendered for board identification.
    expect(find.text('FREE PARKING'), findsNothing);
    expect(find.text('GO TO JAIL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bangla board uses the same icons without changing game data', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Player', 'Nova']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBoardView(
            engine: game,
            text: const GameText('bn'),
            onSelect: (_) {},
          ),
        ),
      ),
    );
    for (final tile in [0, 10, 20, 30]) {
      expect(find.byKey(ValueKey('board-corner-icon-$tile')), findsOneWidget);
    }
    expect(game.spaces[0].kind, SpaceKind.go);
    expect(game.spaces[10].kind, SpaceKind.jail);
    expect(game.spaces[20].kind, SpaceKind.freeParking);
    expect(game.spaces[30].kind, SpaceKind.goToJail);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Corner symbols fit a compact mobile-sized board', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 720);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
    expect(find.byType(BoardCornerSymbol), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
