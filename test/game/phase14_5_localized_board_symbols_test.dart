import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/core/board_data.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/game_board_view.dart';
import 'package:monopoly/game/ui/widgets/board_special_symbol.dart';

void main() {
  test('Bangla location names do not change canonical board data', () {
    const bn = GameText('bn');
    const en = GameText('en');
    final spaces = BoardData.spaces;
    expect(spaces.length, 40);
    expect(bn.spaceName(1, spaces[1].name), 'সদরঘাট');
    expect(bn.spaceName(13, spaces[13].name), 'চাঁদপুর');
    expect(bn.spaceName(18, spaces[18].name), 'ময়মনসিংহ');
    expect(bn.spaceName(39, spaces[39].name), 'বারিধারা');
    expect(en.spaceName(5, spaces[5].name), 'Central Railway');
    expect(spaces[5].name, 'Central Station');
    expect(spaces[5].price, 200);
    expect(spaces[12].price, 150);
  });

  for (final language in ['en', 'bn']) {
    testWidgets('$language special icons fit on an owned board', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final game = GameEngine(playerNames: ['A', 'B']);
      game.properties[5].ownerId = 0;
      game.properties[5].mortgaged = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameBoardView(
              engine: game,
              text: GameText(language),
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(BoardSpecialSymbol), findsNWidgets(14));
      for (final index in [
        2,
        4,
        5,
        7,
        12,
        15,
        17,
        22,
        25,
        28,
        33,
        35,
        36,
        38,
      ]) {
        expect(
          find.byKey(ValueKey('board-special-icon-$index')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
