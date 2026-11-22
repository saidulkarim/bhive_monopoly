import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/widgets/animated_board_tokens.dart';

void main() {
  test('all 40 tile positions are unique and on the perimeter', () {
    final grid = <(int, int)>{};
    for (var tile = 0; tile < 40; tile++) {
      final cell = BoardTokenGeometry.gridPosition(tile);
      expect(
        cell.$1 == 0 || cell.$1 == 10 || cell.$2 == 0 || cell.$2 == 10,
        isTrue,
      );
      expect(grid.add(cell), isTrue);
    }
    expect(BoardTokenGeometry.gridPosition(0), (10, 10));
    expect(BoardTokenGeometry.gridPosition(10), (10, 0));
    expect(BoardTokenGeometry.gridPosition(20), (0, 0));
    expect(BoardTokenGeometry.gridPosition(30), (0, 10));
    expect(() => BoardTokenGeometry.gridPosition(40), throwsRangeError);
  });

  test('six people on same square receive distinct visible token slots', () {
    for (var tile = 0; tile < 40; tile++) {
      final slots = <Offset>{};
      for (var id = 0; id < 6; id++) {
        final topLeft = BoardTokenGeometry.tokenTopLeft(tile, id);
        expect(slots.add(topLeft), isTrue);
        expect(topLeft.dx >= 0 && topLeft.dx < 1000, isTrue);
        expect(topLeft.dy >= 0 && topLeft.dy < 1000, isTrue);
      }
    }
  });

  testWidgets('player tokens have stable keys and visual movement', (
    tester,
  ) async {
    final game = GameEngine(playerNames: ['Alice', 'Bob']);
    final positions = <int, int>{0: 0, 1: 0};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              height: 1000,
              child: AnimatedBoardTokens(
                game: game,
                visiblePositions: positions,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('phase11-token-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('phase11-token-1')),
      findsOneWidget,
    );
    positions[0] = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              height: 1000,
              child: AnimatedBoardTokens(
                game: game,
                visiblePositions: positions,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey<String>('phase11-token-0')),
      findsOneWidget,
    );
  });
}
